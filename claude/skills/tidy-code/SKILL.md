---
name: tidy-code
description: >-
  Small, safe structural clean-ups of code before (or after) a behaviour change, from Kent Beck's Tidy First?. Use when asked to tidy, clean up, simplify, make readable or refactor code, when a behaviour change looks harder than it should because the surrounding code is messy, when deciding whether to tidy first, after, later or never, when splitting a tangled diff into structure and behaviour commits or PRs, or when reviewing a PR that mixes refactoring with feature work. Also trigger on "this function is hard to follow", "should I refactor this first", "the diff is too big", "dead code", "magic number", "nested ifs", or any mention of tidying, coupling or cohesion at function or file scale. Catalogues the fifteen tidyings with before/after shapes, chaining and batching, and the economics (coupling, cohesion, optionality, reversibility) that decide when tidying pays. Not for large refactorings or architecture; pair with ddd-tactical-design for those.
---

# Tidy first

A tidying is a tiny structural change that leaves behaviour untouched and makes the next behaviour change easier. Software design at this scale is minutes to an hour, done by you, for you, in diffs that change structure or behaviour but never both. The book's answer to "tidy first?" is: likely yes, just enough.

Source: Kent Beck, *Tidy First? A Personal Exercise in Empirical Software Design* (O'Reilly, 2023). Chapter-level detail lives in `references/`.

## The one rule

**Structure changes and behaviour changes never share a commit.** A behaviour change is observable by running the program (input/output pairs, invariants). A structure change is observable only by reading the code. Reviewers, bisects and reverts all depend on the two being separable. Label every commit S (structure) or B (behaviour); if a commit would need both letters, split it.

## When a tidying request arrives

1. **Read the code and name the mess.** Match what you see against the catalogue below. If nothing matches, it is probably not a tidying but a refactoring or a design change; say so.
2. **Decide first, after, later or never** with the table in the next section. Default to first, but only for the tidyings that make the change in front of you easier or make the code legible right now.
3. **Tidy one thing at a time.** One tidying, run the tests, commit as S. Do not mix a reading-order shuffle with a guard clause, or renaming with extraction. "A little" is a cognitive measure, not a line count: one conditional clause, one routine, one file.
4. **Then make the behaviour change** in its own B commit, with its own tests.
5. **Stop.** Tidyings are potato chips. Note further tidyings you spotted on a list for later; do not eat the next one while someone is waiting for the change.

## First, after, later or never

| Timing | Do it when | Signal in practice |
|---|---|---|
| **First** | It pays off immediately: comprehension now, or `cost(tidy) + cost(change after tidy) < cost(change as is)`. You know what to tidy and how. | "I am confused right now, and I can see which tidying removes the confusion." |
| **After** | You will change this area again soon, tidying is cheaper now than later (context still in your head), and the tidying is roughly proportional to the change (an hour of change, an hour of tidying, not a week). | "Now that it is done I can see how it should have been shaped." |
| **Later** | Big batch without immediate payoff but eventual payoff; it can be done in little batches. Put it on a list and pick items off in spare hours. Includes finishing API migrations so the old API can be deleted. | "This is a week of work and nobody is waiting on it." |
| **Never** | The behaviour of this code will never change again, and there is nothing to learn. | Truly static systems. Rare. |

Bias toward tidying first; the tidyings are tiny so a failed one costs little. Be wary of tidying becoming the point.

## The fifteen tidyings

Each is a single move with a precise prompt. Apply only when the prompt matches exactly; otherwise take a smaller step. Before/after shapes and caveats are in `references/tidyings.md`.

| # | Tidying | Prompt | Move |
|---|---|---|---|
| 1 | Guard clauses | A routine whose body is one big `if` (or nested `if not`) wrapping everything | Invert and return early. Only when the condition wraps *all* the rest of the routine. Seven guard clauses is not tidier. |
| 2 | Dead code | Code that is never executed | Delete it. Version control remembers. If reflection makes you unsure, log its use in production first. |
| 3 | Normalise symmetries | The same idea written several ways (four styles of lazy init) | Pick one form, convert the variants, one kind of variation per tidying. |
| 4 | New interface, old implementation | The routine you must call has an awkward interface | Write the interface you wish you had; implement it by calling the old one. Migrate callers later. |
| 5 | Reading order | The detail that explains the file is at the bottom | Reorder so a reader meets things in the order they need them. Beware declaration-order-sensitive languages. Do nothing else in the same diff. |
| 6 | Cohesion order | A change needs edits in widely scattered spots | Move coupled routines next to each other, coupled files into one directory, coupled code into one repo. Decouple instead if you know how and can afford it. |
| 7 | Declaration and initialisation together | `int a` ... twenty lines ... `a = ...` | Move initialisation up to the declaration, respecting data dependencies. |
| 8 | Explaining variables | A big expression you have just understood | Extract the subexpression into a variable named for its intent (`width`, `height`, not `tmp`). |
| 9 | Explaining constants | A literal (`404`, a repeated string) you have just decoded | Introduce a named constant. Not when the same literal means different things in different places. |
| 10 | Explicit parameters | A routine reads data it was not passed (a params map, an env var deep inside) | Split it: a top half gathers inputs and passes them explicitly to a body that takes named parameters. Push env reads up the call chain. |
| 11 | Chunk statements | One block does this, then that | Put a blank line between the parts. The simplest tidying; sets up 8, 12 and 14. |
| 12 | Extract helper | A block with an obvious purpose and little interaction with its neighbours | Extract and name it after the purpose, not the mechanism. Also to isolate the lines about to change, and to express temporal coupling (`a()` then `b()` always). |
| 13 | One pile | Code split into pieces that hinder understanding (long repeated argument lists, repeated conditionals, poorly named helpers, shared mutable state) | Inline until it is one pile, understand it, then extract better pieces. |
| 14 | Explaining comments | "Oh, so *that* is what is going on" | Write down only what the code does not say: a constraint, a non-obvious coupling, a defect just found. A header comment for a file with none. |
| 15 | Delete redundant comments | A comment that says exactly what the code says | Delete it. Often a previous tidying (a guard clause) just made it redundant. Only delete the completely redundant. |

## Chaining

Tidyings set up the next one; see `references/managing.md` for the full chain map. Common sequences:

- Chunk statements, then explaining comment or explaining variable, then extract helper, then delete the now redundant comment.
- Dead code, then reading order or cohesion order (the clutter was hiding the shape).
- Guard clause, then the condition becomes an explaining variable or helper.
- One pile, then chunk, comment, extract.
- Explaining comment, then move its information into a variable, constant or helper name and delete the comment.

Each link is a separate S commit. Practise the notes before playing melodies.

## Batching and review

- **Fewest tidyings per PR possible**, ideally one, separate from the behaviour PR. More per batch means more merge collisions, more chance of an accidental behaviour change, and more speculative tidying.
- What pushes batches larger is the fixed cost of review. Lower that cost rather than accept the bigger batch: in a trusted team, tidying PRs can skip review entirely.
- Tidying is a minutes-to-an-hour activity. More than an hour before a behaviour change means you have lost track of the minimum tidying the change needs. Changes cluster (Pareto), so tidyings cluster; soon most changes land in already tidy code.
- **Got tangled?** An hour in, tidyings and changes are interleaved. Options: ship as is (rude to reviewers, error prone), untangle into separate commits or PRs, or discard and redo tidy first with what you now know. Beck recommends the last; the sunk cost is small and the redo often reveals something new. Notice the tangle early and it hardly matters which you pick.

## Why it works (the theory, briefly)

Full treatment in `references/theory.md`.

- **Design is beneficially relating elements.** Designers can only create or delete elements, create or delete relationships, or increase the benefit of a relationship. `box.width() * box.height()` in the caller becomes `box.area()`: one new element, one simpler relationship.
- **Structure buys options; behaviour earns cash.** Discounted cash flow says earn sooner, spend later, so do not tidy first. Option value says spend a little now to keep many cheap futures open, so do tidy. Tidy first for certain when `cost(tidy) + cost(change after) < cost(change as is)`; otherwise it is judgment, amortisation across a series of changes, or honest self-care.
- **Structure changes are reversible; behaviour changes often are not.** Extract a helper you dislike? Inline it. Send 100,000 wrong tax notices? Not so much. Spend review effort in proportion to irreversibility. Make big design moves reversible (prototype behind a flag, tidy first so the flag is checked in few places).
- **Coupling**: two elements are coupled *with respect to a change* if changing one forces changing the other. Analyse by looking at what changes together (files that co-occur in commits), not just at static structure. 1-N and cascading coupling produce the power-law cost of software.
- **Constantine's equivalence**: `cost(software) ~= cost(change) ~= cost(big changes) ~= coupling`. Reduce coupling to reduce cost, but decoupling for one class of change tends to add coupling for another, so do not squeeze out the last bit.
- **Cohesion**: coupled elements belong in the same container; uncoupled elements belong elsewhere. Extract a cohesive sub-element, or move the strangers out. One element at a time.

## Four questions before any tidying

1. Cost: will this make costs smaller, later or less likely?
2. Revenue: will it make value larger, sooner or more likely?
3. Coupling: will I need to change fewer elements?
4. Cohesion: will the elements I need to change sit in a smaller, more concentrated scope?

And one more: will it bring some ease to the programming? A little of that is allowed.

## Reference files

- `references/tidyings.md`: the fifteen tidyings with before/after shapes and caveats (Part I).
- `references/managing.md`: separating, chaining, batch sizes, rhythm, getting untangled, first/after/later/never (Part II).
- `references/theory.md`: beneficially relating elements, structure versus behaviour, time value, options, reversibility, coupling, Constantine's equivalence, cohesion (Part III).
