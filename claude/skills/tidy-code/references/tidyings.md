# The fifteen tidyings (Tidy First? Part I)

Each tidying is one move. Apply it only when its prompt matches precisely; if it almost matches, find the smaller step that makes it match (often extract helper first). Every tidying is its own structure-only commit. Pseudocode follows the book.

## 1. Guard clauses

Prompt: a routine whose entire body sits inside a condition.

```
if (condition)
    if (not other condition)
        ...all the rest of the routine...
```

Move:

```
if (not condition) return
if (other condition) return
...all the rest of the routine...
```

Reads as "here are the preconditions, now the real work". The single-return rule came from FORTRAN routines with multiple entry and exit points; it does not apply. Caveats: seven or eight guard clauses is not easier to read and needs a different partition of the complexity. Do not apply when the `if` wraps only *some* of the code and other code follows; extract the wrapped block to a helper first, then guard inside it.

## 2. Dead code

Prompt: code that is not executed.

Move: delete it. Version control is the archive; the five-way conditional under which you would want it back exactly as written, still working, is rare, and rewriting is usually better anyway. If reflection or dynamic dispatch makes you unsure, pre-tidy by logging its use, ship that, wait until confident, then delete. Delete a little per diff (one clause, one routine, one file, one directory) so a wrong guess reverts cleanly.

## 3. Normalise symmetries

Prompt: the same idea written in different ways. Lazy initialisation, for example:

```
if (foo == null) foo = ...
foo ??= ...
foo || (foo = ...)
foo = foo ?? ...
```

Move: pick one form, convert the variants to it. One kind of variation per tidying (all lazy inits now, something else later). Readers assume difference means difference; identical things should look identical and different things should look different. Also look for routines that are similar but not identical and separate the shared part from the differing part.

## 4. New interface, old implementation

Prompt: you need to call a routine and its interface is difficult, confusing or tedious.

Move: implement the interface you wish existed, and have it call the old one. Call the new interface from your change. Migrate other callers later, then inline. This is design at micro scale: "if the design were like X this change would be easy, so make it like X". The same impulse as coding backwards from the last line, writing the test first, and sketching the helper you wish you had.

## 5. Reading order

Prompt: you reach the end of a file and only then find the detail that would have explained everything before it.

Move: reorder the file into the order a reader would prefer. You just read it, so you know. Do not mix in any other tidying; do those before or after in separate diffs. In languages where declaration order changes execution, reorder only the relevant parts. There is no perfect order (primitives first then composition, or API first then implementation); use recent experience and give the next reader the sequence you wanted.

## 6. Cohesion order

Prompt: one behaviour change needs edits in several widely dispersed places.

Move: put the coupled elements next to each other. Routines side by side in a file; coupled files in the same directory; coupled code in the same repository before changing it. Eliminating the coupling is better when `cost(decoupling) + cost(change) < cost(coupling) + cost(change)`, but decoupling may be an intellectual stretch, a time or money stretch, or a relationship stretch (the team cannot absorb more change). Better cohesion sometimes unlocks the decoupling later, and sometimes just makes the coupling bearable.

## 7. Move declaration and initialisation together

Prompt:

```
int a
...code that does not use a...
a = ...
int b
...code that may use a but not b...
b = ...a...
```

Move:

```
int a = ...
...
int b = ...a...
...
```

Respect data dependencies (`a` before `b`). Try both "each variable just before first use" and "all together at the top" and keep whichever reads better. If hand analysis of dependencies goes wrong and behaviour changes, revert to the last good version and take smaller steps.

## 8. Explaining variables

Prompt: a big expression you have just worked out the meaning of.

```
return new Point(...big expression..., ...another big expression...)
```

Move:

```
x := ...big expression...
y := ...another big expression...
return new Point(x, y)
```

Name for intent (`width`, `height`, `top`, `left`). You are putting understanding back into the code, and separating the subexpressions so each can change alone.

## 9. Explaining constants

Prompt: a literal you had to decode, or a constant string repeated across the code.

```
if response.code = 404
```

Move:

```
PAGE_NOT_FOUND := 404
if response.code = PAGE_NOT_FOUND
```

Caveat: the same literal can mean different things in different places; `ONE = 1` helps nobody. Later tidyings group constants that change together and separate the ones that merely look alike.

## 10. Explicit parameters

Prompt: a routine works on data it was not explicitly passed. A params map:

```
params = { a: 1, b: 2 }
foo(params)
function foo(params)  ...params.a... ...params.b...
```

Move: split the routine.

```
function foo(params)
    foo_body(params.a, params.b)
function foo_body(a, b)
    ...a... ...b...
```

Also for environment variables read deep in the call tree: make them parameters and push them up the chain. Easier to read, test and analyse, and it closes off the habit of mutating the params map for implicit later use.

## 11. Chunk statements

Prompt: a block of code where you realise "this part does this, that part does that".

Move: a blank line between the parts. The simplest tidying, deliberately so: design must not be such a big deal that it does not happen. Opens the way to explaining variables (8), extract helper (12) and explaining comments (14). Compound interest applies, but do not get lost in the design vortex and forget to make the change.

## 12. Extract helper

Prompt: a block inside a routine with an obvious purpose and little interaction with the rest.

Move: extract it and name it after the purpose, not the mechanism (Fowler's Extract Method; use the IDE's automated refactoring). Two special cases:

- You need to change two lines in a long routine: extract exactly those lines, change them inside the helper, then inline again if you like (you usually keep it).
- Temporal coupling: `foo.a()` must always precede `foo.b()`. Create `ab()` that calls both.

Do not hunt down every other place the helper could be used; that is a separate tidying. New helpers tend to be wanted again within minutes; interfaces become tools for thinking.

## 13. One pile

Prompt: code split into many small pieces in a way that stops you understanding it. Symptoms: long repeated argument lists, repeated code (especially repeated conditionals), poorly named helpers, shared mutable data structures.

Move: inline as much as needed until it is one big pile, read it until the shape appears ("first we calculate this, then we use it for that"), then extract new, better pieces. Feels backwards given the bias toward small pieces, and is strangely satisfying. Then ask: tidy more, or just make the change I can now see?

## 14. Explaining comments

Prompt: the moment of "oh, so that is what is going on".

Move: record only what is not obvious from the code. Write for a specific reader, or yourself fifteen minutes ago: "complicated by the need to minimise network calls". Explain domain context the team does not share. Add a header comment to a file that has none, saying why a reader might want this file. When you find a defect caused by hidden coupling, comment the coupling immediately; eliminating it can wait, burying it cannot.

## 15. Delete redundant comments

Prompt: a comment that says exactly what the code says.

```
getX()
  # return X
  return X
```

Move: delete it. Prose has no mechanism for staying accurate as code changes. A comment is often made redundant by the previous tidying: before a guard clause, "# no generator, return the default" at the end of a long else branch re-anchored the reader; after the guard clause it merely restates the code. Delete only the absolutely redundant, and tidy with an eye to making comments redundant.
