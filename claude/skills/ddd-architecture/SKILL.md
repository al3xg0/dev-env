---
name: ddd-architecture
description: Architectural and communication patterns for a bounded context, from Vlad Khononov's Learning Domain-Driven Design (chapters 8 and 9). Use when organising a service's codebase (layered architecture, service or application layer, ports and adapters, hexagonal, onion, clean architecture), when deciding whether to adopt CQRS and how to project read models, when wiring business logic to databases, message buses and external APIs, or when implementing cross-context communication, including anticorruption layers and open-host services (stateless proxies, API gateways, message proxies, stateful translation, interchange contexts), the outbox pattern for reliably publishing domain events, sagas and process managers for workflows that span aggregates. Also trigger on "events get published but the transaction rolled back", "how do I publish domain events reliably", "where does this adapter go", "should commands return data", or "saga versus process manager". Pairs with ddd-tactical-design (which business logic pattern is in use decides the architecture).
---

# DDD architecture and communication patterns

Business logic is the heart of the software, but a codebase also has to take input, produce output, persist state and talk to other systems. Without an organising principle the logic diffuses into controllers, stored procedures and duplicated helpers, and every change becomes a hunt. Architectural patterns draw the boundaries between business logic and everything else; communication patterns make the flow between components reliable.

The patterns here are chosen per business logic pattern, and per module, not once for the whole system.

## Part 1: Organising a bounded context

### Layered architecture

Horizontal layers, each a technical concern, with a strict top-down dependency: each layer references only the layer directly beneath it.

- **Presentation layer** (user interface layer): every way the outside world triggers behaviour or receives output, synchronous or asynchronous: GUI, CLI, REST or gRPC API, message broker subscriptions and the topics the system publishes to. It is the program's public interface.
- **Business logic layer** (domain or model layer): where business decisions are made, using transaction scripts, active records or a domain model.
- **Data access layer** (infrastructure layer): all persistence and integration: operational database, search index, caches, object storage, an internal message bus, and external APIs and managed cloud services.

**Service layer** (application layer) is an optional fourth layer between presentation and business logic. It is a façade exposing one method per public operation, holding the orchestration (start transaction, create or load objects, call them, commit or roll back, build the result) so that controllers only pass input in and responses out. Benefits: one orchestration serves several presentations (web, API, CLI), related operations gather in one place, and business functionality is testable without the UI. It is a logical boundary, never a physical service.

When to add a service layer: required when the business logic pattern needs external orchestration, which is the case for **active record** (the service layer is the transaction script; the active records sit in the business logic layer). Redundant when the business logic already is a transaction script, since the service layer would merely repeat its interface.

When to use layered architecture: when business logic is a **transaction script or active record**. Its top-down dependency makes the business logic depend on data access, which is exactly what a domain model must not do, so a domain model fits awkwardly here.

Layers are logical and share one lifecycle. Tiers (browser, reverse proxy, web server, database server) are physical and independently deployable. Do not confuse the two.

### Ports and adapters

Also known as hexagonal, onion and clean architecture. Same components and relationships; different names for the layers (application = service = use case layer; business logic = domain = core layer). Treating them as different patterns is a failure of ubiquitous language.

Derivation from the layered model: merge presentation and data access into one **infrastructure layer** (both are integration with external technology), apply the **dependency inversion principle** so the business logic depends on nothing, and add an **application layer** as the façade for the public interface. Result: business logic at the centre, application layer around it, infrastructure on the outside.

Mechanics: the business logic layer declares **ports** (interfaces it needs, such as `IMessaging` with `Publish` and `Subscribe`, or a repository interface). The infrastructure layer provides **adapters** (concrete implementations such as an SQS or Kafka bus, a Postgres repository). Ports are bound to adapters by dependency injection or at bootstrap.

When to use: business logic implemented as a **domain model** or **event-sourced domain model**, because aggregates and value objects must have no knowledge of infrastructure.

Placement rule: any integration with a database, message bus, cloud service or external API is an adapter in the infrastructure layer. Never in the business logic layer, never in the application layer.

### CQRS (command-query responsibility segregation)

