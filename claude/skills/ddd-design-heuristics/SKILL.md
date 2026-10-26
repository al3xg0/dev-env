---
name: ddd-design-heuristics
description: Decision heuristics for applying domain-driven design and for evolving or modernising an existing system, from Vlad Khononov's Learning Domain-Driven Design (chapters 10, 11 and 13). Use when the user asks "which pattern should I use here?", wants a tactical design decision tree (business logic pattern, architecture, testing strategy) for a subdomain, is sizing bounded contexts or deciding whether to split one, notices a subdomain changing type (core becoming generic, supporting becoming core), is refactoring transaction scripts to active records, active records to aggregates, or a domain model to event sourcing, is migrating legacy state into an event store, is planning to introduce DDD to a brownfield or legacy codebase (strangler pattern, façade, modular monolith first), or needs to justify DDD decisions to a team or management without appealing to authority. Also trigger on "big ball of mud", "it is painful to add features here", "should this be a microservice", "our contexts are too chatty", or "how do I sell DDD".
---

# DDD design heuristics, evolution and real-world adoption

"It depends" is the right answer to most design questions. This skill lists what it depends on. These are heuristics, rules of thumb that ignore noise and follow the strongest signals. They are not laws; keep thinking critically, and if a team with deep event sourcing experience uses it everywhere and is happy, that is their valid context. The default bias here is **use the simplest tool, escalate only when necessary**.

## Part 1: Heuristics for new design

### Bounded context size

Size is one of the least useful heuristics for a service boundary. Make the context's size a function of the model it holds, not the other way round. Changes that cut across several contexts are expensive and signal wrong boundaries, and refactoring physical boundaries is costly, so wrong boundaries tend to be left alone and become debt.

Volatility and uncertainty are properties of core subdomains, especially early. Therefore:

- **Start with wider boundaries** for contexts holding core subdomains, including the other subdomains the core interacts with most (other core, supporting or generic). It is far cheaper to be wrong about a logical boundary than a physical one.
- **Decompose later** as domain knowledge grows and the logic stabilises.
- Generic and supporting subdomains are more formulaic and less volatile; narrow boundaries are safer there.

### Business logic implementation pattern

Ask in order, stop at the first yes:

1. Does the subdomain track money or monetary transactions, need a legally consistent audit log, or require deep analysis of its behaviour? **Event-sourced domain model.**
2. Is the business logic complex (complicated rules, invariants, algorithms, a ubiquitous language that describes processes rather than CRUD)? **Domain model.**
3. Are the data structures complex (object trees, many-to-many)? **Active record.**
4. Otherwise: **transaction script.**

"Complex" versus "simple": simple logic is mostly input validation; complex logic has rules, invariants and algorithms. Listen to the ubiquitous language: does it describe CRUD operations, or processes and rules?

Use the answer to **validate the subdomain classification**. If you believed it was core but transaction script fits, or you believed it was supporting but it needs a domain model, revisit the business analysis. A core subdomain's advantage is not always technical.

### Architectural pattern

Follows from the business logic pattern:

| Business logic | Architecture |
|---|---|
| Event-sourced domain model | Ports and adapters plus CQRS (mandatory, or you can only fetch by id) |
| Domain model | Ports and adapters (layered makes persistence-ignorant aggregates painful) |
| Active record | Layered with an application (service) layer for the logic controlling the records |
| Transaction script | Minimal three-layer layered architecture |

Exception: CQRS is worth adding to any of these when the subdomain's data must be represented in several persistent models.

### Testing strategy

| Business logic | Strategy | Reason |
|---|---|---|
| Domain model, event-sourced domain model | **Testing pyramid** (mostly unit) | Aggregates and value objects are ideal units |
| Active record | **Testing diamond** (mostly integration) | Logic is split across service and business logic layers; test their integration |
| Transaction script | **Reversed pyramid** (mostly end-to-end) | Logic is simple and layers are few; verify whole flows |

### The tactical decision tree in one pass

```
subdomain type?
  core      -> complex logic
                 needs money/audit/deep analysis?  yes -> event-sourced DM, ports&adapters + CQRS, pyramid
                                                    no  -> domain model, ports&adapters, pyramid
  supporting / generic integration -> simple logic
                 complex data structures?          yes -> active record, layered + service layer, diamond
                                                    no  -> transaction script, layered, reversed pyramid
```

When asked to design a component, walk this tree aloud, state the subdomain type and the three resulting choices, and name the assumption that would flip the answer.

