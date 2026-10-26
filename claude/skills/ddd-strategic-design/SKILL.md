---
name: ddd-strategic-design
description: Strategic domain-driven design, from Vlad Khononov's Learning Domain-Driven Design (Part I). Use when the user wants to analyse a business domain, classify subdomains as core, generic or supporting, decide what to build in-house versus buy or outsource, cultivate a ubiquitous language or glossary, draw bounded context boundaries, decide team ownership of services, choose how two services or teams should integrate (partnership, shared kernel, conformist, anticorruption layer, open-host service, separate ways), or draw a context map. Also trigger when the user asks "is this a core domain?", "should this be its own service?", "how should these two systems talk?", or when another skill (architect, explorer, ddd-tactical-design) needs the strategic picture before choosing an implementation pattern. Not for implementing aggregates, entities or events (that is ddd-tactical-design) or for running a workshop (ddd-eventstorming).
---

# DDD strategic design

Strategic design answers "what are we building and why" before any code is written. It has four tools, applied in order: analyse the business into subdomains, learn the domain through a ubiquitous language, divide the models into bounded contexts, then define how the contexts integrate on a context map. Use the output to drive every later design decision: which parts deserve the best engineers and the richest patterns, which should be bought, and which can be hacked together.

The underlying principle: a model is not a copy of the real world. It is an abstraction with a purpose, like a subway map or a piece of cardboard cut to a fridge's footprint. Every model needs a boundary and a problem it solves. Overbuilding a model is as much a failure as underbuilding it.

## 1. Analyse the business domain into subdomains

A **business domain** is the company's main area of activity (courier delivery, coffee, ticket sales). A **subdomain** is a fine-grained area of business activity needed to operate in that domain. All subdomains together form the business domain; no single one makes a company.

### The three subdomain types

| Type | Competitive advantage | Business logic complexity | Volatility | How to implement | Nature of the problem |
|---|---|---|---|---|---|
| **Core** | Yes. What the company does differently from competitors. | High. Complex algorithms, rules and invariants. | High. Never "done"; continuously evolved. | In-house, best engineers, most advanced patterns. Never outsource. | Interesting |
| **Generic** | No. Everyone solves it the same way. | High, but already solved elsewhere. | Low (patches, new vendors). | Buy off-the-shelf or adopt open source. | Solved |
| **Supporting** | No. Needed, but no one would copy it. | Low. CRUD, data entry, ETL, input validation. | Low. | In-house or outsourced; rapid application framework is fine; good training ground for junior engineers. | Obvious |

Core subdomains are not necessarily technical. For a jewellery maker the design is core and the web shop is generic. For a manual fraud detection firm the analysts' work is core and the document viewer they use is supporting. Identify non-software core subdomains, acknowledge them, and focus on the ones your system actually implements.

### Classification heuristics

Ask these in order:

1. **Could it be a side business? Would someone pay for it on its own?** Yes means core.
2. **Would it be simpler and cheaper to hack our own than integrate an external product?** Yes means supporting rather than generic. The supporting/generic border is a grey area decided by the cost of integration versus the cost of building.
3. **Does the business logic look like CRUD screens and ETL, or like algorithms and processes governed by complex rules and invariants?** CRUD means supporting; rules and invariants mean core.
4. **If it could be solved on the first attempt and never changed, is it really an advantage?** Core subdomains are emergent and volatile by nature. A stable, simple "core" is probably supporting.

### Finding subdomain boundaries

- Start from departments and organisational units (warehouse, customer service, picking, shipping). These are coarse-grained.
- **Distil** each coarse area into finer-grained activities. A "generic" customer service department may hide a generic help desk, a supporting shift scheduler and a core incident routing algorithm. Core subdomains must be distilled as far as possible so everything generic or supporting is stripped away and effort lands on the genuinely differentiating part.
- **Stop distilling** when further drilling reveals nothing that changes a design decision, for instance when every sub-part has the same type as its parent. Supporting and generic subdomains rarely need deep distillation.
- The most precise boundary is a **set of coherent use cases**: same actor, same business entities, closely related data. Use this as the stopping rule and as the unit you refuse to split across services later.
- Subdomains are **discovered**, not designed. They come from business strategy. If you ask the CEO for a list of subdomains you will get a blank stare, so do the analysis yourself.

### Output format for a domain analysis

Produce, for the system in question:

```
Business domain: <one line>
Core subdomains: <list, each with the differentiator and why it is hard to copy>
Generic subdomains: <list, each with the candidate off-the-shelf solution>
Supporting subdomains: <list, each with the reason it is simple>
Design decisions:
  - <what gets in-house, advanced patterns, senior engineers>
  - <what gets bought or adopted>
  - <what can be outsourced or built with a rapid framework>
Non-software core activities acknowledged and excluded: <list>
```

