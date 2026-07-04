---
name: explorer
description: Codebase exploration and architecture extraction skill. Use this skill whenever the user wants to understand one or more codebases, repositories or services from the code itself, for example "explore this repo", "what does this service do?", "map our architecture", "how do these services talk to each other?", "which events does X publish?", "generate a C4-style overview", or when they mention L1/L2/L3 analysis. Also trigger when the /architect skill needs ground truth about the current system, or when the user wants context enriched from Linear tickets, Confluence pages or incident history. Works on uploaded code, cloned repositories, or multiple codebases at once, and produces levelled artefacts (L1 system overview, L2 cross-service plumbing, L3 single-service deep dive) with Mermaid diagrams.
---

# Explorer

Build a mental model of a system and use the code as the source of truth. Then express that mental model as levelled artefacts (L1/L2/L3, similar in spirit to C4 diagrams), each a standalone Markdown document with at least one Mermaid diagram. The goal is insight, not inventory: a reader should finish each artefact understanding something they could not see by scrolling the repo.

## The method: form a mental model from the code

This skill follows a staff engineer's approach to understanding systems. The code is the primary source; everything else corroborates or explains it. When reading a codebase, always locate three things first, in this order:

### 1. Entry points

APIs, workers, cron jobs, message consumers, CLI commands, webhooks. Entry points answer "how does the outside world cause this service to do anything?" and they are the roots of every call graph worth following.

Find them via: route registrations and controllers, gRPC/GraphQL service definitions, queue/topic consumer registrations and handler bindings, scheduler configuration (cron expressions in code or manifests, k8s CronJobs), `main`/startup wiring, and Dockerfile/compose entry commands. List every entry point with its trigger (HTTP request, event, schedule, manual) before going deeper.

### 2. Data and database

Where the stored data is defined and what shape it has. State outlives code; understanding the data model often explains more than reading the logic does.

Find it via: migration folders, schema files, ORM entities, event definitions and event store usage, projection/read model builders, and infra manifests that declare databases, streams, queues or caches. Distinguish clearly between event streams (source of truth in an event-sourced service) and projections/read models derived from them. Note who writes each store and who only reads it.

### 3. Key domain logic files

Usually the services/use-case layer: the files where business rules actually live, between the entry points and the data. This is where the vocabulary of the domain shows up (aggregate names, lifecycle transitions, invariants, policy decisions).

Find them by walking inward from entry points: what does each handler call? The files that many entry points converge on, or that emit domain events, are the heart of the service. Read these carefully; skim everything else.

Connecting the triad gives the mental model: **entry points show what can happen, domain logic shows what it means, data shows what is remembered.** Every artefact this skill produces should trace back to these three.

## Corroborating sources: tickets, docs and incidents

When more exploration is needed than the code alone provides, search the surrounding knowledge systems. Use whichever of these connectors are available in the conversation; if none are, ask the user for exports or skip with a note in "Open questions".

- **Linear**: search issues and projects for the service or topic name. Tickets reveal intent, known limitations, in-flight changes and the reasons behind odd-looking code. Recent issues on a service are a shortcut to its pain points.
- **Confluence** (via Atlassian Rovo): search for design pages, RFCs and domain documentation on the topic. Treat docs as claims to verify against the code, not as truth; where a doc and the code disagree, the code wins and the disagreement itself is a finding worth reporting.
- **Incident history** (incident.io, or postmortem pages in Confluence): past incidents and bug fixes are the fastest route to deep understanding, because they show where the mental model of previous engineers broke. For any service being deep-dived, look for its recent incidents and the fixes that followed; fold what they reveal (fragile integrations, ordering assumptions, retry behaviour) into the artefact.

Keep provenance straight in the output: statements from code are fact (cite file paths), statements from tickets/docs/incidents are context (cite the ticket/page), and inference is labelled as such. Never fabricate component names, event names or flows.

## The three levels

| Level | Question it answers | Scope | Primary diagram |
|---|---|---|---|
| **L1 - System overview** | What is this system for, and what are its major parts? | All codebases together | Component/context diagram (`graph`) |
| **L2 - Plumbing** | How do the parts actually talk to each other? | All services, focused on integration points | Event/message flow (`sequenceDiagram` or `graph LR` centred on the bus) |
| **L3 - Service deep dive** | How does this one service work inside? | One service at a time | Internal structure + aggregate lifecycle (`stateDiagram` where useful) |

Default behaviour when the user does not specify a level: for a first encounter with a codebase, produce L1 and offer L2/L3 as follow-ups. Do not produce all three levels unprompted; each is a meaningful artefact and the user should steer.

## Getting the code

- Uploaded archives or folders: work from `/mnt/user-data/uploads` (copy to `/home/claude` before modifying anything).
- Public or accessible GitHub repositories: clone with `git clone --depth 1` (github.com is reachable). For multiple repos, clone them side by side under one working directory.
- Very large codebases: do not read everything. Locate the triad first, then read selectively along the paths that connect it.