## Part 2: Evolving design decisions

Four vectors of change invalidate past decisions: the business domain, the organisation, domain knowledge, and growth.

### Subdomain type changes

| Change | Trigger | Example |
|---|---|---|
| Core to generic | A vendor commoditises what you built | A routing-as-a-service company undercuts your in-house delivery optimiser |
| Generic to core | You decide to out-innovate the off-the-shelf product | Replacing a bought inventory system with in-house demand prediction; Amazon turning infrastructure into AWS |
| Supporting to generic | Open source or a product now covers your simple in-house tool with more features | Contract management replaced by an open source solution with OCR and search |
| Supporting to core | The simple logic grows complex **and** that complexity raises profit | Watch for rising complexity: if it does not affect profit it is accidental complexity, if it does the subdomain is becoming core |
| Core to supporting | The complexity stops paying for itself | Cut it down to the minimum needed by other subdomains |
| Generic to supporting | Integrating the generic product costs more than it gives | Reverting to the simple in-house tool |

Consequences of a type change:

- **Strategic.** Core subdomains need ACLs to protect their model and OHS published languages to protect consumers. Separate ways is no longer acceptable for something that became core; the teams must integrate, usually customer-supplier with one owning team. Supporting work can be outsourced or used as training wheels; work that became core moves in-house, close to the domain experts.
- **Tactical.** The main symptom is that the existing design can no longer support the business: adding features to a transaction script or active record becomes painful as rules and invariants pile up. Treat that pain as a signal to reassess, not as something to fear. Migrating between patterns is routine if the original choice was made consciously.

### Migrating between business logic patterns

**Transaction script to active record.** When data handling in scripts gets awkward, find the complicated data structures and wrap them in active records; stop touching the database directly.

**Active record to domain model.** When logic manipulating active records duplicates and drifts:

1. Identify **value objects**: which data can be immutable? Pull their related logic in with them.
2. Make all active record setters **private**. Compilation fails everywhere external code mutates state, which is a map of where the logic lives. Move each piece inside the object as a method (`player.ApplyBonus(percentage)` instead of `player.Points *= ...` in a script).
3. Find the hierarchies that must be checked under strong consistency; these are the aggregates. Choose the **smallest** transaction boundaries, decompose along them, reference other aggregates by id.
4. For each aggregate pick the **root**; make internal objects' methods private to the aggregate.

**Domain model to event-sourced domain model.** With sound aggregate boundaries in place, replace direct state mutation with domain events modelling the lifecycle. The hard part is existing data with no history. Two options:

- **Generate past transitions**: synthesise a best-effort event stream per instance that projects to the current state (initialised, contacted, order submitted, payment confirmed). Testable by projecting and comparing, but the history is incomplete and the stream can never claim to be a full record.
- **Model a migration event**: a single `MigratedFromLegacy` event carrying the current state initialises each stream. Honest about missing history, but the legacy trace stays in the event store and every projection must handle it forever.

### Organisational changes

One team per bounded context means new teams can force a wide context to split. Moving a team to a distant location weakens collaboration, so:

- **Partnership to customer-supplier** when ad hoc coordination stops being sustainable.
- **Customer-supplier to separate ways** when integration keeps failing because of distance or politics and duplication becomes cheaper. Only acceptable for non-core functionality.

### Domain knowledge changes

Complexity is often implicit; initial simplicity is deceptive and edge cases, invariants and rules keep appearing, sometimes forcing the model, aggregates and even context boundaries to be rebuilt. Design context boundaries according to the **level of domain knowledge**: unclear and fast-changing means broad; stable and understood means it is safe to narrow, including into microservices. Knowledge is also lost: documentation goes stale, people leave, features are added ad hoc until the codebase is "legacy". Recover it with EventStorming (see `ddd-eventstorming`).

### Growth

Growth is healthy, but unregulated growth without re-evaluating design decisions produces a big ball of mud. The principle: eliminate **accidental complexity** (caused by outdated design decisions) and manage **essential complexity** (inherent to the domain) with DDD tools. Revisit every boundary:

- **Subdomains.** As they grow, boundaries blur. Re-apply the coherent use cases heuristic to find finer-grained subdomains of different types hiding inside, especially inside core ones.
- **Bounded contexts.** Contexts lose focus and accumulate unrelated logic. Extract laser-focused contexts. If contexts become **chatty** (unable to finish an operation without calling another), the model is wrong; redesign for autonomy.
- **Aggregates.** New features get bolted onto existing aggregates for convenience. Any data not required to be strongly consistent by the aggregate's logic is accidental complexity; extract it into its own aggregate. That extraction often reveals a hidden model that belongs in another context.