Remember that some requirements are implicit. A privacy-conscious consumer app implies data anonymisation; a product that takes payments implies accounting, billing and clearing (all generic); a mobile-first product implies the app's user experience may itself be core.

## 2. Discover domain knowledge with a ubiquitous language

Software development is a learning process; working code is a side effect. The traditional chain (domain expert to analyst to requirements to design document to code) is a game of Telephone where domain knowledge is lost at every translation. DDD replaces the translations with one shared language used by domain experts, engineers, product, UX and testers alike, in conversation, documentation, tests, diagrams and source code.

### Rules of a ubiquitous language

- **It is the language of the business.** Business terms only, no technical jargon. "A campaign can be published only if at least one placement is active" belongs; "a campaign is published if it has a row in the active-placements table" does not.
- **One term, one meaning.** If "policy" means both regulatory rule and insurance contract, model two explicit terms. Ambiguity is tolerable between humans and intolerable in code.
- **No synonyms.** "User", "visitor", "account" and "administrator" usually denote different concepts with different behaviours. Make each explicit in its own context.
- **It captures behaviour, not just nouns.** Rules, assumptions, invariants, cause and effect. Glossaries are good for nouns; use cases and Gherkin scenarios capture behaviour.
- **It is continuous.** Validate and evolve the language as understanding deepens; when a breakthrough happens the language changes and so does the code.
- **Usage beats documentation.** Wikis, glossaries and static analysis support the language but never replace its daily use.

### Working with domain experts

- Domain experts are the people who have the business problem: those writing the requirements or the end users. Not analysts, not engineers.
- The most important knowledge is tacit. The only way to reach it is to ask questions. Expect to co-create the model: experts often have only the happy path in mind, and asking about edge cases surfaces conflicts and white spots in their own understanding. This is especially true for core subdomains.
- Brownfield projects already have a language, often polluted with table names and technical terms. Be patient and fix it where you control it: documentation, tests and source code.
- In non-English-speaking organisations use at least English nouns for domain entities so code and conversation share names.

### Practical tools

- A shared glossary (wiki) maintained by everyone, not just leads.
- Gherkin scenarios domain experts can read and verify (do not expect them to write these).
- Static analysis that flags forbidden or inconsistent terms where available.

When modelling, ask: what purpose does this model serve, and what is the minimum it must contain to serve it? All models are wrong, some are useful.

## 3. Divide models into bounded contexts

When different domain experts hold conflicting mental models of the same term (marketing's "lead" is a notification of interest; sales' "lead" is a long-running process), neither a single enterprise-wide model nor prefixed names ("marketing lead", "sales lead") work. The first is a jack of all trades that serves nothing; the second adds cognitive load and nobody says the prefixes aloud.

The DDD answer is the **bounded context**: split the ubiquitous language into smaller languages, each consistent within an explicit boundary. The same term may have different meanings in different contexts, and that is correct, not a defect.

### What a bounded context is

- The **consistency boundary of a ubiquitous language** and of the model it represents. Terms, principles and rules are only consistent inside it. "Ubiquitous" means ubiquitous inside the boundary, not across the organisation.
- A **physical boundary**: each bounded context is implemented as its own service or project, implemented, evolved, versioned and deployed independently, with the technology stack that suits it. Subdomains inside a context are logical boundaries (modules, packages, namespaces).
- An **ownership boundary**: exactly one team owns a bounded context. A team may own several contexts, but no two teams share one. This forces explicit integration contracts instead of implicit assumptions.

### Subdomains versus bounded contexts

Subdomains are **discovered**; bounded contexts are **designed**. The consistency of the language sets the widest possible boundary. Inside that you choose how to decompose further, and that choice is a strategic design decision. One-to-one subdomain-to-context mapping is reasonable but not required. You may also want several models of the same subdomain to solve different problems (several maps of the same territory), which a forced one-to-one mapping would prevent.

### Choosing the size

- Size is not a goal. Usefulness is. Wide boundaries are harder to keep consistent; narrow boundaries multiply integration overhead.
- Legitimate reasons to carve a smaller context out of a larger one: forming a new team, separating development lifecycles, or scaling one piece independently.
- **Never split a coherent set of use cases that operate on the same data** across contexts. If every business change hits two contexts at once and forces simultaneous deployment, the boundary is wrong.

### Checklist before declaring a bounded context

