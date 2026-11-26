---
name: vertical-slice-architecture
description: Vertical slice architecture (Jimmy Bogard) with domain-driven design, for backend services in any language; examples are TypeScript, the shapes map to C#, Go, Python, Java. Use when organising a service by feature instead of by layer, writing or reviewing a request/handler/response slice, a mediator, pipeline behaviours (logging, validation, retry, transaction), a query projecting straight to a DTO, or a command that loads a domain class, calls a method and saves. Also for deciding where new code goes (slice, module or bounded context), whether a repository is needed for a given ORM, mapping domain errors to HTTP status codes, testing slices without mocks, or migrating a layered, onion or clean codebase. Trigger on "vertical slice", "feature folder", "MediatR", "mediator vs command bus", "pipeline behaviour", "handler is getting long", "do I need a repository", "where does this code go", "slices vs bounded contexts". Pairs with the ddd skill.
---

# Vertical slice architecture with DDD

Layers sort code by technical job (routes, services, repositories). Every feature then spans five folders, every class grows forever, and any service may call any other. A vertical slice is the opposite cut: all the code for one request, in one place, along the axis of change. DDD decides where the folders go; slices decide what is inside them.

Examples use an EV charging domain (sessions, chargers, reservations) in TypeScript with Koa, zod and Prisma or Mongoose. Nothing depends on them: the same shapes are MediatR and FluentValidation in C#, a typed registry plus pydantic in Python, an interface-keyed map in Go. Translate the shape, not the syntax.

## 1. The two cuts

**Every request is a query or a command.** A query reads, is safe to repeat, needs no transaction. A command writes, is not safe to repeat, needs one. Test: does the system look different after it runs? CQRS, stripped of event sourcing and projections, means only this: where you had one `SessionService`, have two kinds of piece, one per request.

**One request, one handler, one response, one file.** The handler is a black box to the route. Two routes that need the same work send the same request; they never share a handler through a helper.

```text
✅
📁 src/
├── 📁 charging/                      # bounded context (DDD): its own words, its own tables
│   ├── 📁 sessions/                  # module (DDD): Session has rules and a lifecycle
│   │   ├── 📄 session.ts             # domain class, shared by the slices below
│   │   ├── 📄 session-store.ts       # load + save, write side only
│   │   ├── 📄 start-session.ts       # slice (command)
│   │   ├── 📄 stop-session.ts        # slice (command)
│   │   ├── 📄 get-session.ts         # slice (query)
│   │   ├── 📄 get-active-sessions.ts # slice (query)
│   │   └── 📄 index.ts               # routes + events this module exposes
│   ├── 📁 reservations/
│   ├── 📁 chargers/
│   └── 📁 shared/                    # value objects used by several modules
├── 📁 billing/                       # bounded context: "session" means a billable line here
├── 📁 pipeline/                      # behaviours: logging, validation, retry, transaction
├── 📄 errors.ts
├── 📄 mediator.ts
└── 📄 main.ts                        # imports every slice, error middleware, listen
```

| Level           | Question that creates one                                      | Decided by |
| --------------- | -------------------------------------------------------------- | ---------- |
| Bounded context | Does this part of the business use its own language and model? | DDD        |
| Module          | Does this thing have its own rules and its own lifecycle?      | DDD        |
| Slice           | Is this one thing a user can do?                               | VSA        |

Import rules: a slice imports its module's domain class and store, never another slice. A module is reached from outside only through `index.ts`. A bounded context never imports another context's files; it learns things through events. When a module passes about ten files, split it into `domain/` and `slices/`; the rules do not change.

**Naming, one word per meaning.** Queries start with `Get` and the noun says one or many: `GetSession`, `GetActiveSessions`. Never `List`, `Search`, `Find`, `Retrieve`. Commands start with the business verb: `StartSession`, `CancelReservation`. Never `Update`, `Set`, `Save`. File name is the request name in kebab-case.

## 2. The slice file