## Part 3: DDD in the real world (brownfield, legacy, imperfect teams)

DDD is not only for greenfield projects with expert teams, and it is not all-or-nothing. Brownfield systems that have proven their business viability are the ones that benefit most. The non-negotiable core is: analyse the business domain, look for effective models for specific problems, and let the business domain drive design decisions. Everything else is optional tooling.

### Step 1: Strategic analysis

Understand the business: what is the domain, who are the customers, what value is provided, who are the competitors. Then zoom in using the org chart to find subdomains, with these brownfield-specific signals:

- **Core**: the "secret sauce" (patents, in-house algorithms, non-technical advantages like hiring or design). Also, unfortunately, **the worst-designed components everyone hates but the business refuses to rewrite** because the risk is too high and nothing off the shelf can replace them.
- **Generic**: off-the-shelf products, subscriptions, open source integrations.
- **Supporting**: what remains; cannot be bought, gives no edge, and rough code there annoys fewer people because it rarely changes.

You do not need to find every subdomain. Map the overall structure and focus on what is relevant to the systems you work on.

Then explore the current design: identify high-level components by **decoupled lifecycles** (what can be evolved, tested and deployed independently, even inside a monorepo or monolith). For each, record which subdomains it contains and which business logic and architectural patterns it uses, and ask whether the solution fits the problem's complexity in either direction. Draw a context map treating these components as contexts and look for:

- Several teams on one component.
- Duplicate implementations of a core subdomain.
- A core subdomain implemented by an outsourcer.
- Friction from frequently failing integrations.
- Awkward models leaking from external or legacy systems.

Where knowledge has been lost, especially in core subdomains, run EventStorming to recover it and seed the ubiquitous language.

### Step 2: Modernisation strategy

Big rewrites rarely succeed and rarely get funded. **Think big, start small**, and accept that not all of a large system will be well designed; choose where to invest.

1. **Logical boundaries first.** Reorganise modules, namespaces and packages so they follow subdomain boundaries rather than technical layers. Moving types is low-risk refactoring (watch reflection and dynamic loading by full type name). Apply the same boundaries to logic living elsewhere: rename or re-schema stored procedures, group serverless functions.
2. **Physical boundaries where they pay.** Turn a logical boundary into a bounded context when several teams share a codebase (decouple their lifecycles) or when conflicting models live in one component (separate them). Do not decompose to the smallest possible contexts prematurely.
3. **Fix integration patterns.** Partnerships that no longer work become customer-supplier. ACLs protect new code from legacy models and from volatile upstream APIs. Make a component whose internal changes ripple outwards an OHS with a published language. Let teams go separate ways on contested functionality only if it is not core.
4. **Tactical modernisation.** Target the most painful mismatches first: core subdomains implemented as transaction scripts or active records, which change the most and hurt the most.
5. **Cultivate the ubiquitous language** throughout, using EventStorming to build it with domain experts and to explore undocumented legacy code.

Two mechanisms for replacing legacy implementations:

- **Strangler pattern.** Create a new bounded context, implement new requirements there, migrate legacy functionality piece by piece, and freeze the legacy context except for hotfixes until it dies. Usually paired with a **façade** that routes each request to legacy or modernised code and is deleted at the end. The one-database-per-context rule may be bent so both share a database and avoid distributed transactions, on the condition that the legacy side is retired sooner rather than later.
- **Refactoring in place.** Small steps. Never jump from transaction script or active record straight to event sourcing: first design **state-based aggregates** and get the boundaries right, because a wrong transactional boundary is far cheaper to fix in a state-based aggregate than in an event-sourced one. Introduce domain model elements gradually: value objects first (they reduce complexity even without a full domain model), then gather related logic, analyse transactional requirements (where is strong consistency needed on eventually consistent data, and where is strong consistency enforced unnecessarily), and only then draw aggregate boundaries. Protect the new code with an ACL and legacy consumers with an OHS.

### Step 3: Selling DDD, or not selling it

Management support helps but is not required. Use DDD as part of your professional toolbox rather than an organisational initiative:

