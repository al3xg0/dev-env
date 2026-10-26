---
name: ddd-eventstorming
description: Plan, facilitate or simulate an EventStorming workshop, from Vlad Khononov's Learning Domain-Driven Design (chapter 12). Use when the user wants to run EventStorming (in person or remote), prepare a session (participants, materials, agenda, legend), model a business process as a timeline of domain events with commands, actors, policies, read models, external systems, aggregates and bounded context candidates, recover lost domain knowledge from a legacy system, explore new requirements with stakeholders, onboard people into a domain, or turn a process description into a first-cut event model. Also trigger when the user describes a business process in prose and asks for domain events, commands or aggregate candidates, or asks "what are the sticky note colours", "big picture versus process level", or "how do I facilitate this". Feeds ddd-strategic-design (bounded contexts) and ddd-tactical-design (aggregates, events).
---

# EventStorming

EventStorming is a low-tech group activity for rapidly modelling a business process as a timeline of domain events on sticky notes, enriched step by step with commands, actors, policies, read models, external systems, aggregates and bounded context candidates. Its real output is not the wall of notes. It is the knowledge shared between stakeholders, the alignment of their mental models, the conflicts and white spots that surface, and the ubiquitous language that forms as people argue about what to write on a note.

## When to run one

- **Build a ubiquitous language.** The group synchronises terminology while modelling.
- **Model a business process** and discover candidate aggregates and bounded contexts.
- **Explore new requirements** so everyone is on the same page and edge cases surface before implementation.
- **Recover lost domain knowledge**, especially for legacy systems being modernised, by merging what each participant knows into one picture.
- **Improve an existing process** by seeing it end to end and spotting bottlenecks and manual steps.
- **Onboard new team members.**

Do not run one for a simple, obvious, sequential process with no interesting rules. It will be a waste of key people's time.

## Who and what

**Participants.** A diverse group of everyone who knows the process: domain experts, engineers, product owners, testers, UI/UX designers, support staff. Diversity is where the knowledge comes from. Cap at about 10 in person so everyone can contribute; about 5 for remote sessions, running several sessions and merging the models if more voices are needed.

**Materials.**

- A large modelling surface: a wall of butcher paper or the biggest whiteboard available. You will use all of it.
- Plenty of sticky notes in every colour of the legend, enough for everyone to write freely.
- Markers for everyone. Supplies must never be the bottleneck.
- Healthy snacks; sessions run two to four hours.
- A spacious room with no big table in the middle and, ideally, no chairs. People stand, move and engage; sitting leads to zoning out. Keep a few chairs for anyone who needs them.

**Legend.** Build it on the wall at the start as you explain each element, and keep it visible all session. Stick to the conventional colours so the model matches every book and training people may have seen.

| Colour | Element | Wording |
|---|---|---|
| Orange | Domain event | Past tense: "Order shipped" |
| Light blue | Command | Imperative: "Submit order" |
| Small yellow | Actor | Persona: customer, editor, administrator |
| Purple (lilac) | Policy / automation | "Whenever X then Y", optionally with a condition |
| Green | Read model | The view the actor looks at before deciding |
| Pink | External system | Anything outside the explored domain |
| Pink, rotated as a diamond | Pain point / hotspot | Bottleneck, manual step, missing knowledge |
| Large yellow | Aggregate | Commands on the left, events on the right |
| Vertical bar / tape | Pivotal event | Marks a phase or context change |

## The ten steps

1. **Unstructured exploration.** Everyone grabs orange notes and writes every domain event they can think of, something interesting that happened in the business, in the past tense. No ordering, no de-duplication, no debate yet. Keep going until the rate of new events slows markedly.
2. **Timelines.** Order the events as they occur. Start with the **happy path**, then add alternative flows (errors, different business decisions) as branches or arrows. Fix wrong events, merge duplicates, add missing ones.
3. **Pain points.** With the whole flow visible, mark hotspots with diamond pink notes: bottlenecks, manual steps needing automation, missing documentation, missing knowledge ("how are airfare prices compared here?"). Keep adding these throughout whenever someone raises a concern, so nothing is lost and they can be revisited afterwards.
4. **Pivotal events.** Find the events that mark a change of phase or context ("shopping cart initialised", "order initialised", "order shipped", "order delivered", "order returned") and mark them with vertical bars. These are **candidate bounded context boundaries**.
5. **Commands.** Add light blue notes for what triggers events, phrased in the imperative, placed before the events they cause. Where the actor is obvious, add a small yellow actor note on the command. Not every command has an actor yet.
6. **Policies.** For commands with no actor, find the automation: an event that triggers a command ("when Shipment approved, then Ship order"). Purple notes link event to command; write any decision criteria on the note ("only for VIP customers"). Draw arrows if event and command are far apart.
7. **Read models.** Green notes placed before commands describing the data (screen, report, notification) the actor consulted to decide on the command.
8. **External systems.** Pink notes for any system outside the explored domain, either issuing commands into the process (a CRM triggering "Ship order") or being notified of events through a policy. By the end of this step every command is executed by an actor, triggered by a policy, or called by an external system.
9. **Aggregates.** Group related commands and the events they produce under large yellow notes: an aggregate receives commands and produces events.
10. **Bounded contexts.** Group aggregates that are closely related by functionality or coupled through policies. These groups are natural candidates for bounded contexts.

## Recommended variant: big picture first, then per process

When introducing EventStorming to an organisation, run a **big picture** session covering steps 1 to 4 across the whole business domain. It produces a broad model, a strong base for the ubiquitous language, and candidate context boundaries. Then run a dedicated **process-level** session, all ten steps, for each business process that matters.

The method is guidance, not law. Adjust the recipe to what works for the group.

## Facilitation

- Open with a short overview: what we are doing, which process we are exploring, and the legend, built live from the notes you will use.
- **Watch the energy.** When it slows, ask questions to reignite, or move to the next step.
- It is a group activity. Make sure everyone gets to model and to talk. Draw in anyone drifting to the edges by asking them about the current state of the model.
- Take breaks. Do not restart until everyone is back, and restart by walking the group through the current model to rebuild the shared mood.
- **Remote.** The creator of the format objects to remote sessions because participation suffers, but when necessary use a shared board tool (for example Miro), be more patient, keep the group to around five, run several sessions and merge. Return to in person when you can.
- You do not need to be an expert to facilitate. Follow the steps and learn by doing.

## What the result feeds

- Pivotal events and aggregate clusters: candidate bounded contexts for `ddd-strategic-design`.
- Commands, events and aggregates: a blueprint for a domain model, and in particular an event-sourced domain model, for `ddd-tactical-design`. Whether to go event-sourced is still a business-driven decision.
- Policies: candidate sagas and process managers for `ddd-architecture`.
- Hotspots: a backlog of missing knowledge and process inefficiencies.
- The shared vocabulary on the notes: the first draft of the glossary.

## Simulating a session from a written process

When the user supplies a process description instead of a room full of people, produce a first cut in this order and label each element with its colour so it can be transferred to a wall or board:

```
Events (orange, past tense, happy path in order, then branches)
Pivotal events (bars) and the phases they separate
Commands (blue) with actors (yellow) where obvious
Policies (purple) with conditions
Read models (green)
External systems (pink)
Hotspots (pink diamond): every assumption you had to make and every gap in the description
Aggregates (large yellow): commands in, events out
Bounded context candidates
Open questions for the domain experts
```

Be explicit that this is a draft to be torn apart in the room. The point of the workshop is the conversation, and a pre-built model should provoke it, not replace it.