```ts
// charging/sessions/stop-session.ts
import type Router from "@koa/router";
import { z } from "zod";
import { NotFoundError } from "../../errors";
import { register, send, type Request } from "../../mediator";
import { schemas } from "../../pipeline/validation";
import { sessions } from "./session-store";

export type StopSession = Request<{ energyWh: number }> & {
  type: "StopSession";
  sessionId: string;
  meterStopWh: number;
};

export const stopSessionSchema = z.object({
  sessionId: z.string().uuid(),
  meterStopWh: z.number().int().nonnegative(),
});
schemas.set("StopSession", stopSessionSchema);

declare module "../../mediator" {
  interface RequestMap {
    StopSession: StopSession;
  }
}

register("StopSession", async (cmd) => {
  const session = await sessions.load(cmd.sessionId); // throws NotFoundError
  session.stop(cmd.meterStopWh, new Date());
  await sessions.save(session);
  return { energyWh: session.snapshot().energyWh };
});

export function routes(router: Router) {
  router.post("/sessions/:id/stop", async (ctx) => {
    ctx.body = await send({
      type: "StopSession",
      sessionId: ctx.params.id,
      meterStopWh: ctx.request.body.meterStopWh,
    });
  });
}
```

**Queries** project straight from the database to a per-screen DTO. No domain class in between, select only the columns the screen shows, map in the handler. Raw SQL in one handler is fine because only that screen is affected. Two screens with similar selects is fine; share a named function only when two handlers need exactly the same rows. A screen with no inputs still gets its own empty query type.

**Commands** are the form, not the domain model. Each field the user can edit is a field on the command, nothing else. Never bind a request body to a domain or database object. Task-based UI: one button, one command (`ExtendReservation`, `CancelReservation`), never one generic `UpdateReservation`. The query that fills an edit screen and the command that submits it may share a type.

**Command responses, four levels.** Start at the lowest that works.

| Level | Response                               | When                                             |
| ----- | -------------------------------------- | ------------------------------------------------ |
| 1     | `Request<void>`                        | Nothing to say, failure throws                   |
| 2     | `Request<{ ok: boolean }>`             | Caller branches on success                       |
| 3     | `Request<{ id: string }>`              | Something was created                            |
| 4     | `Request<Result<View, FailureReason>>` | The screen must show why it failed, or a payload |

## 3. Errors and status codes

Handlers and domain classes throw by kind. Only `main.ts` knows HTTP.

```ts
// errors.ts
export class DomainError extends Error {}
export class NotFoundError extends DomainError {}
export class ForbiddenError extends DomainError {}
export class ConflictError extends DomainError {}
export class ConcurrencyError extends ConflictError {}

// main.ts
function statusOf(err: Error): number | undefined {
  if (err instanceof ZodError) return 400;
  if (err instanceof NotFoundError) return 404;
  if (err instanceof ForbiddenError) return 403;
  if (err instanceof ConflictError) return 409;
  if (err instanceof DomainError) return 422;
  return undefined; // rethrow, becomes a 500
}
```

| Status | Meaning                                       | Example                              |
| ------ | --------------------------------------------- | ------------------------------------ |
| 400    | Malformed request (zod)                       | `meterStopWh` is a string            |
| 404    | The thing does not exist                      | Session not found                    |
| 403    | This caller may not touch it                  | Not your session                     |
| 409    | Wrong state, or someone else changed it first | Session is not active, stale version |
| 422    | Well formed but breaks a business rule        | Meter reading went backwards         |

Never rely on the ORM's own not-found exception (`findUniqueOrThrow`, bare `.orFail()`); it is not a `DomainError` and becomes a 500. Use `findUnique` plus `NotFoundError`, or `.orFail(() => new NotFoundError(...))`.

## 4. Mediator and pipeline

The mediator is a map from request type to handler (MediatR in .NET; in Go or Python a registry keyed by request type with a generic `send`). In TypeScript, declaration merging keeps it typed with no `any` and no cast: each slice adds its request to `RequestMap`, `register` infers the handler's parameter from the key, `send` returns exactly what the handler returns, a request type nobody registered does not compile, and a duplicate `register` throws at start-up.

