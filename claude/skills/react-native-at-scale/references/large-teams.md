# Part III: challenges from large engineering teams (chapters 19 to 24)

Lines marked **RN** are React Native applications, not the book's claims.

## 19. Planning and decision making

- Small teams just build; larger ones need lightweight process to avoid collisions. Some teams formalise with a handful of mobile engineers, others at about 30.
- Unclear requirements and scope creep cause much of the delay: a product spec is the go signal for engineering.
- Plan iOS and Android together: same flag names, analytics events and structure; cross-platform review catches business logic mistakes.
- Timebox decisions and go with the best option on the information available; on mobile tooling questions, prototype rather than whiteboard.
- Broadcast plans widely (an "intent to write a design doc", then the doc, to a mobile-wide list): it surfaces problems early and spreads knowledge. Silos are the bigger risk than noise.
- Starting a design doc process: a template per stack, buy-in from most engineers, short docs with named approvers, lightweight tooling, iterate.
- **RN:** one codebase removes much divergence, but docs still need to cover native modules, permissions and store implications per platform.

## 20. Architecture that keeps teams apart

- Small team: any testable pattern works (MVC, MVP, MVVM, VIPER). Trouble starts when many engineers edit the same files; a hot screen touched by dozens of engineers breaks constantly.
- At scale, architecture is the mechanism for isolating teams and components. Keep a known pattern if it works; otherwise write down candidates and trade-offs.
- Formalise in increasing strength: verbal agreement, written docs, then tooling (generators that scaffold correctly wired components, lint rules that fail on boundary violations).
- Principles for hundreds of engineers: feature isolation, monorepo-like structure, strong ownership, automated tests guarding every feature before merge.
- Change architecture when merge conflicts and cross-team breakage on shared files are routine, not before.
- **RN:** feature folders or workspace packages, CODEOWNERS, ESLint boundary rules (`no-restricted-imports` or a boundaries plugin), plop or hygen generators for screens and modules, required CI checks.

## 21. Shared architecture across several apps

- Unifying architectures across apps usually means a rewrite whose benefit cannot be proven up front.
- Go incremental: shared vocabulary for screens, flows and navigation; one design doc per feature covering both platforms; share one component at a time; new architecture on new screens only; adapters so new-style components plug into old apps.
- Rewrite only when a major change (such as a redesign) will touch most of the codebase anyway.

## 22. Tooling maturity

- Off-the-shelf tooling hits limits with millions of lines and dozens of engineers.
- Build time is the top problem. Do the maths: engineers times builds per day times seconds saved. At 50 engineers building 5 times a day, 30 seconds saved recovers months of engineer time a year.
- Build system choice and multi-app release orchestration become ongoing workstreams; budget headcount for them.

## 23. Build and merge times

- Bazel is the common destination at very large scale; tuning never ends.
- iOS: static libraries instead of dynamic frameworks improve build time, size and cold start.
- Monorepo: the question appears at 20 to 40 engineers when fetching dependencies gets slow. Trade-off: speed and uniform versions versus custom tooling and platform cost.
- Keeping main green with long pipelines and many PRs per hour needs a merge queue that builds changes in parallel.
- **RN:** Metro, Gradle and Xcode caching, ccache, prebuilt native modules, EAS build caching, GitHub merge queue once main goes red regularly.

## 24. Mobile platform libraries and teams

- Teams reinvent logging, analytics, storage, networking, flags, design system, navigation and so on. Shared libraries emerge, often thin wrappers so a vendor can be swapped.
- Failure modes: authors leave and changes go in unchecked; quick fixes pile up because no owner can say no; the owning product team has no time for maintenance.
- Platform teams usually form at 20 to 30 mobile engineers. Typical remit: build infrastructure, release management, developer experience, architecture governance, reliability and performance, shared libraries.
- A healthy platform team has a specific mission, measurable goals (reliability, adoption), staff for roadmap work beyond support, a contract on what it owns, clear support channels and a request intake process.
- Too late means duplication and no architecture owner; too early pulls the strongest product engineers away without a business case. Do not copy another company's structure.
- **RN:** the platform remit also covers native module upgrades, RN and Expo SDK upgrades, the JS to native boundary and the shared design system package.
