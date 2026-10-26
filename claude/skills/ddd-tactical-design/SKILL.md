---
name: ddd-tactical-design
description: Tactical domain-driven design and business logic implementation patterns, from Vlad Khononov's Learning Domain-Driven Design (Part II, chapters 5 to 7). Use when implementing or reviewing business logic in any language, when choosing between transaction script, active record, domain model and event-sourced domain model, or when designing value objects, entities, aggregates, aggregate boundaries, domain events, domain services, repositories, optimistic concurrency, idempotency or event stores and projections. Also trigger on questions like "should this be an aggregate?", "is this aggregate too big?", "why is my counter double-incrementing?", "where does this rule live?", "anaemic model", "primitive obsession", or "should we use event sourcing?". Pairs with ddd-strategic-design (which subdomain type the logic belongs to decides the pattern) and ddd-architecture (how the logic is wired into layers, CQRS and messaging).
---

# DDD tactical design

Business logic is the reason the software exists. Tactical design is about choosing the right implementation pattern for the complexity at hand and then applying it correctly. Four patterns, in increasing order of power and cost:

| Pattern | Business logic it suits | Data structure | Subdomain type | Source of truth |
|---|---|---|---|---|
| Transaction script | Simple, procedural, ETL-like | Flat records, direct DB access | Supporting, integration glue for generic, adapters in an ACL | State |
| Active record | Simple (CRUD plus input validation) | Complex object trees mapped to tables | Supporting, generic integration, model translation | State |
| Domain model | Complex rules, state transitions, invariants | Aggregates, value objects, domain services | Core | State (plus selected domain events) |
| Event-sourced domain model | Complex, plus need for history, audit, deep analysis | Same building blocks, state projected from events | Core | Events |

Never use a transaction script or active record for a core subdomain; it will duplicate logic across procedures until it becomes a big ball of mud. Never use a domain model or event sourcing for CRUD; the accidental complexity costs more than it saves. Match the tool to the problem, and be pragmatic where the business can tolerate it (one duplicated IoT event in a million may be fine; one duplicated bank transfer is not).

## Transaction script

Organise logic as procedures, one per public operation. Each procedure may talk to storage through a thin abstraction or directly. The one non-negotiable requirement is **transactional behaviour**: every operation either fully succeeds or fully fails, never leaving an invalid state. Use rollbacks or compensating actions.

This is the easiest pattern to get wrong, and most "simple" production data corruption traces back to one of three mistakes:

1. **No transaction around multiple writes.** Updating one table and then inserting into another without a wrapping transaction. A crash in between leaves the system inconsistent. Wrap both in one transaction.
2. **Implicit distributed transaction across storages.** Writing to the database and then publishing to a message bus. If publishing fails after the commit, consumers never hear about the change. There is no simple fix; use the outbox pattern or CQRS projections (see `ddd-architecture`).
3. **The caller is part of the transaction.** Even `UPDATE users SET visits = visits + 1` is distributed: the method communicates its result back to the caller. If the response is lost (network outage, process crash), the caller retries and the counter goes up twice. Fix by making the operation **idempotent** (caller passes the new absolute value) or with **optimistic concurrency** (caller passes the value it read; the update only applies if the stored value still matches).

Review checklist for any transaction script:

- Is every multi-write wrapped in one transaction, with rollback on failure?
- Does it write to more than one storage mechanism or publish messages? If so, how is the second write made reliable?
- What happens if the caller retries? Is the operation idempotent or concurrency-guarded?

Every other pattern in this skill is built on a transaction script. The application layer that loads an aggregate, executes a command and saves it is itself a transaction script, so the same checklist applies there.

## Active record

Same simple business logic as a transaction script, but the data is a non-trivial object tree (one-to-many, many-to-many) and hand-mapping it in every script would duplicate code. The data structures become **active records**: objects that know how to create, read, update and delete themselves through an ORM or data access framework. The transaction script then manipulates active records instead of raw rows, still inside an atomic transaction.

Active records may hold light logic such as field validation, but their defining trait is that **data and behaviour are separated**: public getters and setters let outside procedures change their state. This is the "anaemic domain model" that gets labelled an anti-pattern. It is only an anti-pattern when applied to complex logic. For CRUD it is the correct, cheapest tool. Do not confuse the pattern with any specific framework that carries the same name.

## Domain model

