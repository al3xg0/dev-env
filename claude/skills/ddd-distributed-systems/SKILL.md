---
name: ddd-distributed-systems
description: Domain-driven design applied to microservices, event-driven architecture and analytical data (data mesh), from Vlad Khononov's Learning Domain-Driven Design (Part IV, chapters 14 to 16). Use when deciding microservice boundaries (bounded context versus subdomain versus aggregate as a service), diagnosing a distributed big ball of mud, judging whether a service is too fine-grained or too chatty, designing asynchronous integration between services and choosing between event notification, event-carried state transfer and domain events, reviewing an event schema or topic design for temporal, functional or implementation coupling, or designing analytical data products, data warehouses, data lakes or a data mesh on top of bounded contexts. Also trigger on "should every aggregate be a microservice", "we subscribed to all their domain events", "events arrive out of order", "deep versus shallow services", "public versus private events", "star or snowflake schema", or "who owns the analytics model". Builds on ddd-strategic-design and ddd-architecture.
---

# DDD for microservices, event-driven architecture and data mesh

DDD is about boundaries: subdomains bound business capabilities, bounded contexts bound models, aggregates bound transactions. Microservices, event-driven architecture (EDA) and data mesh are all about boundaries too, and all three fail in the same way when boundaries are drawn by technology rather than by the business: the **distributed big ball of mud**, which is more fragile, clumsy and expensive than the monolith it replaced.

## Part 1: Microservices

### What "micro" means

A service is a mechanism giving access to capabilities through a prescribed interface, synchronous or asynchronous. The interface is the service's front door: everything in or out passes through it, and a well-expressed interface fully describes the service. A **microservice is a service with a micro public interface**, a micro front door. That is the whole definition. Not lines of code, not "rewrite rather than modify", not team pizza count.

This is why microservices never expose their databases. A database is an interface with effectively infinite operations (every possible query), so sharing it blows the front door wide open.

### Why "one method per service" fails

Take a backlog service with eight public methods and split it into eight services. Each now needs its own database and none can read the others', so to keep working together they all grow integration-only methods: tiny front doors plus enormous "staff only" entrances. Each service is simpler; the system is orders of magnitude more complex. You won the battle and lost the war.

**Local complexity** is the complexity inside one service. **Global complexity** is the complexity of the interactions and dependencies between services. A single monolith minimises global complexity and may maximise local complexity (big ball of mud). Over-decomposition minimises local complexity and explodes global complexity (distributed big ball of mud). The goal is the global optimum that balances both, not either extreme.

### Deep services

Picture a module as a rectangle: the top edge is the width of its public interface, the area is its logic. **Deep modules** hide a lot of logic behind a narrow interface. **Shallow modules** expose nearly as much interface as they contain logic (`AddTwoNumbers(a, b)` is the limit case) and add accidental complexity to the system. Shallow services are the reason so many microservices projects fail.

Cost of change falls as a monolith is decomposed, bottoms out at the microservices threshold where services are deepest, and rises again past it as interfaces grow back for integration reasons. The threshold is set by the system's use cases, not by a size rule.

### Which DDD boundary to use

| Boundary | Role | As a microservice? |
|---|---|---|
| **Bounded context** | Widest valid boundary: protects one consistent model and language, one owning team | Every microservice is a bounded context, but not every bounded context is a microservice. A wide context is the largest valid monolith, a legitimate design, not a big ball of mud. |
| **Subdomain** | A coherent set of use cases, one model, same or closely related data, strong functional relationship, change together | The **safe default**. Subdomains describe what the business does rather than how, which makes them naturally deep. Splitting a coherent set of use cases widens interfaces and makes modules shallow. |
| **Aggregate** | Narrowest valid boundary: a transaction and invariant boundary | Sometimes, for a non-functional reason (independent scaling). Usually too fine: the more the aggregate shares value objects, communicates with other aggregates and changes together with the rest of its subdomain, the shallower it is as a service, and global complexity rises. Never split an aggregate itself across services. |

The safe zone is between the bounded context (widest) and the microservices threshold (narrowest). Wider than a bounded context is a big ball of mud; narrower than the threshold is a distributed one. Which point in the zone to pick depends on the business domain, the organisation, the business strategy and non-functional requirements, and it should be revisited as these change.

### Compressing public interfaces