- Does the same term carry one meaning everywhere inside it?
- Could it be deployed and versioned on its own?
- Does one team own it end to end?
- Does it contain a coherent set of use cases that mostly change together?
- Can you state the problem its model solves in one sentence?

## 4. Integrate bounded contexts

Contexts are independent in evolution, not in operation. Every touchpoint is a **contract**, and because contexts speak different languages the contract's language must be chosen deliberately. The integration patterns are grouped by the kind of collaboration between the owning teams.

### Cooperation (teams with good communication, often one team)

- **Partnership.** Ad hoc, two-way coordination. One team announces an API change, the other adapts. Needs high commitment, frequent synchronisation and continuous integration. Poor fit for geographically distributed teams.
- **Shared kernel.** A small overlapping model (ideally only integration contracts and data structures crossing the boundary) is implemented once and referenced by several contexts. Any change is immediately reflected everywhere and must trigger integration tests in all consumers. It couples lifecycles and violates single-team ownership, so it must be justified: use it only when the cost of duplication exceeds the cost of coordination, which is more likely for volatile core subdomains. Common legitimate uses: a pragmatic stopgap while modernising a legacy system, or making the contract explicit between contexts owned by the same team so a partnership does not wash the boundary away.

### Customer-supplier (upstream and downstream can succeed independently; power is unbalanced)

- **Conformist.** Upstream dictates the contract in its own model, take it or leave it. Downstream adopts that model wholesale. Reasonable when the upstream contract is an industry standard or simply good enough.
- **Anticorruption layer (ACL).** Downstream refuses to conform and translates the upstream model into its own. Use when the downstream holds a core subdomain, when the upstream model is a mess (legacy systems), or when the upstream contract changes often so that changes stay confined to the translation layer. It keeps foreign concepts out of the consumer's language.
- **Open-host service (OHS).** Power sits with the consumers and the supplier wants to protect them. The supplier decouples its implementation model from a public interface expressed in an integration-oriented **published language**, so the internal model can evolve freely and several versions of the published language can be exposed in parallel for gradual migration. OHS is the mirror image of an ACL: the supplier does the translating.

### Separate ways

No integration; each context duplicates the functionality. Justified when communication is too expensive (organisational size or politics), when the subdomain is generic and trivially embedded locally (a logging library), or when models are so different that an ACL would cost more than duplication. **Never for core subdomains**: duplicating the differentiator defeats the strategy of implementing it once and well.

### Choosing a pattern

| Situation | Pattern |
|---|---|
| Same team or tightly aligned teams, able to sync often | Partnership |
| Tight teams but boundaries keep blurring, or legacy being split | Shared kernel (minimal scope) |
| Upstream model is standard or good enough; downstream is supporting/generic | Conformist |
| Downstream is core, upstream is messy or volatile | Anticorruption layer |
| Upstream serves many consumers and must evolve internally | Open-host service with a published language |
| Integration costs more than duplication, and it is not core | Separate ways |

An ACL on the consumer side tends to appear in front of core subdomains; an OHS on the supplier side tends to appear in front of core and supporting subdomains that many others depend on.

## 5. Draw the context map

A context map is the visual record of the bounded contexts and the integration patterns between them. Read it for three things:

- **High-level design.** Which components exist and which models they implement.
- **Communication patterns.** Which teams collaborate closely and which keep each other at arm's length (ACL, separate ways).
- **Organisational issues.** If every consumer of one upstream team has built an ACL, or every separate-ways decision clusters around one team, that is an organisational problem wearing a technical costume.

Maintenance rules: introduce it at the start of the project; each team updates its own integrations; it can be kept as code (for example with Context Mapper). Expect it to be messy in reality: one pair of contexts can have several patterns at once when they span several subdomains or modules.

When asked to produce a context map, output a Mermaid diagram with contexts as nodes, directed edges from upstream to downstream, and the pattern on each edge (P, SK, CF, ACL, OHS/PL, SW). Add a short table listing the owning team per context.

## How this feeds the rest of the design

- Subdomain type decides the business logic pattern: supporting and generic lean towards transaction script and active record; core demands a domain model or event-sourced domain model. See `ddd-tactical-design`.
- Bounded contexts decide the physical services, their team ownership and their contracts. See `ddd-architecture` for layered, ports and adapters, CQRS and the messaging patterns that implement ACLs, OHS and cross-context workflows.
- Subdomain types change over time (core becomes generic when a vendor appears; supporting becomes core when the business finds an edge). Re-run this analysis when the business strategy moves. See `ddd-design-heuristics`.
- To discover subdomains, language and context boundaries collaboratively, run an EventStorming session. See `ddd-eventstorming`.