Useful search patterns while locating the triad: `grep -ri` for `publish`, `subscribe`, `consume`, `emit`, `topic`, `stream`, `queue`, `handler`, `cron`, `schedule`, and for past-tense class/type names (`*Created`, `*Started`, `*Completed`, `*Failed`, `*Changed`) which strongly signal domain events. Adjust to the language and libraries the manifests reveal.

## Level 1 - System overview

Purpose: high-level responsibilities and the business context that can be read out of the code, followed by a component diagram.

Process: for each codebase, do a quick triad pass (entry points, data, domain logic) at survey depth plus READMEs and manifests. From that, identify what business capability each service exists to provide, who its external actors are (users, hardware such as charge points, external networks, third-party APIs) and its two or three core responsibilities. Optionally corroborate service purposes against Confluence or Linear project descriptions.

Artefact: one file, `L1-system-overview.md`:

```markdown
# L1 - System overview: [system name]
## What this system does (business context)
[3-6 sentences of business purpose inferred from the code, naming the actual product concepts found]
## Services and responsibilities
[Per service: one short paragraph - purpose, key responsibilities, notable entry points and externals]
## Component diagram
[mermaid graph: services as nodes, external actors distinguished (e.g. different shape/class),
 edges labelled with the nature of the relationship, not protocol detail]
## Key observations
[2-5 genuine insights: e.g. surprising coupling, apparent domain boundaries, tech spread]
## Open questions
```

Keep L1 readable in five minutes. Resist detail; that is what L2 and L3 are for.

## Level 2 - Plumbing

Purpose: key details about each service, but told as the story of how the plumbing connects. If there is an event bus, this level shows how events travel across domains. L2 is about edges, not nodes.

Process: this level leans on the **entry points** and **data** legs of the triad across all services at once. Match producers to consumers: an event published in one service and a consumer entry point in another is an edge; so is an HTTP client call matching another service's route, or two services touching the same store. For each integration capture mechanism (event bus, HTTP, gRPC, shared DB, file drop), the concrete event/endpoint names, direction, and sync vs async. Then reconstruct two or three end-to-end flows that matter to the business (e.g. "a charging session from plug-in to invoice") as sequence diagrams. Incident history is especially valuable here: integration points feature in most incidents, and postmortems often document ordering and retry behaviour that the code only implies.

Artefact: one file, `L2-plumbing.md`:

```markdown
# L2 - Plumbing: how the services connect
## Integration inventory
[Table: producer | event/endpoint | mechanism | consumer(s) | defined in (file path)]
## Message flow diagram
[mermaid graph LR with the bus/broker as an explicit node; edges labelled with event names]
## End-to-end flows
[For each key business flow: short narrative + mermaid sequenceDiagram,
 with the broker as a participant and arrows labelled with actual event names from the code]
## Cross-domain observations
[Where similar entities cross boundaries and how they are translated; any synchronous
 coupling between domains that looks at odds with an otherwise async design; shared databases;
 integration points implicated in past incidents]
## Open questions
```

Every event name in L2 must exist in the code; include the defining file path in the inventory table.

## Level 3 - Service deep dive

Purpose: key details about one service at a time. Run once per service the user asks about.

Process: the full triad at depth. Enumerate every entry point with its trigger. Map the data: streams, projections, other stores, and their schemas. Read the domain logic files properly: aggregates, lifecycle events, invariants, policies. Trace one or two representative paths end to end (entry point → domain logic → data → events out). Then enrich with corroborating sources: recent Linear tickets touching the service, relevant Confluence pages, and past incidents/bug fixes, which reveal the sharp edges no amount of code reading surfaces quickly.

Artefact: one file per service, `L3-<service-name>.md`:

```markdown
# L3 - [Service name]
## Purpose and ownership
[What it does; which aggregates/entities it owns, based on where lifecycle events are created]
## Entry points
[Table: entry point | trigger (HTTP/event/cron/manual) | what it does | file path]
## Internal structure
[mermaid graph of modules/layers and their dependencies]
## Aggregates and domain logic
[Per aggregate: lifecycle events published (with file paths), key invariants and policies;
 stateDiagram where the lifecycle is non-trivial]
## Data
[Event streams, projections/read models, other stores; who writes, who reads]
## Consumed events and side effects
## Configuration and external dependencies
## Lessons from tickets and incidents
[Known limitations, recent pain points, incident-derived fragilities - with ticket/incident references]
## Notable implementation details and risks
## Open questions
```

## Working across multiple codebases

When given several repositories, do the triad survey on all of them before writing anything, so L1 and L2 reflect the whole rather than the first repo read. Keep a scratch notes file per repo in the working directory while exploring; the artefacts should be synthesis, not raw notes.

## Output handling

Write artefacts to `/mnt/user-data/outputs` and present them. In the chat, give a three or four sentence summary of the most important insight per artefact rather than repeating the document. Offer the natural next step: after L1, offer L2; after L2, offer L3 for the services that looked most interesting or risky.
