# Vertical slices meet the DDD book

Not part of the talk. A reconciliation of Bogard's talk with Vlad Khononov's _Learning Domain-Driven Design_ (see the ddd-* skills), using the help desk example from that book.

## Contents

1. [The two vocabularies side by side](#1-the-two-vocabularies-side-by-side)
2. [Folder layout: modules by subdomain, slices inside](#2-folder-layout-modules-by-subdomain-slices-inside)
3. [A core slice and a supporting slice](#3-a-core-slice-and-a-supporting-slice)
4. [Across aggregates: the outbox](#4-across-aggregates-the-outbox)
5. [Behaviours are the book's application layer concerns](#5-behaviours-are-the-books-application-layer-concerns)
6. [Where the two disagree](#6-where-the-two-disagree)
7. [Tests](#7-tests)
8. [Cheat sheet](#8-cheat-sheet)

---

## 1. The two vocabularies side by side

| The book says                                      | The talk says                                  | Same thing?                                                 |
| -------------------------------------------------- | ---------------------------------------------- | ----------------------------------------------------------- |
| Bounded context, module per subdomain              | Feature folder                                 | Yes, but the book says where to draw the line: by subdomain |
| Application service, one class per aggregate       | Handler, one per use case                      | Same layer, different grain. The talk splits the class      |
| Command on the aggregate: `ticket.escalate()`      | "Push behaviour down into the domain"          | Yes                                                         |
| Command DTO from outside                           | Request object                                 | Yes                                                         |
| Aggregate, value objects, domain events            | The domain model shared by slices              | Yes                                                         |
| `repository.load` / `save`, used but not discussed | Use the ORM directly, write one only if needed | Closer than it looks, section 6                             |
| CQRS read model                                    | Query slice reading straight from the database | Yes                                                         |
| Domain event to connect aggregates                 | "Choreography" inside the request              | Yes, plus the book adds the outbox for reliability          |
| Ports and adapters                                 | "No abstractions until pain"                   | The disagreement, section 6                                 |
| Decision tree per subdomain (lesson 13)            | "Consistent style, two or three blueprints"    | The tree is the set of blueprints                           |

Short version: **the talk is a way of laying out the book's application layer.** The domain layer is untouched. The book's strategic layer decides where the talk's feature folders go.

---

## 2. Folder layout: modules by subdomain, slices inside

| Module       | Subdomain  | Business logic     | Slice style                                                             |
| ------------ | ---------- | ------------------ | ----------------------------------------------------------------------- |
| tickets      | Core       | Domain model       | Handler = load aggregate, call command, save. Queries read a read model |
| sla-policies | Core       | Domain model       | Same                                                                    |
| autopilot    | Core       | Domain services    | Handler = call a domain service function, save the result               |
| categories   | Supporting | Active record      | Handler = procedural code on the ORM record                             |
| schedules    | Supporting | Transaction script | Handler = a few SQL statements in a transaction                         |
| holidays     | Generic    | Transaction script | Same                                                                    |

```text
✅
📁 src/
├── 📁 modules/
│   ├── 📁 tickets/                          # core: domain model + CQRS
│   │   ├── 📁 domain/
│   │   │   ├── 📄 ticket.ts                 # aggregate, shared by every slice below
│   │   │   ├── 📄 priority.ts
│   │   │   ├── 📄 ticket-events.ts
│   │   │   └── 📄 response-deadline.ts      # domain service
│   │   ├── 📁 slices/
│   │   │   ├── 📄 escalate-ticket.ts
│   │   │   ├── 📄 close-ticket.ts
│   │   │   ├── 📄 assign-ticket.ts
│   │   │   ├── 📄 get-agent-inbox.ts        # query slice
│   │   │   └── 📄 get-ticket.ts
│   │   ├── 📁 infrastructure/
│   │   │   ├── 📄 ticket-repository.ts      # mapper row <-> Ticket, the one hand-written repository
│   │   │   └── 📄 agent-inbox.projection.ts
│   │   └── 📄 index.ts
│   ├── 📁 quotas/
│   │   ├── 📁 domain/
│   │   │   └── 📄 ticket-quota.ts
│   │   └── 📁 slices/
│   │       └── 📄 on-ticket-closed.ts       # reacts to tickets' event
│   ├── 📁 categories/                       # supporting: active record, no domain folder
│   │   └── 📁 slices/
│   │       ├── 📄 rename-category.ts
│   │       └── 📄 get-category-tree.ts
│   └── 📁 schedules/                        # supporting: transaction scripts
│       └── 📁 slices/
│           └── 📄 set-shift.ts
├── 📁 pipeline/
├── 📄 mediator.ts
└── 📄 main.ts
```

Two rules, one from each side:

- **Book:** a module is reached only through its `index.ts`. `tickets/domain/` imports nothing outside itself and `shared/`.
- **Talk:** nothing in `slices/` is imported by another slice.

---

## 3. A core slice and a supporting slice

Core: the aggregate is the book's, the slice is the talk's. The handler is the book's application service method lifted into its own file.

```ts
// modules/tickets/domain/ticket.ts
export class Ticket {
  escalate(reason: EscalationReason, now: Date): void {
    if (this.status === TicketStatus.Closed)
      throw new DomainError("Closed tickets cannot be escalated");
    if (this.isEscalated) throw new DomainError("Ticket is already escalated");

    this.isEscalated = true;
    this.respondBy = ResponseDeadline.shortenByThird(this.respondBy, now);
    this.raise({ type: "TicketEscalated", ticketId: this.id, reason, at: now });
  }
}

// modules/tickets/slices/escalate-ticket.ts
export type EscalateTicket = Request<TicketView> & {
  type: "EscalateTicket";
  ticketId: string;
  reason: string;
  requestedBy: string;
};

export const escalateTicketSchema = z.object({
  ticketId: z.string().uuid(),
  reason: z.enum(["sla-missed", "customer-request", "manager-override"]),
  requestedBy: z.string().uuid(),
});

register("EscalateTicket", async (cmd) => {
  const ticket = await tickets.load(TicketId.parse(cmd.ticketId));
  ticket.escalate(EscalationReason.parse(cmd.reason), clock.now());
  await tickets.save(ticket);
  return TicketView.from(ticket); // the book allows commands to return data from the consistent model
});
```

Supporting: categories are active record. No aggregate, no domain folder. The handler is procedural on the ORM, which is where the talk starts and, here, where it ends.

```ts
// modules/categories/slices/rename-category.ts
export type RenameCategory = Request<void> & {
  type: "RenameCategory";
  categoryId: string;
  name: string;
};

register("RenameCategory", async (cmd) => {
  const category = await db.category.findUniqueOrThrow({
    where: { id: cmd.categoryId },
  });
  const sibling = await db.category.findFirst({
    where: {
      parentId: category.parentId,
      name: cmd.name,
      NOT: { id: cmd.categoryId },
    },
  });
  if (sibling)
    throw new DomainError("A sibling category already has that name");

  await db.category.update({
    where: { id: cmd.categoryId },
    data: { name: cmd.name },
  });
});
```

Same outer shape (request, schema, handler), different inner shape (aggregate versus ORM call), **chosen by subdomain type, not by taste**. That is the talk's "blueprints" and the book's decision tree in one example.

---

## 4. Across aggregates: the outbox

The talk's stock example decrements stock in-process right after approving the order, either procedurally or through an in-memory domain event, inside one request. That works inside one database and one module.

The book adds: one aggregate per transaction, so across modules the event is written to an outbox in the same transaction as the aggregate and handled in a later transaction. The consumer is itself a slice in the other module.

```ts
// modules/tickets/slices/close-ticket.ts
register("CloseTicket", async (cmd) => {
  const ticket = await tickets.load(TicketId.parse(cmd.ticketId));
  ticket.close(User.parse(cmd.closedBy), clock.now()); // raises TicketClosed
  await tickets.save(ticket); // UPDATE tickets + INSERT outbox, one transaction
});

// modules/quotas/slices/on-ticket-closed.ts: a slice whose request is an event
on<TicketClosed>("TicketClosed", async (e) => {
  const quota = await quotas.load(TenantId.parse(e.tenantId));
  quota.release(TicketId.parse(e.ticketId), e.eventId); // idempotent on eventId
  await quotas.save(quota);
});
```

---

## 5. Behaviours are the book's application layer concerns

| Concern                         | Book's home                                          | Talk's home                                   |
| ------------------------------- | ---------------------------------------------------- | --------------------------------------------- |
| Open and commit the transaction | Unit of work port, called by the application service | Transaction behaviour, wraps every command    |
| Validate the incoming DTO       | Start of the application service                     | Validation behaviour, runs the slice's schema |
| Retry on `ConcurrencyError`     | Application service catches and retries              | Retry behaviour                               |
| Log request and response        | Not specified                                        | Logging behaviour                             |
| Turn strings into value objects | Application service                                  | Still the handler, it is per slice            |
| Pass in `now`                   | Application service, from a `Clock` port             | Still the handler                             |

---

## 6. Where the two disagree

**Ports and adapters versus "no abstractions until pain".** The book itself says almost nothing about repositories; its aggregate examples call `repository.load` and `save` as a given and its active record examples use the ORM directly. The `TicketRepository` interface with a Postgres adapter is the DDD notes' application of ports and adapters, not a rule from the book. Settle it per module with the decision tree:

- **Core, rich aggregate:** you need a mapper between rows and `Ticket` anyway, because the aggregate has private state and the row does not. That mapper is a repository. Give it an interface if you want to fake it in fast tests. Not speculative: it is the mapping Entity Framework did for Bogard for free (see `typescript-reference.md`, section 4).
- **Supporting, active record or transaction script:** no aggregate, no mapper, no repository. ORM in the handler, as the talk says.

**One application service per aggregate versus one handler per use case.** Same code either way. The talk's split is better for the talk's reasons: one file per feature, nothing shared between use cases, no class that grows forever. Nothing in the book depends on the methods sharing a class. Take the split.

**Where behaviour goes when a handler grows.** The talk says "push it down into the domain". The book says which part:

| The logic...                                           | Goes in                                                           |
| ------------------------------------------------------ | ----------------------------------------------------------------- |
| Changes one aggregate's state or guards its invariants | The aggregate, as a command                                       |
| Is a calculation with no identity                      | A value object or domain service                                  |
| Needs several aggregates or an external fact           | A domain service, called by the handler with everything passed in |
| Is only data access                                    | Stays in the handler, or a named query function if shared         |

**Event sourcing.** Not in the talk. Switching an aggregate to event sourcing changes its internals and the repository's `save` and nothing else. The slices do not change.

---

## 7. Tests

| Module                  | Book's shape | Per slice                                                                            |
| ----------------------- | ------------ | ------------------------------------------------------------------------------------ |
| tickets (core)          | Pyramid      | Many fast tests on `Ticket`, no mocks. One integration test per slice, real database |
| categories (supporting) | Diamond      | A few fast tests where a rule exists. Integration test per slice carries the weight  |
| schedules (supporting)  | Reversed     | Integration test per slice, almost nothing else                                      |

```ts
// Fast: the aggregate, no setup
test("escalation cuts the response limit by a third", () => {
  const ticket = Ticket.open({ priority: Priority.High, openedAt: t0 });
  ticket.escalate(EscalationReason.SlaMissed, t0);
  expect(ticket.respondBy).toEqual(
    ResponseDeadline.shortenByThird(originalDeadline, t0),
  );
});

// Slow: the whole slice, real database, black box
test("EscalateTicket marks the ticket escalated and returns the view", async () => {
  const id = await seedOpenTicket();
  const view = await send({
    type: "EscalateTicket",
    ticketId: id,
    reason: "sla-missed",
    requestedBy: agentId,
  });
  expect(view.isEscalated).toBe(true);
  expect((await db.ticket.findUnique({ where: { id } }))!.is_escalated).toBe(
    true,
  );
});
```

No test mocks `TicketRepository` to unit test the handler. The handler is three lines; the integration test covers it.

---

## 8. Cheat sheet

- The book decides the folders: one module per subdomain. The talk decides what is inside: one slice per use case plus the module's shared domain.
- A slice is request, schema, handler, response in one file. The handler is the book's application service method on its own.
- Core modules: load aggregate, call command, save. Supporting modules: procedural code on the ORM. Chosen by subdomain type, not by taste.
- Queries are slices too. They read a read model and never load an aggregate.
- Cross-aggregate effects are domain events. Across modules, through the outbox. The consumer is a slice in the other module.
- Behaviours carry what every request needs: validation, transaction, retry, logging.
- The one repository you write is the mapper a rich aggregate needs. Everything else uses the ORM directly.
- Fast tests on aggregates, one slow test per slice, no mocked layers.
