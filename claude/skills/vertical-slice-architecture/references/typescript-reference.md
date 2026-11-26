# TypeScript reference

The building blocks from the talk, written out so they can be copied. The mediator and pipeline are what MediatR gives you in .NET. Section 4 goes beyond the talk: it works out what "the ORM already is a repository" means for the TypeScript libraries you are likely to meet, because the talk's answer assumes Entity Framework.

## Contents

1. [Mediator](#1-mediator)
2. [Pipeline behaviours](#2-pipeline-behaviours)
   - [2.1 Do you need the mediator? Plain function, mediator, command bus](#21-do-you-need-the-mediator-plain-function-mediator-command-bus)
3. [A slice file](#3-a-slice-file)
4. [Repository or not, per library](#4-repository-or-not-per-library)
5. [Folder layout](#5-folder-layout)

---

## 1. Mediator

One request type, one handler, one response. `register` ties a handler to a request type at compile time; `send` infers the response from the request.

```ts
// mediator.ts
export interface Request<TResponse> {
  readonly type: string;
  readonly __response?: TResponse; // phantom field, exists only for the type checker
}

export type ResponseOf<T> = T extends Request<infer R> ? R : never;

// Every slice adds its own request type to this interface (declaration merging).
// The mediator file itself never lists them.
export interface RequestMap {}

type Handler<K extends keyof RequestMap> = (
  request: RequestMap[K],
) => Promise<ResponseOf<RequestMap[K]>>;

const handlers: Partial<{ [K in keyof RequestMap]: Handler<K> }> = {};

export function register<K extends keyof RequestMap>(
  type: K,
  handler: Handler<K>,
) {
  if (handlers[type]) throw new Error(`Duplicate handler for ${type}`);
  handlers[type] = handler;
}

export async function send<K extends keyof RequestMap>(
  request: RequestMap[K] & { type: K },
): Promise<ResponseOf<RequestMap[K]>> {
  const handler = handlers[request.type];
  if (!handler) throw new Error(`No handler for ${request.type}`);
  return handler(request);
}
```

Each slice file adds its request to `RequestMap` with a three-line block, the same trick Fastify, Vue and Express use for typed plugins:

```ts
// features/orders/approve-order.ts
declare module "../../mediator" {
  interface RequestMap {
    ApproveOrder: ApproveOrder;
  }
}

register("ApproveOrder", async (cmd) => {
  // cmd is ApproveOrder, inferred from the key
});
```

What keeps it type safe, with no cast anywhere:

- `register("ApproveOrder", ...)` infers the handler parameter as `ApproveOrder` from the key.
- `send(request)` infers the response type from the phantom field.
- A `send` with a type nobody added to `RequestMap` does not compile. The runtime `No handler for ...` check stays for callers outside TypeScript.

The route becomes a thin adapter:

```ts
router.post("/orders/:id/approve", async (req, res) => {
  await send({
    type: "ApproveOrder",
    orderId: req.params.id,
    userId: req.user.id,
  });
  res.sendStatus(204);
});
```

---

## 2. Pipeline behaviours

Behaviours wrap the handler. The first registered is outermost.

```ts
// mediator.ts, extended
export type Behaviour = <R>(
  request: Request<R>,
  next: () => Promise<R>,
) => Promise<R>;

const behaviours: Behaviour[] = [];
export function use(b: Behaviour) {
  behaviours.push(b);
}

export async function send<K extends keyof RequestMap>(
  request: RequestMap[K] & { type: K },
): Promise<ResponseOf<RequestMap[K]>> {
  const handler = handlers[request.type];
  if (!handler) throw new Error(`No handler for ${request.type}`);

  // First registered behaviour is outermost
  const run = behaviours.reduceRight(
    (next, behaviour) => () => behaviour(request, next),
    () => handler(request),
  );
  return run();
}
```

The four from the talk:

```ts
// pipeline/logging.ts
use(async (request, next) => {
  const started = Date.now();
  const response = await next();
  log.info({ type: request.type, request, response, ms: Date.now() - started });
  return response;
});

// pipeline/validation.ts: run the slice's schema before the handler sees the request
use(async (request, next) => {
  const schema = schemas.get(request.type);
  if (schema) schema.parse(request);
  return next();
});

// pipeline/transaction.ts: every command in a transaction, nobody can forget
use(async (request, next) => {
  if (!isCommand(request)) return next();
  return db.$transaction(() => next());
});

// pipeline/retry.ts: optimistic concurrency, a handful of attempts
use(async (request, next) => {
  for (let attempt = 1; ; attempt++) {
    try {
      return await next();
    } catch (e) {
      if (!(e instanceof ConcurrencyError) || attempt >= 3) throw e;
    }
  }
});
```

Order of wrapping, outermost first: logging, validation, retry, transaction, handler. Retry sits outside transaction so each attempt gets a fresh transaction; the failed one has rolled back before the next starts.

### 2.1 Do you need the mediator? Plain function, mediator, command bus

Beyond the talk. The talk's rule is one request, one handler; MediatR is only how Bogard wires them. Three ways to do that wiring, same slice files in every case:

| Option         | Route does                | Where behaviours go                            | When                                             |
| -------------- | ------------------------- | ---------------------------------------------- | ------------------------------------------------ |
| Plain function | `await approveOrder(cmd)` | Koa middleware, or wrapped by hand per handler | Small app, no cross-cutting concerns yet         |
| Mediator (§1)  | `await send(cmd)`         | Pipeline around every handler, typed response  | Default. Commands and queries, in process        |
| Command bus    | `await bus.dispatch(cmd)` | Same pipeline, plus the option to queue        | Commands that may run later or on another worker |

A command bus is the mediator with two differences: it carries commands only (queries go straight to the database), and `dispatch` may be asynchronous, so handlers return nothing and the route answers 202 with an id. When every command runs in process and returns a result, bus and mediator are the same thirty lines under a different name.

```ts
// shared/command-bus.ts
export interface CommandMap {} // each slice adds its command, as with RequestMap

type Handler<K extends keyof CommandMap> = (
  cmd: CommandMap[K],
) => Promise<void>;
type Middleware = (
  cmd: { type: string },
  next: () => Promise<void>,
) => Promise<void>;

export function createCommandBus(queue?: Queue) {
  const handlers: Partial<{ [K in keyof CommandMap]: Handler<K> }> = {};
  const middleware: Middleware[] = [];

  async function run<K extends keyof CommandMap>(
    cmd: CommandMap[K] & { type: K },
  ) {
    const handler = handlers[cmd.type];
    if (!handler) throw new Error(`No handler for ${cmd.type}`);
    const chain = middleware.reduceRight(
      (next, mw) => () => mw(cmd, next),
      () => handler(cmd),
    );
    return chain();
  }

  return {
    register<K extends keyof CommandMap>(type: K, handler: Handler<K>) {
      if (handlers[type]) throw new Error(`Duplicate handler for ${type}`);
      handlers[type] = handler;
    },
    use(mw: Middleware) {
      middleware.push(mw);
    },
    async dispatch<K extends keyof CommandMap>(
      cmd: CommandMap[K] & { type: K },
    ) {
      if (queue)
        await queue.push(cmd); // a worker calls run(cmd) later
      else await run(cmd);
    },
  };
}
```

```ts
// main.ts: composition root, the one file that knows every handler
const bus = createCommandBus();

bus.use(async (cmd, next) => {
  const t = Date.now();
  try {
    return await next();
  } finally {
    console.log(cmd.type, Date.now() - t, "ms");
  }
});
bus.use((cmd, next) => db.transaction(next));

bus.register("ApproveOrder", (cmd: ApproveOrder) => approveOrder(cmd));
bus.register("CancelOrder", (cmd: CancelOrder) => cancelOrder(cmd));
```

```ts
// routes.ts: imports no handler
router.post("/orders/:id/approve", async (req, res) => {
  await bus.dispatch({
    type: "ApproveOrder",
    orderId: req.params.id,
    userId: req.user.id,
    approvedByManager: req.user.isManager,
  });
  res.sendStatus(204);
});
```

Differences from the §1 mediator: `dispatch` returns nothing (no phantom response type), and registration happens in `main.ts` instead of inside each slice file. Same map, same `reduceRight` chain. With a `queue`, `dispatch` enqueues `cmd` and a worker calls `run()` from the same map.

**Recommendation: the §1 mediator with the `use()` list from §2.** Three reasons:

- **Typed responses.** Queries need `send(query)` to return the DTO type. The bus returns nothing, so queries end up outside it and lose the pipeline.
- **Registration in the slice file.** `register("ApproveOrder", ...)` next to the handler keeps the slice self-contained. A `main.ts` that lists every handler grows per feature and is a dumping ground.
- **Same code otherwise.** Map plus `reduceRight`.

Start with plain functions if there is no pipeline yet. Move to the mediator when the second behaviour (transaction after validation) shows up, because wrapping by hand in every handler is the duplication the refactor step removes. Go to a real bus only when a command must be queued or run on another process; that is a different thing (persistence, retries, no return value), not a swap.

---

## 3. A slice file

Everything for one use case in one file: request, schema, handler. The route is registered here too so the feature's entry point is not somewhere else.

```ts
// features/orders/approve-order.ts
import { z } from "zod";
import type Router from "@koa/router";
import { register, send, type Request } from "../../mediator";
import { orders } from "./order-repository";

export type ApproveOrder = Request<void> & {
  type: "ApproveOrder";
  orderId: string;
  userId: string;
  approvedByManager: boolean;
};

export const approveOrderSchema = z.object({
  orderId: z.string().uuid(),
  userId: z.string().uuid(),
  approvedByManager: z.boolean(),
});

declare module "../../mediator" {
  interface RequestMap {
    ApproveOrder: ApproveOrder;
  }
}

register("ApproveOrder", async (cmd) => {
  const order = await orders.load(cmd.orderId);
  order.approve(cmd.userId, cmd.approvedByManager, new Date());
  await orders.save(order);
});

export function routes(router: Router) {
  router.post("/orders/:id/approve", async (ctx) => {
    await send({
      type: "ApproveOrder",
      orderId: ctx.params.id,
      userId: ctx.state.user.id,
      approvedByManager: ctx.state.user.isManager,
    });
    ctx.status = 204;
  });
}
```

A query slice reads straight from the database and returns its own DTO:

```ts
// features/orders/list-approved-orders.ts
export type ListApprovedOrders = Request<ApprovedOrdersResponse> & {
  type: "ListApprovedOrders";
  customerId?: string;
  page: number;
  pageSize: number;
};

export type ApprovedOrdersResponse = {
  total: number;
  items: ApprovedOrdersResponse.Item[];
};

export namespace ApprovedOrdersResponse {
  export type Item = {
    id: string;
    customerName: string;
    approvedAt: string;
    total: number;
  };
}

register("ListApprovedOrders", async (q) => {
  const where = {
    status: "approved",
    ...(q.customerId && { customerId: q.customerId }),
  };
  const [total, rows] = await Promise.all([
    db.order.count({ where }),
    db.order.findMany({
      where,
      skip: (q.page - 1) * q.pageSize,
      take: q.pageSize,
      select: {
        id: true,
        approvedAt: true,
        total: true,
        customer: { select: { name: true } },
      },
    }),
  ]);
  return {
    total,
    items: rows.map((r) => ({
      id: r.id,
      customerName: r.customer.name,
      approvedAt: r.approvedAt.toISOString(),
      total: r.total,
    })),
  };
});
```

---

## 4. Repository or not, per library

Beyond the talk. Bogard's answer in the Q&A is "Entity Framework already is a repository, use `DbSet.Add` directly, write your own only when the client library gives you nothing". A repository here means three things:

- **Collection-like access.** Find by id, add, remove.
- **Unit of work.** Changes are tracked and written together.
- **Identity map or version check.** Loading the same thing twice gives the same object, or a stale save is rejected.

| Library                             | Already a repository?                                                           | What to do                                                                    |
| ----------------------------------- | ------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| TypeORM, MikroORM, Entity Framework | Yes, and your own class is the persisted entity                                 | Call it directly from the handler                                             |
| Prisma                              | Collection access and transactions, but returns its own objects, not your class | Direct for procedural handlers; a mapper once you have a domain class         |
| Mongoose                            | `findById`, `save` with change tracking, `__v` version key                      | Direct for procedural handlers; a mapper once you have a domain class         |
| Raw `mongodb` driver, raw `pg`      | No                                                                              | Write `load` and `save`; once two handlers share them, that is the repository |

**Why the talk never hits this.** Entity Framework maps plain C# classes that Bogard writes himself, so his `Order` is both the domain model with `Approve()` on it and the thing EF saves. "Push behaviour down into the domain" means onto that class and EF does the mapping for free. TypeORM and MikroORM give the same thing in TypeScript. Prisma and Mongoose return their own objects, so the mapping EF did for free is the thing you write by hand.

**Data model versus domain model.** A Mongoose document or Prisma result is a data model: the stored shape, owned by the library. Once the refactor step pushes behaviour "down into the domain", there are three places it can land:

1. **Procedural:** functions over the document, `approve(orderDoc, userId)`. Fine for simple logic.
2. **Active record:** `orderSchema.methods.approve = function () {}`. Behaviour on the data model. No private state, rules coupled to the library.
3. **Domain model:** your own `Order` class with the rules, plus a mapper from document to `Order` and back. The mapper is the small hand-written repository and this is the moment it earns its place.

### 4.1 TypeORM or MikroORM: the class is what gets saved

```ts
// features/orders/order.ts: domain model and persisted entity, same class
@Entity()
export class Order {
  @PrimaryKey() id!: string;
  @Property() status: "pending" | "approved" = "pending";
  @Property() approvedAt?: Date;
  @OneToMany(() => OrderLine, (l) => l.order) lines = new Collection<OrderLine>(
    this,
  );
  @Property({ version: true }) version!: number;

  approve(by: UserId, isManager: boolean, now: Date): void {
    if (this.status !== "pending")
      throw new DomainError("Only pending orders can be approved");
    if (this.lines.count() === 0)
      throw new DomainError("Cannot approve an empty order");
    if (this.total() > 10_000 && !isManager)
      throw new DomainError("Orders over 10k need a manager");
    this.status = "approved";
    this.approvedAt = now;
  }

  total(): number {
    return this.lines
      .getItems()
      .reduce((sum, l) => sum + l.qty * l.unitPrice, 0);
  }
}

// features/orders/approve-order.ts: no repository, the ORM is one
register("ApproveOrder", async (cmd) => {
  const order = await em.findOneOrFail(Order, cmd.orderId, {
    populate: ["lines"],
  });
  order.approve(cmd.userId, cmd.approvedByManager, new Date());
  await em.flush(); // unit of work: writes what changed, checks the version
});
```

### 4.2 Prisma or Mongoose: the class plus a small mapper

```ts
// features/orders/order.ts: domain model only, no library imports
export class Order {
  private constructor(
    readonly id: string,
    private status: "pending" | "approved",
    private approvedAt: Date | null,
    private readonly lines: ReadonlyArray<{ qty: number; unitPrice: number }>,
    readonly version: number,
  ) {}

  static restore(s: OrderSnapshot): Order {
    return new Order(s.id, s.status, s.approvedAt, s.lines, s.version);
  }

  snapshot(): OrderSnapshot {
    return {
      id: this.id,
      status: this.status,
      approvedAt: this.approvedAt,
      lines: this.lines,
      version: this.version,
    };
  }

  approve(by: UserId, isManager: boolean, now: Date): void {
    // same rules as above
  }
}

// features/orders/order-repository.ts: the hand-written part, document <-> Order
export const orders = {
  async load(id: string): Promise<Order> {
    const doc = await OrderModel.findById(id).lean().orFail();
    return Order.restore({
      id: doc._id.toString(),
      status: doc.status,
      approvedAt: doc.approvedAt ?? null,
      lines: doc.lines,
      version: doc.__v,
    });
  },

  async save(order: Order): Promise<void> {
    const s = order.snapshot();
    const res = await OrderModel.updateOne(
      { _id: s.id, __v: s.version },
      {
        $set: { status: s.status, approvedAt: s.approvedAt, lines: s.lines },
        $inc: { __v: 1 },
      },
    );
    if (res.matchedCount === 0) throw new ConcurrencyError(s.id);
  },
};

// features/orders/approve-order.ts: identical shape to the ORM version
register("ApproveOrder", async (cmd) => {
  const order = await orders.load(cmd.orderId);
  order.approve(cmd.userId, cmd.approvedByManager, new Date());
  await orders.save(order);
});
```

With MongoDB, one document is one aggregate and saves atomically. Reference other aggregates by id and avoid `populate` on the write path, or you are loading other aggregates just to change one.

---

## 5. Folder layout

```text
✅
📁 src/
├── 📁 features/
│   ├── 📁 orders/
│   │   ├── 📄 approve-order.ts           # command + schema + handler + route
│   │   ├── 📄 reject-order.ts
│   │   ├── 📄 change-shipping-address.ts
│   │   ├── 📄 get-order.ts               # query + response + handler + route
│   │   ├── 📄 list-approved-orders.ts
│   │   ├── 📄 order.ts                   # domain object shared by the slices above
│   │   ├── 📄 order-repository.ts        # only if the library is not already one (section 4)
│   │   └── 📄 index.ts                   # registers the routes
│   └── 📁 invoices/
│       └── ...
├── 📁 pipeline/
│   ├── 📄 logging.ts
│   ├── 📄 validation.ts
│   ├── 📄 transaction.ts
│   └── 📄 retry.ts
├── 📄 mediator.ts
├── 📄 db.ts
└── 📄 main.ts
```

Rules:

- Nothing in one slice is imported by another slice. A slice is a leaf.
- `order.ts` is shared by the slices in its feature folder, and starts as a folder, not a package (Q&A 3).
- Cross-cutting code lives in `pipeline/` and is registered once in `main.ts`.
- Nothing is named `OrderService`, `OrderManager` or `OrderHelper` (Q&A 9).