Two context integration patterns make services deeper:

- **Open-host service.** A published language exposes a restrained, integration-oriented model that hides implementation complexity, exposes less data in a more convenient shape, and lets the implementation evolve behind it. Narrower interface over the same logic, hence a deeper service and lower global complexity.
- **Anticorruption layer as a standalone service.** Moves integration complexity out of the consuming context into a dedicated service, so the consumer's model and interface stay focused on its business. Reduces both the consumer's local complexity and global complexity.

## Part 2: Event-driven architecture

EDA is components communicating asynchronously by exchanging event messages, instead of synchronous endpoint calls; the saga is the typical flow. It is **not** event sourcing: event sourcing captures state transitions inside a service and its events model the domain's intricacies; EDA is about communication between services. Events are not a sauce you pour over a system to make it loosely coupled. Applied carelessly they turn a modular monolith into a distributed big ball of mud.

### Events versus commands

Both are messages. An **event** describes something that has already happened and cannot be rejected; it can only be overturned by a compensating action. A **command** describes an operation to carry out and can be rejected by its target. Events are named in the past tense (`DeliveryScheduled`, `ShipmentCompleted`). A typical event has metadata (type, event id, correlation id, entity id, timestamp) and a payload.

### Three types of event

| Type | Payload | Purpose | Consistency fit |
|---|---|---|---|
| **Event notification** | Minimal: ids and a link to fetch details (`PaycheckGenerated` with `/paychecks/456123/2021/01`) | Tell interested parties something happened; they query for details | Consumer needs the **latest** state: the query returns it, can be authorised separately, avoids sending sensitive data over the bus, and can combine with pessimistic locking so only one competing consumer processes it |
| **Event-carried state transfer (ECST)** | Full snapshot of the entity's state, or just the changed fields, plus a version | Asynchronous **data replication**: consumers keep a local cache and keep working when the producer is down; backend-for-frontend aggregation without repeated queries | Consumer can live with **eventually consistent** data |
| **Domain event** | Everything describing the business event, in domain terms (`Married` with partner id and whether the surname was assumed) | Model the business domain; useful even with no external consumer, essential in event sourcing | Not designed for integration; no single domain event is enough to maintain a cache, and exposing them couples consumers to the implementation |

Same fact, three shapes: `marriage-recorded` with a details link (notification), `personal-details-changed` with the new surname but no reason (ECST), `married` with the partner and the name decision (domain event).

### Anatomy of a distributed big ball of mud

A CRM context is event sourced. Marketing subscribes to all its domain events and projects a flattened customer snapshot. AdsOptimization is added and does the same. Reporting subscribes to a subset of CRM events as notifications and fetches AdsOptimization's calculations, so AdsOptimization adds a five-minute processing delay to make sure Reporting runs after it. Three kinds of coupling:

- **Temporal coupling.** Reporting depends on AdsOptimization finishing first. The delay is a prayer, not a guarantee: overload, network delay or an outage breaks the order and corrupts Reporting.
- **Functional coupling.** Marketing and AdsOptimization implement the same projection for the same reason; a change must be made twice, in sync.
- **Implementation coupling.** Both subscribe to all CRM domain events. Any new event or schema change in the CRM must be mirrored in every subscriber or their projections break or go silently inconsistent.

Fix: the CRM follows the **consumer-driven contract** idea and projects the model its consumers need itself, publishing it as part of its published language (ECST events), so consumers never see the implementation model and the projection exists once. AdsOptimization publishes an **event notification** when its calculations are done, and Reporting fetches on receipt, removing the timer.

### Design heuristics

**Assume the worst.** The network will be slow, servers will fail at the worst moment, events will arrive out of order and duplicated, mostly at weekends and on public holidays. "Driven" means the whole system depends on message delivery, so reject the "it will be fine" mindset:

- Publish through the **outbox** pattern.
- Make consumers able to **deduplicate** and to detect and reorder out-of-order messages (ids, versions, sequence numbers).
- Use **sagas and process managers** for cross-context processes needing compensation.

**Public versus private events.** Treat events as part of the context's public interface. Do not leak domain events, above all event-sourced ones, outside the context. Under the open-host pattern the events in the published language are translated from internal events by a message proxy. Use ECST to compress the implementation model to what consumers need, event notifications to shrink the interface further, and domain events for integration only sparingly, preferably as a dedicated set of **public domain events**.