```ts
// mediator.ts
export interface Request<TResponse> {
  readonly type: string;
  readonly __response?: TResponse; // phantom, never set
}
export type ResponseOf<T> = T extends Request<infer R> ? R : never;
export interface RequestMap {} // slices merge into this

type Handler<K extends keyof RequestMap> = (
  request: RequestMap[K],
) => Promise<ResponseOf<RequestMap[K]>>;
export type Behaviour = <R>(
  request: Request<R>,
  next: () => Promise<R>,
) => Promise<R>;

const handlers: Partial<{ [K in keyof RequestMap]: Handler<K> }> = {};
const behaviours: Behaviour[] = [];

export function register<K extends keyof RequestMap>(
  type: K,
  handler: Handler<K>,
) {
  if (handlers[type]) throw new Error(`Duplicate handler for ${type}`);
  handlers[type] = handler;
}
export function use(b: Behaviour) {
  behaviours.push(b);
}
export async function send<K extends keyof RequestMap>(
  request: RequestMap[K] & { type: K },
): Promise<ResponseOf<RequestMap[K]>> {
  const handler = handlers[request.type];
  if (!handler) throw new Error(`No handler for ${request.type}`);
  const run = behaviours.reduceRight(
    (next, behaviour) => () => behaviour(request, next),
    () => handler(request),
  );
  return run();
}
```

**Behaviours** wrap every handler, one file each under `pipeline/`, imported by `main.ts` in this order, which is nesting order, outermost first:

1. **Logging**, `try/finally` so failures are timed too.
2. **Validation**: `schemas.get(request.type)?.parse(request)`. A bad request fails before any transaction opens.
3. **Retry** on `ConcurrencyError`, three attempts. Outside the transaction so each attempt gets a fresh one.
4. **Transaction**, commands only (`!request.type.startsWith("Get")`). The handler must run on the transaction's client, not the global one; with Prisma hand `tx` down through `AsyncLocalStorage` and have `db()` return it, with Mongoose pass the `session`, MikroORM does this itself.

**Command bus**: the same map, commands only, `dispatch` may enqueue and return `202`. Reach for it only when a command must run later or on another process. Otherwise the mediator, because queries need typed responses and registration belongs in the slice file, not a composition root that grows by a line per feature.

## 5. Validation at three levels

| Level   | Question                            | Lives in                     | Fails with                                |
| ------- | ----------------------------------- | ---------------------------- | ----------------------------------------- |
| Request | Is the input well formed?           | zod schema in the slice file | `ZodError` 400                            |
| Command | May this happen, given the system?  | Handler, after load          | `NotFoundError` 404, `ForbiddenError` 403 |
| Domain  | May this happen, given this object? | Domain class method          | `ConflictError` 409, `DomainError` 422    |

A request-level check never touches the database; if it needs a lookup it is command level. A domain-level check never lives in the handler; if two handlers would need the same `if` about a session's state, it belongs on `Session`. Throw by default; return a `Result` (response level 4) only when the screen shows the reason.

## 6. Handlers start procedural, then refactor by smell

The first version of a handler is plain code against the ORM: load the rows, `if` statements, save. No repository, no service, no interface. Shape is always load, do your junk, save.

Every pull request, read the handler and look for the one smell that matters: long method. Fixes in order: extract methods inside the slice file; if the extracted methods are about one thing, push them down into a class for that thing; keep going inside the class. An encapsulated, testable domain does not arise naturally; it is worked towards from procedural code.

**The domain class** is the one place a class appears, because it has state to protect. Private constructor, `static restore(snapshot)`, `snapshot()`, `version` for optimistic concurrency, methods named for what the user does, no library imports, no decorators. Which part of the logic goes where, from DDD:

| The logic                                          | Goes in                                          |
| -------------------------------------------------- | ------------------------------------------------ |
| Changes one thing's state or guards its invariants | The domain class, as a method                    |
| Is a calculation with no identity                  | A value object or domain service in `shared/`    |
| Needs several objects or an external fact          | A domain service, called by the handler          |
| Is only data access                                | The handler, or a named query function if shared |

**Repository or not, per library.**

| Library                      | What you get                               | What to do                                                                                                                                                        |
| ---------------------------- | ------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Entity Framework, Hibernate/JPA, TypeORM, MikroORM, SQLAlchemy ORM | Your class is the entity; change tracking and unit of work built in | Call the ORM from the handler. It already is the repository |
| Prisma, Mongoose, GORM, sqlx, raw drivers | Collection access; returns its own records, not your class | Stage 1 procedural; stage 2 `restore`/`snapshot` inline in the handler; stage 3 a store with `load` and `save` once a second handler needs the mapping |