Same organising principles as ports and adapters, but the system keeps **several persistent models of the same data**. Reasons: OLTP and OLAP need different shapes; polyglot persistence (a document store for operations, a column store for analytics, a search engine for full-text, flat files for fast retrieval) because every database is flawed in its own way; and event sourcing, which cannot query across aggregates by state at all.

CQRS is useful without event sourcing. Event sourcing is not usable without CQRS.

**Command execution model.** The single model that executes state-changing operations. It implements the business logic, validates rules, enforces invariants, is the only strongly consistent model, is the source of truth, and must support reading current state and optimistic concurrency on update.

**Read models (projections).** As many as needed, each a precached projection in a durable database, file or in-memory cache. Strictly read-only; no operation writes to them. A correct implementation can wipe any projection and rebuild it from scratch, which also allows adding projections nobody foresaw.

**Projecting read models**, the equivalent of a materialised view:

- **Synchronous (catch-up subscription).** The projection engine queries the command model's storage for records added or changed after the last checkpoint, updates the read models, stores the new checkpoint. Requires the storage to stamp every write with a monotonically increasing checkpoint (for example a `rowversion` column, or a maintained counter) and to guarantee that a query after checkpoint 10 never later returns a record below 10. Rebuilding a projection is trivial: reset the checkpoint to zero.
- **Asynchronous.** The command model publishes committed changes to a message bus; projection engines subscribe. Scales better, but duplicated or out-of-order messages corrupt projections and rebuilding is hard.

Rule: **always implement synchronous projection**, and add asynchronous projection on top only where its scale is needed.

**Model segregation rules.** Commands operate only on the command execution model. Queries never modify any persisted state. A common misconception is that commands must return nothing and callers must read results from a projection; that produces round trips and a poor user experience. **Commands should return data**: whether they succeeded, why they failed (validation versus technical), and the resulting state when the UI needs it. The only constraint is that returned data must come from the strongly consistent command model, never from an eventually consistent projection.

When to use CQRS: the same data must be served in several models or several databases, or the business logic is event sourced.

### Scope: slices, not system-wide rules

None of these patterns is a system-wide or even bounded-context-wide law. A bounded context typically spans several subdomains of different types, and even subdomains of the same type may need different business logic and architectural patterns. Imposing one architecture across all of them creates accidental complexity.

Partition vertically as well as horizontally: define logical module boundaries per subdomain inside the context, and pick the fitting pattern for each slice (layered with active records in the supporting module, ports and adapters with a domain model in the core module). This makes a monolithic context a modular one and keeps it from becoming a big ball of mud. Those logical boundaries are what can later be extracted into separate bounded contexts if the business requires it.

### Pattern selection summary

| Business logic pattern | Architecture | Notes |
|---|---|---|
| Transaction script | Layered (no separate service layer needed) | Scripts are the application layer |
| Active record | Layered with a service layer | Service layer holds the transaction scripts |
| Domain model | Ports and adapters | Optionally CQRS when multiple models are needed |
| Event-sourced domain model | Ports and adapters plus CQRS | CQRS mandatory for querying |

## Part 2: Communication across components

### Model translation (implementing ACL and OHS)

When a downstream context will not conform to an upstream model, one side translates: the downstream through an **anticorruption layer**, the upstream through an **open-host service** that exposes a **published language**. The translation logic is the same shape in both cases.

**Stateless translation** maps one model to the other on the fly, using the proxy pattern.

- *Synchronous.* Embed the transformation in the context's codebase: an OHS translates incoming requests into its internal model and responses into the published language; an ACL translates outgoing calls to the upstream. Alternatively offload it to an **API gateway** (Kong, KrakenD, AWS API Gateway, Apigee, Azure API Management). For an OHS a gateway also makes serving several versions of the published language straightforward. An ACL built as a gateway can be shared by several downstream contexts; it then becomes an **interchange context**, a bounded context whose job is translating models for others.
- *Asynchronous.* A **message proxy** subscribes to the source's messages, transforms them, optionally filters out noise, and forwards to the target. This is essential for an OHS: publishing raw domain events exposes the implementation model. Intercept them and convert to published-language events instead. This is also what separates **private events** (internal) from **public events** (integration contracts).

**Stateful translation** is needed when translation must aggregate or unify data and therefore needs its own storage.

