# Managing tidying (Tidy First? Part II)

## Separate tidying from behaviour change

The tail-chasing loop: tidyings in with the behaviour change, reviewers say the PR is too long; tidyings in their own PRs, reviewers say they are pointless; repeat. The tidyings have to go somewhere or you stop tidying.

Answer: tidyings go in their own PRs, with as few tidyings per PR as possible. Behaviour changes in separate PRs. Every time you switch from structure to behaviour or back, open a new PR (or at least a new commit).

The learning curve, as the book draws it:

1. An undifferentiated mass of changes. Fixing an `if`, noticing a bad name, fixing that, back to the `if`. Change is change.
2. The picture snaps into focus: some changes alter behaviour (visible when running the program), some alter structure (visible only by reading). Label them B and S.
3. Flows appear: chunk statements leads to extract helper leads to an easy behaviour change. Programming becomes chess; you see several moves ahead.
4. Split the sequences into separate PRs: S, S, B, S, B.

Trade-offs: one big PR shows the whole picture but defeats useful review; tiny PRs invite detailed feedback at the risk of going into the weeds. Review latency is a reinforcing loop in both directions: fast reviews encourage smaller PRs, which review faster; slow reviews encourage bigger PRs, which review slower. Once tidying feels safe, experiment with not requiring review on tidying PRs.

## Chaining

Tidyings set up further tidyings. Manage the urge: you just tidied, should you tidy more? It depends (Part III). Prefer tiny steps; from outside it looks like running.

| After this tidying | Look for |
|---|---|
| Guard clause | The condition becomes an explaining helper or explaining variable |
| Dead code | Reading order or cohesion order now visible under the removed clutter |
| Normalise symmetries | Parallel code can be grouped (a file of look-alike entry points grouped at the top as a table of contents) |
| New interface, old implementation | Converting callers one at a time (the first fan-out: one tidying spawns many) |
| Reading order | Symmetries to normalise, now that similar code is adjacent |
| Cohesion order | A sub-element to extract (a helper object is beyond tidying, but you will start seeing it) |
| Explaining variables | The right-hand side becomes an explaining helper; the variable name makes a comment redundant |
| Explaining constants | Cohesion order: group constants that change together |
| Explicit parameters | A parameter object, and code that moves into it (beyond tidying; abstractions found this way beat speculative ones) |
| Chunk statements | An explaining comment per chunk, or extract a chunk as a helper |
| Extract helper | A guard clause, explaining constants or variables, redundant comments to delete |
| One pile | Chunk statements, explaining comments, extract helpers |
| Explaining comments | Move the information into a variable, constant or helper name |
| Delete redundant comments | A better reading order, or explicit parameters |

A failed tidying is expensive relative to a chain of successful ones. Practise the notes of the scale before forming melodies.

## Batch sizes

How much tidying before integrating and deploying (the same thing, ideally)? Tidying meets an immediate need: structural changes supporting the *next* behaviour change, not a distant future.

Costs that rise with more tidyings per batch:

- **Collisions**: longer before integration, more chance of merge conflicts, each of which raises merge cost by an order of magnitude.
- **Interactions**: more chance the batch accidentally changes behaviour, with the same jump in cost.
- **Speculation**: more tidying "just because".

The cost that falls with bigger batches is the fixed cost of getting a change through review and deployment. Programmers feel that cost and move toward bigger batches. Those curves are not laws of physics: reduce the cost of review so batches can shrink. In teams with trust and a strong culture, tidyings do not need review at all. Getting there takes months of practice, experiments and reviewing errors together.

## Rhythm

Tidying at this scale takes minutes up to an hour before a behaviour change. More than an hour usually means you have lost track of the minimum structure change the behaviour change needs. Sometimes the code is such a mess that hours of tidying pay; that state does not last.

Pave the path: behaviour changes cluster (80% of changes in 20% of files), so tidyings cluster in exactly the places behaviour changes want to happen. Soon most changes land in already tidy code, and untidy code becomes the exception even though most of the system was never touched.

## Getting untangled

An hour into a change you understand all the behaviour changes needed and all the tidyings that ease them, and they are tangled together. Three options, none attractive:

- **Ship it as is.** Quick, impolite to reviewers, error prone.
- **Untangle** into separate PRs, a sequence of PRs, or a sequence of commits in one PR. Polite, can be a lot of work.
- **Discard and start over, tidying first.** More work, leaves a coherent chain of commits.

Sunk cost pulls toward the first two. Beck recommends experimenting with the third: re-implementing often reveals something new, and the point is to explain intent to people, not merely instruct the computer by the shortest path. The earlier you notice the tangle, the smaller the job and the less the choice matters.

## First, after, later, never

**Never.** Only when the behaviour of the code will never change again and there is nothing to learn from improving it. Rare but real; "if it ain't broke" applies to truly static systems.

**Later.** Not a unicorn. The prerequisite is believing there is enough time to do the work properly; ask "how would we work if we had enough time?" and notice how different the answer is from current practice. Keep a list of messes (the Fun List). With a spare hour, take an item. Tidying later pays when an area is guaranteed to change, when it removes a messiness tax (finish migrating the hundred remaining callers so the old API can go), as a learning tool (the code "knows" how it wants to be structured), and because it feels good, and a happy programmer is a better one.

**After.** You changed behaviour in messy code without seeing how to tidy, and now you see how it could have been easier. Tidy after if you will change the same area again soon, if it is cheaper now (context in your head, nobody has interfered yet), and if the tidying is proportional to the change (an hour of change justifies an hour of tidying; a week of tidying goes on the list).

**First.** Ask:

- How much harder is the messy change? If tidying does not make it easier, do not tidy first.
- How immediate is the benefit? Reading for comprehension counts; tidying speeds comprehension.
- How will it amortise? Once-only change, limit the tidying; weekly payoff for years, go for it.
- How sure are you? Bias away from speculation. "I can see the mess, right here, and without it this change is easy" is enough. So is "I am confused right now".

Bias toward tidying first, but watch for tidying becoming an end in itself. The tidyings are tiny so you need not think hard before applying one, and a tidying that does not pay off costs little.

Summary:

- Tidy **never** when you will never change this code again and there is nothing to learn.
- Tidy **later** when there is a big batch without immediate payoff, eventual payoff exists, and you can do it in little batches.
- Tidy **after** when waiting until next time will cost more, or you need the sense of completion.
- Tidy **first** when it pays off immediately in comprehension or cheaper change, and you know what to tidy and how.
