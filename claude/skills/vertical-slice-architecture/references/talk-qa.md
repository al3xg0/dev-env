# The live Q&A

Thirty minutes of questions after the talk, in the order asked. Each answer is Bogard's position, paraphrased closely.

## Contents

1. [Input validation and business rules: separate classes or in the handler?](#1-input-validation-and-business-rules-separate-classes-or-in-the-handler)
2. [Security says do not return ids from created elements](#2-security-says-do-not-return-ids-from-created-elements)
3. [Multi-module projects for shared domain, factories, common code](#3-multi-module-projects-for-shared-domain-factories-common-code)
4. [When is the right time to refactor?](#4-when-is-the-right-time-to-refactor)
5. [No mocks, more integration tests](#5-no-mocks-more-integration-tests)
6. [What if the team cannot refactor? Isn't this a big ball of mud?](#6-what-if-the-team-cannot-refactor-isnt-this-a-big-ball-of-mud)
7. [Migrating from clean or n-tier](#7-migrating-from-clean-or-n-tier)
8. [Avoiding shared domain objects between slices](#8-avoiding-shared-domain-objects-between-slices)
9. [Extracting data access without creating repositories again](#9-extracting-data-access-without-creating-repositories-again)
10. [Consistent code style between slices](#10-consistent-code-style-between-slices)
11. [Communicating between slices](#11-communicating-between-slices)
12. [Adding and removing aggregates without repositories](#12-adding-and-removing-aggregates-without-repositories)

---

## 1. Input validation and business rules: separate classes or in the handler?

Separate classes, organised alongside the handler. Single responsibility still applies, but the responsibilities are scoped to the slice. The validator sits next to the handler in the same slice. It moves to a shared location only when it is genuinely used by several use cases.

```text
features/orders/
└── change-shipping-address.ts   # command, validator, handler: separate classes, one place
```

## 2. Security says do not return ids from created elements

Nothing to do with vertical slices, but it comes up. What security teams mean is: do not return an easily guessable id, a numerically increasing identity column. Keep that as the primary key and expose a separate id, a GUID, that is also unique and indexed. Something has to identify the thing; it just must not be the sequential primary key.

```ts
// Internal primary key stays private. The public id is a uuid, unique and indexed.
await db.order.create({ data: { publicId: randomUUID(), ...cmd } });
return { id: order.publicId };
```

## 3. Multi-module projects for shared domain, factories, common code

Some things are intended to be shared across slices, the domain objects above all: approve, reject and cancel invoice all deal with an invoice, so `Invoice` has to live somewhere. That starts as a **folder**, `domain/`, inside the application.

He only creates separate projects, modules or assemblies when the deployment architecture forces it: two deployed applications that must share the same code. Not before. The same goes for "core", "common", factories and the rest. If code is meant for one slice it stays in the slice. If it is meant for several slices it moves to a shared folder. It moves to a separate assembly only when several deployed consumers need it. YAGNI.

## 4. When is the right time to refactor?

Every pull request. He assumes the developer has analysed the code they just wrote. The team may not do strict red-green-refactor, there may not even be a red, but there must be an analysis step for every feature: what smells are here, is a refactoring warranted. The first code that came out of your fingers is not what you submit.

On top of that, as tech lead he watches for duplicate code across slices, because an individual developer may not know the same thing exists elsewhere. When similar operations show up on two screens, it becomes a business conversation: should these be the same, should a change here always affect there? That makes sharing a deliberate business decision instead of an accident of layering.

Any time you touch the code base is an opportunity to leave it better than you found it.

## 5. No mocks, more integration tests

The testing pyramid got a wider base, more square than triangular. The rule: **every slice has an integration test.** Push a request in, the handler runs with its full set of dependencies under test control, check the response. A black box. That test is what says the feature is done.

Unit tests still exist but far fewer of the mock-heavy kind. In layered applications every layer mocks the one below, so the system as a whole is never tested, only the mock of the layer below. Those tests were the most brittle: they passed and the system failed, and every refactor meant rewriting them because the mocked method no longer looked like that.

The team stopped saying unit and integration and said **fast tests** (in memory) and **slow tests** (out of process). Kent Beck's unit was never "a class with mocked dependencies"; it is bigger. Tests should enable refactoring, not prevent it. Mock-everything tests prevented it, so they went.

Because handlers have no abstractions over the database, there are no unit tests of handlers. If a piece of business logic inside a handler deserves a unit test, refactor it out into something unit testable, typically by doing the data access first and then delegating to the domain. The integration test still has to be written regardless, because ORMs are among the most complex software on the planet and cannot be skipped.

```ts
// Slow test: real database, through the mediator, black box
test("approving a pending order marks it approved", async () => {
  const id = await seedPendingOrder({
    lines: [{ sku: "A1", qty: 2, unitPrice: 10 }],
  });

  await send({
    type: "ApproveOrder",
    orderId: id,
    userId: "u1",
    approvedByManager: false,
  });

  const row = await db.order.findUniqueOrThrow({ where: { id } });
  expect(row.status).toBe("approved");
  expect(row.total).toBe(20);
});

// Fast test: pure domain, no setup
test("orders over 10k need a manager", () => {
  const order = Order.pending([{ sku: "A1", qty: 1, unitPrice: 12_000 }]);
  const result = order.approve("u1", false, new Date());
  expect(result).toEqual(fail({ reason: "needs-manager" }));
});
```

## 6. What if the team cannot refactor? Isn't this a big ball of mud?

The co-host's objection: this sounds reasonable for a team with ten-plus years of experience who know the smells and refactor fluently, but many teams can barely extract a method, so they adopt vertical slices, skip the refactoring, and end up with an abstraction-free big ball of mud.

Bogard: more a pile of smaller balls of mud. But he has been both ways. In the onion-style project the services still got big and nasty. The layered approach did not save them from the big ball of mud; the only thing it added was coupling. Logic gets complicated inside well-defined boxes too, and the refactoring step is still required there. It is not possible to enumerate up front every primitive and pattern that logic should fall into; there has to be a design step, and sometimes nothing fits the boxes.

So he prefers to leave the door open for the team to extract a design from what is there rather than prescribe one up front. That is also why he wants someone who knows what they are doing on the team with a design focus. This is not a licence for a bunch of procedural code; the extra step is stressed to every team.

## 7. Migrating from clean or n-tier

First, it is not either/or. You can do n-tier or clean with vertical slices, and the clean architecture advocates in the .NET space recommend vertical slices too. The difference is that he stays away from clean's prescriptiveness, because nothing saves you from thoughtful design and refactoring anyway.

Tips:

- **Defactor first.** When he joins an application he does not understand, he reverses the refactorings for one request: inline methods, inline classes, inline, inline, until all the logic for that request sits in the controller action or whatever the top-level entry is. Then step back, see what the work actually is, and refactor forward from there. (His refactoring talk on this ends up as an advert for JetBrains tools, which do it safely.)
- **The whole team must agree** the migration is worth the work.
- **Complete or roll back.** Do not refactor three or four controllers and abandon it, leaving the next person wondering why half the code looks one way and half another. Either migrate to the target architecture fully, or treat it as an experiment and roll it back fully. Consistency in an application matters more than any one person's opinion of the month.

## 8. Avoiding shared domain objects between slices

You do not have to share objects between slices. Some teams, pure Dapper for instance, share nothing. Your persistence framework has to lend itself to that.

He usually finds it advantageous to share: multiple operations deal with the same entity in the database, so representing it once makes sense. Even with a document database, several operations touch the same document. You could go to all stored procedures and have no objects at all, but there is still a shared table underneath, and he does not want to go back to the stored procedure days.

## 9. Extracting data access without creating repositories again

A good question. Call it an encapsulated data access object rather than a repository, because repository is a specific pattern. Two handlers with the same query is the signal to pull the common code into one place, and one option is an orders repository with a method for each shared query. It is not the only option.

What he avoids, for data access and business logic alike, are **generic objects with no specific intent**: `OrderRepository`, `OrderDataAccess`, `OrderGateway`, `OrderService`, `OrderManager`. They describe a kind of operation, not an operation, and become dumping grounds. Instead, model the specific operation explicitly:

- not `OrderRepository.getApprovedOrders()` but a `GetApprovedOrders` query object, one class for one encapsulated query;
- not `OrderService.approve()` but an `OrderApprover` that owns the responsibility of approving orders and can be reused by anything that approves orders.

```ts
// Dumping ground
class OrderRepository {
  findApproved() {}
  findPending() {}
  // ...
}

// One class, one responsibility, a name that says what it does
export async function approvedOrdersFor(
  customerId: string,
): Promise<ApprovedOrder[]> {
  // ...
}
```

## 10. Consistent code style between slices

Not just important, essential. Individual opinions must not leak into a code base that will outlive everyone on the team. Code bases over a decade old show clearly where someone read a book, got excited about a pattern and injected it, instead of sticking with the established style.

Not every handler has to look identical, but he has seen one slice factored into twenty folders of one-line methods, factories and managers because its author liked mocks, next to a slice that is plain procedural code. So he keeps **blueprints** for developers:

1. Simple: procedural code, it looks like this.
2. More complex: push behaviour down into the domain, it looks like this.
3. Anything beyond those two: let's talk, look at the code together, design it.

Asked whether using different patterns per slice is not an advantage of slices: the goal is encapsulation. If something gets too big or complex a slice _could_ differ, but that is not permission to do whatever you want whenever you want. Microservices made the same promise (this one Rails, that one Django, that one Go) and someone has to maintain all of it.

## 11. Communicating between slices

A slice is a request from the end user. Two user operations are separated in time: the user does one, waits for the result, does the other. So at the application level there is no communication between slices to begin with.

What is really being asked: approving an order must decrement stock. That is a change needing to happen in a separate area of the system, and the question is the most appropriate way to effect it:

- **Procedurally in the handler:** approve the order, decrement the stock, in order. Orchestration.
- **In-memory messaging:** the aggregate raises a domain event, a domain event handler decrements the stock. Choreography. This moves from imperative to notification style and removes the direct coupling from one to the other.

Both happen within the context of a single request. It is a question of orchestration versus choreography between two aggregates or two areas of the system, and it is almost always happening at the domain layer, not slice calling slice.

```ts
// Orchestration
register("ApproveOrder", async (cmd) => {
  const order = await orders.load(cmd.orderId);
  order.approve(cmd.userId, cmd.approvedByManager, new Date());
  await orders.save(order);

  for (const line of order.lines) {
    const item = await stock.load(line.sku);
    item.decrement(line.qty);
    await stock.save(item);
  }
});

// Choreography: the aggregate raises, a handler elsewhere reacts, same request
export class Order {
  approve(by: UserId, isManager: boolean, now: Date): void {
    // ...rules...
    this.raise({ type: "OrderApproved", orderId: this.id, lines: this.lines });
  }
}

on<OrderApproved>("OrderApproved", async (e) => {
  for (const line of e.lines) {
    const item = await stock.load(line.sku);
    item.decrement(line.qty);
    await stock.save(item);
  }
});
```

## 12. Adding and removing aggregates without repositories

It depends on the data access framework. Moving away from the _abstract_ repository is possible because Entity Framework already implements the repository pattern, the identity map and the unit of work. `DbContext.DbSet.Add` is "add aggregate". Use the tool at hand.

Where the client library does not implement those patterns, he implements the repository himself. So it is not that the code moves somewhere else: use the repository the framework gives you, and write one only when the framework does not.
