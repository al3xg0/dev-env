---
name: self-review
description: Self-review the full diff before pushing or opening a PR, so a human reviewer or PR bot never finds what a careful read would have caught. Use whenever about to push a branch, open or update a PR, or declare implementation work done. Covers a reuse/prior-art pass (search for existing helpers before adding any new function, type, or inlined snippet), a correctness pass over the whole diff, running the code against real dependencies, and consistency with the codebase's existing invariants and idioms.
---

# Self-review before pushing

Review your own diff the way the strictest reviewer on the team would, before anyone else sees it. Reacting to bot or reviewer comments one round at a time is not acceptable; each round trip is a red PR and a wasted review cycle. Everything below happens before `git push`.

## 1. Prior art / reuse pass

For every function, method, type, constant, or inlined snippet the diff adds, check whether the codebase already has it. Do this even when the new code follows an inline precedent in the file you touched: nearby code that predates a shared helper is not evidence the helper doesn't exist.

- Search shared code first (`lib/`, `libs/`, `pkg/`, `util/`, `common/`, internal shared modules, the org's shared packages), then the rest of the repo.
- Search by behaviour, not just by name: grep for the distinctive expression (a formula, a regex, a magic constant) as well as likely names for the operation (`Mask`, `Sanitize`, `Normalize`, `Format`, ...).
- If a helper exists, use it. If a near-miss exists, prefer extending it over adding a parallel one, and say so in the PR.
- Same rule for test code: look for existing fixtures, builders, and assertion helpers before writing new ones.

Typical failure this catches: hand-rolling a one-line masking/formatting expression that an existing sanitize/format helper in the shared library already provides, because the surrounding file inlined it years ago.

## 2. Read the whole diff

`git diff` end to end, every round, not just the lines the last change or comment touched. For each hunk ask:

- What breaks under concurrency, legacy/old-shape data, and transient dependency errors (dependency down, retry, partial write)?
- Does new code respect invariants the codebase already enforces (canonical ID formats, soft-delete rules, dual-written fields staying in sync)?
- Is anything left over from an earlier iteration: dead code, stale comments, debug output, a name that no longer fits?
- Would a reviewer ask "why?" anywhere the code doesn't answer it? (The answer belongs in the PR body, not comment noise.)

## 3. Run it for real

Green lint is not evidence the code works.

- Run the build, formatter, linter, and the tests covering the change, with whatever the repo defines for those.
- Exercise the change against a real dependency, not only mocks (a real database via a local instance or testcontainers, the actual screen or endpoint for anything user-facing). Prove the behaviour rather than assuming it.
- Prove a new regression test is real: revert the fix, watch the test fail, restore.
- Report gaps honestly. Never present a skipped step as done.

## 4. Know when to stop patching

When a third issue turns up in the same component (yours or a reviewer's), stop patching and reconsider the design. Repeated rounds of small patches on the same code usually mean the approach is wrong, and one structural change (for example, replacing a best-effort check-then-write sweep with a transactional write) can make the whole bug class impossible.

## Pre-push checklist

1. Reuse pass done: nothing in the diff reimplements an existing helper.
2. Full diff read against the questions in section 2.
3. Build, lint, tests green; behaviour exercised against a real dependency.
4. Diff contains only what the task asked for: no adjacent refactors, no leftovers.
5. Commit messages and the PR description follow the project's conventions; no AI attribution anywhere.
