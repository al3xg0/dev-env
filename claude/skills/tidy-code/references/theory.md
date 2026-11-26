# Theory (Tidy First? Part III)

## Beneficially relating elements

Software design is beneficially relating elements.

- **Elements**: structures have parts with boundaries, containing sub-elements. Tokens, expressions, statements, functions, objects or modules, systems. Natural hierarchies are not homogeneous; the container differs from what it contains.
- **Relating**: elements exist in relation. Invokes, publishes, listens, refers (reads a variable).
- **Beneficially**: one giant soup of tiny elements (assembly with a global namespace) behaves identically to a well-designed program but cannot be changed, because the relationships are too many and too implicit. Intermediate elements let one element be simpler because another carries part of the complexity.

Designers can only: create and delete elements; create and delete relationships; increase the benefit of a relationship.

```
caller()
    return box.width() * box.height()
```

becomes

```
caller()
    return box.area()

Box>>area()
    return width() * height()
```

One new element, one simpler relationship (one invocation instead of two), at the cost of a bigger `Box`. The structure of a system is its element hierarchy, the relationships, and the benefits those relationships create.

## Structure and behaviour

Software creates value in two ways: what it does today (behaviour) and what it could be made to do tomorrow (options). Behaviour is characterised by input/output pairs and invariants; it earns the money. Options are the economic magic of software: a system that could become either a 100-for-10 machine or a 20-for-1 machine is worth more than the 10-for-1 machine it is today, even before anyone knows which. The more volatile the environment, the more options are worth. Adding to what the system could do next creates value without changing behaviour.

Option killers: a key person leaves; distance from customers; the cost of change skyrockets. Tidying addresses the third: keep the kitchen clean as you cook.

Structure does not affect behaviour (one giant function or many small ones, same paycheck) but it creates or destroys options. The trouble is legibility: a new button is visible, "easier to change" is not, so nobody can tell whether structure investment was enough or too much. Structure and behaviour changes both create value but differ fundamentally in reversibility.

## Economics: time value and optionality

Two properties of money that shape design:

- **A dollar today is worth more than a dollar tomorrow**: earn sooner, spend later.
- **In chaos, options beat things**: create options under uncertainty.

They conflict. Earning now can close options; not earning now can mean not surviving to exercise them.

### Time value

Value a system as dated cash flows, not by what it is (lines of code, services, cyclomatic complexity are irrelevant to a buyer). "Costs 10 million, earns 20 million over ten years" versus "costs 10, earns 12" is a trick question until you ask when and how sure. Paying 10 today for 20 in ten years is nerve-racking; receiving 12 today and paying 10 in ten years is a no-brainer.

Time value favours **tidy after** over tidy first: ship the behaviour that earns, spend on structure later. Except when `cost(tidy) + cost(change after tidy) < cost(change as is)`; then tidy first, always. At minutes-to-hours scale discounting barely matters, but the habit matters for larger scales.

### Options

A call option is the right, not the obligation, to buy something later at a fixed price. Parameters: the underlying, its price and volatility, the premium paid now, the duration (software behaves like an option exercisable any time before expiry). In software, the behaviour changes you could make next are the underlying, and design done today is the premium.

Lessons from implementing options pricing test-first:

- "What can I implement next?" has value before it is implemented. You are mostly paid for what you could do next.
- More behaviours in the portfolio, more value. More valuable behaviours, more value, and you need not know which will win as long as the option stays open.
- The more uncertain the predictions, the more the option is worth relative to just building the thing. Embracing change maximises value exactly where conventional development fails worst.

Hence: the more volatile the value of a change, the better; the longer you can keep developing, the better; cheaper future development helps but is a small share of the value; the less design needed to create an option, the better.

### Options versus cash flows

The tug-of-war behind "tidy first?":

- Discounted cash flow: earn sooner and surer, spend later and less surely. Do not tidy first; maybe not after or later either.
- Options: spend now to earn more later even without knowing how. Tidy first when it creates options, and after, and later.

Tidy first for certain when `cost(tidy) + cost(change after tidy) < cost(change as is)`; set boundaries so you do not overshoot. When the inequality goes the other way you may still tidy first if a series of changes amortises it, or if the options created outweigh the certain spend, or because it makes the work more pleasant (a little tidying as self-care, knowing it runs against the incentives). At this scale you cannot calculate precisely; you are training judgment about incentives and practising on yourself the relationship skills you will later need with colleagues.

## Reversible structure changes

A bad haircut grows out; a bad tattoo is far harder to undo. Structure changes are generally reversible: extract a helper, dislike it, inline it, as if it never existed. Behaviour changes often are not: 100,000 tax notices with the wrong number cost plenty and may cost reputation permanently.