**Evaluate consistency requirements.** Eventually consistent is fine: ECST. Consumer must read the producer's last write: event notification followed by a query.

## Part 3: Analytical data and data mesh

### OLTP versus OLAP models

Operational (OLTP) models are built around business entities and their lifecycles, optimised for real-time transactions with predictable queries. Analytical (OLAP) models ignore entities and model business activities for unpredictable, flexible querying where seconds or minutes of latency are fine.

- **Fact tables** record business activities that happened (`Fact_Sales`, `Fact_CaseStatus`). Like domain events they are append-only; outdated data is superseded by appending a new record. Unlike domain events there is no past-tense naming rule, and granularity is chosen by the analysts (snapshots every 30 minutes rather than every change).
- **Dimension tables** describe facts (the adjectives to the facts' verbs), referenced by foreign key, highly normalised so facts can be filtered and grouped along any dimension.
- **Star schema**: facts with single-level dimensions. **Snowflake schema**: dimensions further normalised into multi-level dimensions; less storage and easier maintenance, more joins per query.

### Data warehouse and data lake, and why they strain

- **Data warehouse.** ETL from every operational system into one analytical model, possibly via a staging area, exposed through SQL. It is an enterprise-wide model, with all the problems of an enterprise-wide operational model. Data marts (per department) only partly help: either they still depend on the warehouse's enterprise model, or they ETL directly from operational systems and cross-mart queries become slow and awkward.
- **Data lake.** Ingest raw operational data first, build task-specific analytical models later, so several models and future models are possible. Cost: data engineers maintain several versions of the same ETL for several versions of the operational schema, and with no schema or quality control the lake becomes a swamp at scale.

Shared failures: thousands of unmaintainable ad hoc ETL scripts; ETL that reads operational databases directly, treating an internal schema as a public interface so any schema change breaks analytics; friction between operational and data teams that ends up freezing operational models; and data teams that know big data tooling but not the domain. These hurt most on DDD projects, where the operational model is expected to keep evolving.

### Data mesh: DDD for analytical data

Four principles:

1. **Decompose data around domains.** No monolithic analytical model. Align analytical models and their ownership with bounded contexts: each context's team owns both its operational and its analytical model and does the transformation.
2. **Data as a product.** Analytical data is served through well-defined **output ports**, treated like any public API: discoverable, with a schema, trustworthy with defined and monitored SLAs, versioned with managed breaking changes, designed for its consumers' needs, and **polyglot** (SQL, object storage, streams) to suit different consumers. Accountability for quality sits with the producing team, which needs data specialists added to the cross-functional team. Consumers combine fine-grained data products and apply local transformations.
3. **Enable autonomy.** A dedicated **data infrastructure platform team** provides data product blueprints, unified access patterns, access control, polyglot storage and monitoring so every team does not build its own serving stack.
4. **Build an ecosystem.** A **federated governance** group of context data and product owners plus platform representatives defines and enforces interoperability rules across all data products.

### DDD patterns that implement data mesh

- The **ubiquitous language** and domain knowledge are what traditional data teams lack; the owning context team has them.
- Exposing an analytical model distinct from the operational one is an **open-host service**: the analytical model is another published language.
- **CQRS** generates multiple models of the same data, so the analytical model is one more projection, rebuildable from scratch, and several schema versions can be served simultaneously.
- **Context integration patterns** apply between data products too: partnership on co-evolved analytical models, an ACL against a poor upstream data product, or separate ways with duplicated analytical models.

## Review checklist

- A service whose interface keeps growing for integration reasons, or that cannot complete an operation without calling others: probably decomposed past the threshold. Merge back towards the subdomain boundary.
- A monolith with conflicting models of the same term: wider than a bounded context. Split along the language.
- Consumers subscribed to a producer's full domain event stream: implementation coupling. Replace with a published language (ECST or public events) produced by the owner.
- Two consumers maintaining the same projection: functional coupling. Move the projection to the producer.
- Timers or delays used to order processing across services: temporal coupling. Use notifications plus queries, or a saga.
- No outbox, no idempotent consumers, no ordering strategy: the system is betting on a perfect network.
- Analytics ETL reading operational tables directly: give the context an analytical output port and own it there.
