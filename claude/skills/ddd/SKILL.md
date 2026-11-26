---
name: ddd
description: >-
  Domain-driven design, from Vlad Khononov's Learning Domain-Driven Design. Use to analyse a business domain (core, supporting and generic subdomains, build versus buy, ubiquitous language, bounded contexts, context maps and integration patterns); to implement or review business logic (transaction script, active record, domain model, event sourcing, value objects, aggregates, domain events, repositories); to organise a service (layered, ports and adapters, CQRS, outbox, sagas, process managers, anticorruption layers); to draw microservice boundaries, design event-driven systems or a data mesh; to plan or run an EventStorming workshop; or to choose a pattern and evolve a legacy system. Also trigger on "is this a core domain?", "should this be its own service?", "should this be an aggregate?", "big ball of mud", "saga versus process manager" or "how do I sell DDD".
---

# Domain-driven design

Strategic design decides what to build and where the boundaries go; tactical design decides how the business logic
inside a boundary is written; architecture wires that logic to everything else. Work in that order: the subdomain
type decides the business logic pattern, and the business logic pattern decides the architecture.

## Which reference to load

| Task | Load |
|---|---|
| Subdomains, build versus buy, ubiquitous language, bounded contexts, context maps, team ownership | `references/strategic-design.md` |
| Business logic patterns, value objects, entities, aggregates, domain events, event sourcing | `references/tactical-design.md` |
| Layers, ports and adapters, CQRS, outbox, sagas, process managers, anticorruption layers | `references/architecture.md` |
| Microservice boundaries, event-driven architecture, data mesh | `references/distributed-systems.md` |
| Planning, facilitating or simulating an EventStorming workshop | `references/eventstorming.md` |
| Which pattern to use, sizing contexts, refactoring between patterns, introducing DDD to a legacy system | `references/design-heuristics.md` |

When a question spans several, start with the earliest in the table: a tactical answer built on the wrong strategic
boundary is wrong however well it is implemented.