- **Ubiquitous language**: listen to stakeholders, steer terms away from jargon, ask about inconsistent names (same thing with several names, or several concepts under one name, which points at hidden contexts), talk to domain experts informally, and use the language in code and every artefact. Be patient.
- **Bounded contexts**: argue from the principles, not the pattern name. Problem-focused models beat all-in-one models because all-in-one serves nothing well; conflicting models in one context raise cognitive load; several teams on one codebase create friction.
- **Tactical patterns**: never say "because the DDD book says so". Explain the why:
  - Explicit transaction boundaries protect data consistency.
  - One aggregate per transaction ensures the consistency boundaries are right.
  - No external mutation of aggregate state keeps all logic co-located and un-duplicated.
  - No logic in stored procedures because duplicated logic in distant components drifts and corrupts data.
  - Small aggregates because wide transactional scope raises complexity and hurts performance.
  - Not a log file instead of event sourcing because a log file has no long-term consistency guarantee.
- **Event sourcing**: let the domain experts sell it. Show them state-based and event-based models side by side; the insight into time usually makes them advocates.

## Output when asked for a modernisation assessment

```
Business domain and subdomains (with type and confidence)
Current high-level components, their lifecycles and owning teams
Per component: subdomains inside, business logic pattern, architecture, fit verdict
Context map of the current state with integration patterns and observed smells
Lost-knowledge areas needing EventStorming
Modernisation plan: logical boundaries -> physical extractions -> integration fixes -> tactical refactors, each with the pain it removes and the risk it carries
```

## Lessons from the book's case study (Appendix A)

A self-funded marketing start-up applied DDD from day one and made most of the mistakes available. The arc is worth remembering because it is the usual arc.

1. **Marketing (first context): "aggregates everywhere".** Every noun became an "aggregate" with no behaviour and no transactional meaning, all logic in a giant service layer, one monolith. A textbook anaemic model, yet a business success, because the team had built a strong ubiquitous language with the domain experts and shipped fast. Language compensated for architecture.
2. **CRM: the Lead cut in two.** Prefixes like `CRMLead` and `MarketingLead` appeared in code but never in conversation, which is the signal for separate bounded contexts, so the monolith was split along the language. Then proper aggregates proved slow to get right, deadlines slipped, and management handed part of the business logic to the DBA team as stored procedures. That created an implicit second bounded context slicing through the most complex entity, two vocabularies, duplicated rules that drifted, and years of silent data corruption. The Lead aggregate had to be rewritten later. Never dissect an aggregate across teams or codebases.
3. **Event crunchers: supporting became core, unnoticed.** Logic shared by marketing and CRM was extracted as a supporting context built with transaction scripts and no ubiquitous language. Flags requested by analysts grew into real rules and invariants; the scripts became a big ball of mud; a year later it was rewritten as an event-sourced domain model. Not investing in the language delayed noticing the change.
4. **Bonuses: supporting became core, noticed early.** Commission calculation started as active records behind a service layer. Analysts then wanted tiered percentages, goals and unlocks. Because a ubiquitous language existed, the moment the language outgrew what active records could express was obvious, and the switch to an event-sourced model happened before the mud set. Money was involved, so every small bug had large consequences.
5. **Marketing hub: core by business label, supporting by logic.** Declared a new profit line, so it got event sourcing, CQRS and microservices drawn around aggregates. The services grew chatty until it was a distributed monolith, and the business logic turned out to be simple enough for active records. The real competitive edge was commercial relationships, not software. Pure accidental complexity.

Distilled rules:

- **Ubiquitous language is the core subdomain of DDD.** It predicted success in every one of the five contexts and is not optional for any subdomain type. Fix the language early; a wrong language is harder to repair than a wrong implementation, and conflicting terms lingered for years.
- **Reverse the relationship to validate subdomain types.** Pick the business logic pattern that honestly fits the requirements, map it back to the subdomain type it implies, and check that against the business's view. If the business calls it core and you can hack it in a day, either look for finer-grained subdomains or question the business case. If the business calls it supporting but it needs a domain model, either the requirements carry accidental business complexity and should be simplified, or the business has not yet realised it has found an edge.
- **Never ignore pain.** Pain adding features means the model or the pattern no longer fits; the subdomain has probably changed type. Go back to the domain experts, re-evaluate, and refactor without fear.
- **Start wide, extract later.** Linguistic, subdomain-based and entity-based boundaries all worked in some places; "suicidal" boundaries through an aggregate never did. Extracting a service from a bigger one is far safer than starting too small, and the less you know about the domain, the wider the first boundaries should be.
- From "aggregates everywhere" to "ubiquitous language everywhere" is the whole journey.