Rules for the store: write side only (`load`, `save`, nothing else). No `findActive`, no `findByCharger`; a method per query is the dumping ground layers had. Queries never use it. `save` filters on `version` and throws `ConcurrencyError` when nothing matched.

**Blueprint by subdomain.** Same outer shape everywhere (request, schema, handler, route), inner shape chosen by DDD's subdomain type, not taste. Core: load the class, call a method, save. Supporting: procedural on the ORM, and it stays that way. Generic: procedural or a library. Keep two or three blueprints in the codebase, no more.

## 7. Between modules and contexts

Inside one bounded context either works, both in one transaction: **orchestration** (the handler loads and saves both objects in order) or **choreography** (the class raises an in-process event, a slice in the other module handles it, so `sessions/` no longer knows chargers exist). A choreography handler never runs if the domain method threw.

Across bounded contexts: choreography only, the event written to an outbox in the same transaction as the save, consumer is a slice in the other context, idempotent on the event id. See the ddd skill (references/architecture.md) for the outbox and relay.

## 8. Testing

- **One slow test per slice**, through `send`, against a real database (test container or local instance, reset between tests), asserting on rows. It runs the whole pipeline. It does not change when the handler goes from procedural to domain class.
- **Fast tests on the domain class**, one per rule, no setup, no database, no mediator.
- **No mocks between layers.** The handler has no interface in front of the database, so it has no unit test. Logic in a handler that deserves a unit test is the signal to push it down.
- Fast and slow, not unit and integration. The pyramid is closer to a square and that is fine.

## 9. Migrating a layered codebase

1. **Defactor first.** Take one request. Inline the service method into the controller, the repository method into that, until all the code sits in one place. Then refactor forward into a slice.
2. **The whole team agrees** and does it the same way.
3. **Complete or roll back.** Half a codebase in each style is worse than either.

## Review checklist

- A handler imports another slice, or two routes share a handler through a helper: send the same request instead.
- A query loads the domain class or goes through the store: read straight to a DTO.
- A command type mirrors the table or the domain object: cut it to the form's fields.
- Request named `ListX`, `FindX`, `UpdateX`, `SetX`: rename to `GetX` or the business verb.
- `register<X>("X", ...)`, `any` or a cast in the mediator: use `RequestMap` declaration merging.
- Slice exports a schema nothing registers: `schemas.set(type, schema)` next to it.
- Transaction behaviour wraps `next()` but the handler uses the global client: route the transaction client through `AsyncLocalStorage`.
- Retry inside the transaction, or validation inside it: reorder to logging, validation, retry, transaction.
- Every domain failure is a 400, or the ORM's not-found leaks as a 500: use the error family and `statusOf`.
- Store has `findX` methods, or a query reads through it: write side only, one named query function per shared lookup.
- A repository interface, service and factory on a supporting module: procedural on the ORM is the blueprint there.
- Handler unit test with a mocked database: delete it, keep the slice test, push the logic into the class.
- Slices in one module factored three different ways: pick one of the blueprints.
- Two bounded contexts importing each other's files: events through an outbox.

## Reference files

- `references/typescript-reference.md`: copy-ready TypeScript for the mediator, pipeline behaviours, plain function versus mediator versus command bus, a command and a query slice file, repository-or-not per library (TypeORM, MikroORM, Prisma, Mongoose, raw driver) with both code paths, and the folder layout.
- `references/slices-meet-ddd.md`: the talk's vocabulary against Learning DDD, modules by subdomain with slices inside, a core slice and a supporting slice side by side, the outbox across aggregates, behaviours as application-layer concerns, where the two disagree, test shapes per subdomain.
- `references/talk-qa.md`: Bogard's answers on validation placement, ids, shared code, when to refactor, no mocks, teams that cannot refactor, migrating from clean or n-tier, shared domain objects, data access without repositories, consistent style, communicating between slices, aggregates without repositories.