- *Aggregating incoming data*: batching requests for throughput, or combining several fine-grained messages into one unified message. Cannot be done in an API gateway. Consider stream processors (Kafka Streams, Kinesis) or batching tools (NiFi, Glue, Spark) before writing a custom one.
- *Unifying multiple sources*: the backend-for-frontend pattern, or an ACL in front of a context that must process data from many other contexts so that integration complexity stays out of the business logic.

### Outbox: publishing domain events reliably

Two tempting implementations are wrong:

1. **Publishing from inside the aggregate** as the command runs. The event goes out before the new state is committed, so subscribers may act on a state that contradicts the database; and if the transaction later fails the event cannot be retracted.
2. **Publishing from the application layer after the commit.** If the bus is down or the process dies between commit and publish, the state is saved but the event is lost forever.

The **outbox pattern** fixes both:

1. Commit the aggregate's new state **and** its new domain events in the **same atomic transaction**. With a relational database use a dedicated outbox table. With a NoSQL store lacking multi-document transactions, embed an `outbox` array of unpublished events inside the aggregate's document.
2. A **message relay** fetches unpublished events, either by **polling** (needs proper indexes to keep load down) or by **transaction log tailing** / change streams (Postgres logical decoding, DynamoDB Streams and similar).
3. The relay publishes to the bus, then marks the event published or deletes it.

Guarantee: **at least once** delivery. If the relay dies after publishing and before marking, the event is published again, so consumers must be idempotent. The same relay can execute other side effects reliably, such as commands issued by a saga (below).

### Saga: a process spanning several aggregates

An aggregate is a transaction boundary; one instance per transaction. When a business process must span several aggregates or contexts (campaign activated, so submit materials to the publisher; on confirmation mark the campaign published; on rejection mark it rejected) do not merge the entities into one aggregate. Implement a **saga**.

A saga is a long-running process in the sense of spanning **multiple transactions**, from seconds to years. It listens to events from the participating components and issues commands to others. If a step fails, the saga issues **compensating actions** to restore consistency. It is **instantiated implicitly** by a triggering event (`CampaignActivated`).

A simple saga is stateless: each handler loads what it needs, calls the next command, done. A saga that must track what it has already done (so it can compensate) is implemented as an **event-sourced aggregate** recording received events and issued commands. In that case, move command execution out of the saga: the saga appends a `CommandIssued` event and the outbox relay executes it, so commands run reliably even if the process dies mid-way.

Consistency rule: everything inside an aggregate is strongly consistent; everything outside, including everything a saga coordinates, is **eventually consistent**. If business rules require two things to be strongly consistent, they belong in the same aggregate. A saga is not a patch for wrong aggregate boundaries.

### Process manager: a business process with decisions

A saga maps events to commands, linearly. A **process manager** is a central unit that holds the state of a multi-step process and decides the next step based on business logic. Rule of thumb: **if the saga has if/else branches, it is a process manager.**

Other differences: a process manager is not bound to a single triggering event; it is a coherent process in its own right and must be **instantiated explicitly** (there is no single entity whose event starts "book a business trip": route proposed, employee approves or manager approves an alternative, flight booked, pre-approved hotel booked, flight cancelled if no hotel). Process managers have an explicit id and persistent state and are usually implemented as state-based or event-sourced aggregates that subscribe to the workflow's events and emit `CommandIssued` events for the outbox relay.

## Review checklist

- Infrastructure code (ORM, HTTP clients, bus clients) found inside domain objects or the application layer: move it behind a port into an adapter.
- Business rules in controllers or stored procedures: move them into the business logic layer; add a service layer if the presentation is orchestrating transactions.
- Domain events published before commit, or after commit without an outbox: introduce the outbox and make consumers idempotent.
- Raw domain events exposed to other contexts: add a message proxy that translates to a published language and distinguish private from public events.
- Read model written to directly, or a command returning data read from a projection: fix the segregation.
- Only asynchronous projections: add the synchronous catch-up projection so projections can be rebuilt.
- Two aggregates updated in one transaction "because the saga was too hard": revisit the aggregate boundary rather than widening the transaction.
- A saga full of conditionals: rename and restructure it as a process manager with explicit state and instantiation.
- One architecture enforced across every module of a context: slice vertically and match the pattern to each subdomain.