For complex business logic: entangled rules, invariants that must hold at all times, non-trivial lifecycles. The canonical example is a support ticket with priorities, SLAs, escalation that shortens the SLA, automatic reassignment when an escalated ticket goes unread, automatic closure after seven days of customer silence, rules on who may close an escalated ticket and a reopen window. Implementing that with active records invites duplicated, drifting rules.

Two design rules govern the whole pattern:

- **Plain objects only.** The model is already complex; it must not carry infrastructure. No database calls, no framework base classes, no messaging inside domain objects.
- **The code speaks the ubiquitous language.** Names of aggregates, fields, commands and events come from the bounded context's language, not from technical convenience.

### Value objects

An object identified by the composition of its values. Two colours with the same red, green and blue are the same colour; an id field would be redundant and would let two rows represent the same colour with different ids.

- **Immutable.** Any operation that "changes" a value returns a new instance (`red.MixWith(green)` returns yellow and leaves red untouched). This makes them side-effect free and thread safe.
- **Value-based equality.** Override equality and hashing (or use the language's record or data class features).
- **Behaviour, not just data.** Parsing, validation, conversion and arithmetic live inside: `Height.FromMetric(180).ToImperial()`, `PhoneNumber.Parse(s).Country`, `Money.Add`. Validation happens once, in the constructor or factory, so an invalid value cannot exist.
- **Use them whenever you can.** Replace **primitive obsession** (strings, ints and dictionaries standing in for domain concepts by convention) with named types. Candidates: ids, names, email addresses, phone numbers, addresses, statuses, passwords, quantities with units, date ranges and, above all, **money**. Representing money as a float or a bare decimal scatters rounding and precision bugs through the codebase.
- Rule of thumb: value objects describe the properties of entities. Strings in most standard libraries are themselves value objects, which is why the pattern feels natural once adopted.

### Entities

An entity needs an explicit, unique, immutable identity because its other values can legitimately coincide or change over time (two people with the same name are still two people). The id is itself a value object (`PersonId`), and can be a GUID, a number or a domain identifier. Entities are mutable. They are **never implemented on their own**, only as part of an aggregate.

### Aggregates

An aggregate is an entity that is also a **consistency enforcement boundary**, a **transaction boundary** and a **hierarchy of entities and value objects** that must change together.

**Consistency.** Only the aggregate's own logic may change its state. Outsiders can read it but mutate it only by executing **commands** through the aggregate's public interface, either as plain methods (`ticket.AddMessage(from, body)`) or, preferably, as explicit command objects dispatched polymorphically (`ticket.Execute(new AddMessage(...))`). The command handler validates input and enforces every relevant rule and invariant, so all logic about the aggregate lives in one place and cannot be bypassed from the application layer.

**Transaction boundary.** All changes to one aggregate instance commit atomically, and **only one aggregate instance is modified per database transaction**. Needing to update two aggregates in one transaction is a signal that the aggregate boundaries are wrong, not a reason to widen the transaction. Domain services do not provide a loophole.

**Concurrency.** Hold a version field and use optimistic concurrency on save:

```sql
UPDATE tickets
SET ticket_status = @new_status, agg_version = agg_version + 1
WHERE ticket_id = @id AND agg_version = @expected_version;
```

If zero rows update, the caller's view was stale and it must retry. Whatever database you choose must support this; document databases map naturally onto aggregates.

**Application layer shape.** The orchestration is deliberately boring, and is itself a transaction script:

```
load aggregate by id
build command
aggregate.Execute(command)
save aggregate (with expected version)
return result, or a concurrency error so the caller can retry
```

**Boundary design.** Include in the aggregate only the data that the aggregate's rules need to be **strongly consistent**. Everything that may be eventually consistent lives in another aggregate and is **referenced by id**, never by object. Test: "If this piece of data were stale by a few seconds, could the aggregate's logic produce an invalid state?" If yes, it belongs inside. In the ticket example, messages belong inside because the reassignment rule reads unread counts; the customer, products and agent are outside and referenced by id. Keep aggregates **as small as the invariants allow**: large aggregates mean contention, slow loads and concurrency failures.

**Aggregate root.** One entity in the hierarchy is the public interface. Internal entities are modified only through the root (`ticket.Execute(new AcknowledgeMessage(messageId))` marks a message read; nobody touches `Message` directly).

**Domain events.** Messages describing something significant that has already happened, named in the **past tense** in the ubiquitous language (`TicketEscalated`, `MessageReceived`) and carrying the data needed to act on them (ids, reason, time). An aggregate appends events to its internal collection as part of handling a command; they are part of its public interface. Other aggregates, processes or external systems subscribe. Reliable publishing is an infrastructure concern solved by the outbox pattern (see `ddd-architecture`).

### Domain services

A **stateless** object hosting logic that belongs to no single aggregate or value object, typically a calculation or analysis that reads several aggregates (for example, an agent's response deadline computed from the ticket's priority and escalation, the department's SLA policy and the agent's shift schedule). Domain services coordinate reads across aggregates; they still write only one aggregate per transaction. The word "service" here has nothing to do with microservices or SOA.

### Why this reduces complexity

Complexity is the difficulty of controlling and predicting a system's behaviour, measured by its degrees of freedom: the number of independent values needed to describe its state. A class with five public settable fields has five degrees of freedom; a class whose three derived fields are computed from two inputs has two. Invariants reduce degrees of freedom. Value objects and aggregates encapsulate invariants, so they make a system simpler even though they contain more code.

## Event-sourced domain model

Same building blocks as the domain model, but the **events are the source of truth**. Instead of storing an aggregate's current state, you store every domain event in its lifecycle and project state from them.

A state table tells you that a lead is `CONVERTED`; it cannot tell you how many calls it took, whether the phone number changed, or whether follow-ups are worth doing. The event stream can, and you can project it into as many representations as you need, now or later: a current-state model, a search model holding every historical name and phone number, an analysis model counting follow-ups. The ledger in accounting is the original event store.

### Mechanics

- **Event store**: append-only, with at minimum `Fetch(instanceId)` and `Append(instanceId, newEvents, expectedVersion)`. The expected version provides optimistic concurrency; a stale version raises a concurrency exception. No updates, no deletes (data migration is the rare exception).
- **Every operation** follows: load the aggregate's events, reconstitute state by applying them in order (a state projector class with one `Apply` per event type), execute the command (which produces new events rather than setting fields), commit the new events with the original version.
- **Version** is the count of applied events. Applying only the first N events reconstitutes the state at version N: time travel.
- The command handler reads `_state.IsEscalated` and, when the rule passes, appends `TicketEscalated` rather than setting a flag. The flag is set in the projector's `Apply(TicketEscalated)`.

### When it pays off

- Time travel for retroactive debugging and analysing past decisions.
- Deep insight into core subdomains, with new projections added over existing events at any time.
- A strongly consistent **audit log**, mandatory in some regulated domains and ideal for anything that moves money.
- Smarter optimistic concurrency: on conflict, inspect the concurrently appended events and decide in domain terms whether they actually collide.

### Costs

- Learning curve for the team.
- Evolving event schemas is hard (immutable events; see Greg Young's "Versioning in an Event Sourced System").
- More moving parts: CQRS and projections become mandatory (see `ddd-architecture`).

### Answers to the usual objections

- **Performance of replay.** Benchmark against the expected lifespan of an aggregate. Most aggregates never exceed about 100 events; replay only hurts past roughly 10,000. If it does, first re-check the aggregate boundary, then add **snapshots** (cache a projection, replay only events after the snapshot version).
- **Volume.** Shard the event store by aggregate id; all events of one instance live in one shard.
- **Deleting data (GDPR).** Use the **forgettable payload** pattern: encrypt sensitive fields in the events and keep the key in a separate store keyed by aggregate id; delete the key to forget.
- **Why not a log file, a log table, or a history-table trigger?** A log file is a second storage and goes inconsistent with the database. A log table in the same transaction stays consistent but relies on every future engineer remembering to write it, and its schema degrades. A trigger records what changed but never why, which cripples future projections.

## Choosing and reviewing

When asked which pattern to use, answer in this order:

1. Which subdomain type does this logic belong to? (See `ddd-strategic-design`.)
2. Is the logic CRUD-like (transaction script or active record) or governed by rules and invariants (domain model)?
3. Does the business need history, audit or analysis of the lifecycle, or is money involved? (Consider event sourcing.)
4. Can the team carry the chosen pattern's complexity?

When reviewing a domain model, look for:

- Setters or public mutable fields on aggregates (logic has leaked to the application layer).
- Primitive obsession where a value object would validate once and carry behaviour.
- Aggregates holding references to other aggregates instead of their ids.
- Transactions that save more than one aggregate.
- Missing version checks on save.
- Domain events named in the present or imperative tense, or missing the data a subscriber needs.
- Infrastructure code (ORM annotations, HTTP, message bus calls) inside domain objects.
- A domain service used to update several aggregates in one go.