Treat the two differently. Irreversible decisions deserve slow, deliberate, repeated checking because the downside is large. Reversible decisions have modest upside and almost no downside, so invest little in avoiding mistakes with them. That is why the word is "tidying": no big deal. Review processes that do not distinguish reversible from irreversible changes spend the same effort on radically different payoff profiles.

Make irreversible design moves reversible for a while: "extract as a service" via a prototype in production behind a feature flag, tidied first so the flag is checked in few places. If it turns out the service should have been a SQL query, back out cheaply. A reversible decision becomes irreversible when it propagates (an integer that should be a long, in a million places): think a little more about which decisions will propagate, and when it happens anyway, reverse it one tidying at a time, in short interruptible slices.

## Coupling

Yourdon and Constantine found that expensive programs shared one property: changing one element required changing others. Cheap programs needed localised changes. Two elements are coupled *with respect to a particular change* if changing one necessitates changing the other.

```
coupled(E1, E2, Δ) ≡ ΔE1 ⇒ ΔE2
```

Caller and callee are coupled with respect to renaming the callee, not with respect to reformatting its body. Coupling with respect to a change that never happens is the boulder that never rolls down the hill. So coupling cannot be read from source alone; look at which files change together in commits.

Two properties make coupling dangerous: **1-N** (one element coupled to many; tooling such as automated rename can neutralise this) and **cascading** (a change ripples, then the ripple ripples). Cascades create the power-law distribution of change cost. "Complex" systems are ones where changes have unexpected consequences: two services on one rack coupled through a backup policy saturating the top-of-rack switch, their teams unaware of each other. Page-Jones's "connascence" is the same idea.

When a messy change feels messy because "if I change this I must change all those", go through the tidyings and see which reduce coupling.

## Constantine's equivalence

The old alarm that 70% of cost is maintenance misreads software as a thing built once and then kept running. In fact value-creating software can ship after a few percent of its eventual cost, and the sooner real usage gives feedback the less is spent on behaviour that does not matter. Therefore:

```
cost(software) ~= cost(change)
```

Changes are not equal. Most cost about one unit; occasionally one costs ten, a hundred, a thousand. Power law: the few big ones outweigh all the small ones together.

```
cost(change) ~= cost(big changes)
```

What makes big changes big is propagation: this element forces those two, each forcing others. Coupling.

```
cost(big changes) ~= coupling
cost(software) ~= coupling
```

To reduce the cost of software, reduce coupling. Decoupling is not free.

## Coupling versus decoupling

Coupling is often invisible until stepped on. It exists because the coupled implementation was the economically right call at the time (revenue sooner, expense later; now it is later), because it was not a problem until now (nobody knew translation would be needed), or because some coupling is inevitable. Why it is there does not matter; today's choice is pay the cost of coupling or pay the cost of decoupling. "Tidy first?" is this decision in miniature.

Example: sender and receiver sharing a format are coupled, and must deploy in lockstep. An interface definition language removes that: change the format in one place. But the coupling is not gone; a new field still has to be computed in the sender before the receiver can use it. The IDL bought more options over implementation order, not freedom from coupling.

Beck's unprovable belief: reducing coupling for one class of change increases it for another. Do not squeeze out every last bit. The costs of coupling and decoupling are not knowable in advance, play out over time (so discounting applies), and decoupling creates options of uncertain value. You can land anywhere on the continuum.

## Cohesion

Coupled elements should be sub-elements of the same containing element. Elements that are not coupled should go elsewhere.

A module of ten functions, three of them coupled: either extract the three into their own sub-module (cohesive, because its elements change together; the parent is no worse off) or move the seven uncoupled functions out to wherever their real siblings are, or into a sub-module of their own if they are coupled to each other. Extract helper is the first kind of move: if the lines of the helper change together, the helper is cohesive, with easier analysis, easier change and resistance to accidental behaviour change.

No sudden moves. Information about what is coupled with what is incomplete and changing. Move one element at a time and leave the code better than you found it.

## Conclusion

Four forces behind every "tidy first?" answer:

- **Cost**: will tidying make costs smaller, later or less likely?
- **Revenue**: will it make revenue larger, sooner or more likely?
- **Coupling**: will I need to change fewer elements?
- **Cohesion**: will the elements I must change sit in a smaller, more concentrated scope?

And you: will tidying bring some ease and satisfaction? A rushed programmer changing painful code is not at their best. Do not get carried away; tidying is Pringles, and when tidying first, resist the next one. Tidy to enable the behaviour change; save the binge for later when nobody is waiting.

Scales of design, as the series frames them:

| Who | When | What | How | Why |
|---|---|---|---|---|
| You | Minutes to hours | Tidyings | Structure/behaviour diffs | Coupling, cohesion |
| You and colleagues | Days to weeks | Refactorings | Weekly planning | Power laws |
| All stakeholders | Months to years | Architectural evolution | Dynamic balance | ? |

Tidy first? Likely yes. Just enough. You're worth it.
