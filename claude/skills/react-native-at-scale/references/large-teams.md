# Large engineering teams

Each section: the challenge, what React Native and Expo give you, what they do not solve, and how to apply it. Written against Expo SDK 58 and React Native 0.88 (New Architecture only).

## Planning and decision making

**The challenge.** A handful of engineers can just build, but a larger team needs a more formal process to avoid clashes and keep architecture consistent. Lightweight design docs or RFCs help, ideally alongside a product requirements document, because unclear requirements and scope creep cause most delays. iOS and Android teams that plan together build the same thing, learn each other's platform and can standardise feature flags, analytics event names and even code structure, yet many work in silos. Thorough planning can turn into decision paralysis, so planning should be timeboxed, and on mobile a prototype often beats more whiteboarding. Teams also worry about noise when sharing plans widely, though broadcasting plans to all mobile engineers tends to catch problems early and spread knowledge. The suggested start: a design doc template per stack, buy-in from most engineers, short docs sent to everyone with named approvers, over-communication through light tooling, and iteration based on how it goes.

### What React Native gives you

- **One plan per feature.** Both apps come from one codebase, so there is one design doc, one pull request, one feature flag and one set of analytics event names. The iOS and Android silo mostly disappears by construction.
- **Cross-platform review by default.** Every reviewer reads the same TypeScript, so a mismatch in business logic between platforms cannot exist unless someone adds a `Platform.OS` branch.
- **Cheap prototypes.** A development build plus EAS Update previews lets a team put a working prototype in stakeholders' hands within a timebox, which is the remedy for decision paralysis.
- **The silo moves.** The remaining split is JS versus native code, and it is much smaller: only native modules and platform-specific UI need platform specialists in the plan.

### What it does not solve

- **The planning process itself.** Design docs, PRDs, approvers and timeboxes are still yours to introduce. One codebase removes the coordination between platforms, not the need to plan.
- **Native expertise.** Decisions about permissions, background work, store rules and native dependencies still need people who know each platform; include them as named reviewers.
- **Web and backend alignment.** Shared naming for flags and events across mobile, web and backend still needs agreement beyond the mobile team.

### How to apply it

1. Create a short mobile design doc template with sections for platform differences, native dependencies, flags and analytics events.
2. Send intent and review notices to one channel that all mobile engineers follow, and name the required approvers on each doc.
3. Timebox planning, and use a development build or EAS Update preview to settle open questions with a prototype.
4. Require any `Platform.OS` branch or new native dependency to be called out in the doc, since that is where the two platforms diverge again.

---

## Architecting ways to avoid stepping on each other's toes

**The challenge.** With a small team the choice of architecture barely matters: any testable pattern (MVC, MVP, MVVM, VIPER) will do. Trouble starts when many engineers keep editing the same files, typically one busy screen, and break each other's work; splitting that screen into smaller components only moves the conflict into component communication and navigation. At scale, architecture becomes the tool that controls how isolated teams and components are from each other while the codebase grows. If a known pattern stops working, the team should write down what would work, why and at what cost. The approach can be formalised as a verbal agreement (fast, but open to interpretation and invisible to new joiners), as documentation (fine for smaller teams, enforced by each engineer and reviewer), or as tooling: templates and code generators that wire components up correctly, and lint rules that catch architecture violations. The principles needed for hundreds of engineers are feature isolation, a monorepo-like structure, strong code and feature ownership, and automated tests that catch breakage before merge, so that engineers can merge without fear of breaking other parts of the app.

### What React Native gives you

- **One codebase, so one architecture.** There is no separate iOS and Android pattern to keep aligned; the conflict surface is one set of TypeScript files instead of two parallel ones.
- **File-based routing that removes the central navigator.** In Expo Router every screen is its own file under `app/`, and route groups such as `(checkout)` or `(account)` with their own `_layout.tsx` give a team a folder it owns. Adding a screen no longer means editing a shared navigation file.
- **Packages as feature boundaries.** npm, pnpm, Yarn and Bun workspaces work with Expo without manual Metro configuration from SDK 52, so features can live in `packages/*` with an explicit public entry point instead of reaching into each other's folders.
- **Architecture rules as lint.** ESLint's `no-restricted-imports`, `eslint-plugin-boundaries` or dependency-cruiser can fail the build when, for example, a feature package imports another feature's internals or a UI component calls the API layer directly. `npx expo lint` sets up ESLint with flat config.
- **Generators for the boring wiring.** `npx create-expo-module@latest --local` scaffolds a native module in `modules/` with Swift, Kotlin and TypeScript already connected; plop or Nx generators can do the same for a feature package or screen.
- **Pre-merge tests on the same stack.** `jest-expo` with React Native Testing Library for units and components, and Maestro flows (runnable as a `maestro` job in EAS Workflows) for end-to-end checks.

### What it does not solve

- **Choosing the architecture.** React gives you components and hooks, not a module structure. Where state lives, how features talk to each other and what the dependency direction is remain decisions the team must write down.
- **Shared hot spots.** The root `_layout.tsx`, the global store, the theme and `app.config.ts` become the new files everyone touches. They need owners and a small surface.
- **Native code conflicts.** `ios/` and `android/` changes, config plugins and native dependencies still collide; Continuous Native Generation (`npx expo prebuild`) helps by regenerating the native folders from config instead of hand-editing them.
- **Ownership and coverage.** CODEOWNERS, review rules and enough tests to merge with confidence are process, not framework.

### How to apply it

1. Write the architecture down: folder layout, allowed dependency directions and where server, UI and global state live.
2. Give each team a route group in `app/` and a workspace package for its logic, and map both in CODEOWNERS.
3. Turn the written rules into lint rules that fail CI, starting with "no imports from another feature's internals".
4. Add generators for new screens, feature packages and native modules so new code starts in the agreed shape.
5. Gate merges on Jest and a small set of Maestro flows covering each team's critical path.

---

## Shared architecture across several apps

**The challenge.** A company with several apps usually starts each one with its own architecture, built by different teams moving fast. Once platform teams own shared pieces such as experimentation, feature flags and performance, a unified architecture is proposed, but getting there can mean rewriting much of each app: to prove the benefit you would already need to be on it. The sensible middle ground is to move towards it without a rewrite: agree on shared vocabulary for screens, navigation, modals and flows; plan the same feature for both platforms in one lightweight design document; get teams on different apps talking, for example through cross-team planning reviews; share one component or library at a time, built in the unified style; and use the new approach only for new parts of the app, the way Swift was introduced into Objective-C codebases. Migrating architecture is expensive and most teams are right to decline a full move. A rewrite is justified only when major changes will touch most of the codebase anyway, and even then it takes longer and hurts more than planned. An adapter that lets components built the new way run inside apps on the old architecture is a pragmatic way to share without rewriting.

### What React Native gives you

- **iOS and Android unification for free.** Within one app there is one implementation, so shared vocabulary and shared planning across the two platforms are the default, not a goal.
- **Shared packages across apps in one monorepo.** Expo supports workspaces with Bun, npm, pnpm and Yarn, configures Metro automatically from SDK 52 and supports isolated installs (pnpm's default) from SDK 54. A design system, API client, analytics wrapper or auth package can be consumed by every app as `"workspace:*"`.
- **New code in old apps without a rewrite.** `expo-brownfield` adds React Native screens to an existing native app, either integrated into the native project or isolated as an AAR and XCFramework that native teams consume like any other dependency, with a message API (`sendMessage`, `addMessageListener`) between native and React Native. This is the "new architecture only in new parts" route.
- **Many apps from one codebase.** `app.config.ts` can produce variants (bundle identifier, name, icons) from an environment variable such as `APP_VARIANT`, which suits white-label or regional apps that differ mostly in configuration.

### What it does not solve

- **Lockstep upgrades.** Expo's monorepo guide states that duplicate React Native versions in one monorepo are not supported, so every app in it moves to a new React Native and Expo SDK together. That is real coordination cost.
- **Brownfield maturity.** Expo marks integration into existing native projects as alpha, and not every Expo tool works there (the development client does not).
- **Migration economics.** Deciding which apps move, in what order, and whether a rewrite is justified is unchanged. React Native removes the iOS versus Android split, not the cost of rewriting an existing app.
- **Native-only apps in the estate.** Sharing with apps that stay fully native still needs native libraries or a bridge layer.

### How to apply it

1. Put the apps in one workspace monorepo and extract one shared package first, ideally a low-risk one such as analytics or the design tokens.
2. Agree the shared vocabulary (screen, flow, modal, route group) and use it in every design doc.
3. Build new features in the target structure and leave existing screens alone unless they are being changed anyway.
4. For native apps, pilot one new screen through `expo-brownfield` before committing to more.
5. Plan React Native and Expo SDK upgrades as one estate-wide project per cycle.

---

## Tooling maturity for large engineering teams

**The challenge.** Apps built from millions of lines of code, with dozens of native engineers, outgrow standard native tooling, and there are few off-the-shelf answers. Build time is the biggest problem: a large project built many times a day by each of a hundred or more engineers, plus a full automated test run, easily justifies hiring people to do better than the available services. Choosing between Bazel, Buck, Gradle and xcodebuild and tuning the build is never finished, because build tooling keeps changing. The arithmetic is simple: shaving half a minute off a build for 50 engineers who build several times a day recovers months of engineering time a year, so a few weeks of one engineer's work and regular revisits pay off. Shipping more than a few apps is also hard: each app needs checkpoints from the build cut through localisation, manual, smoke and performance testing to beta users, and tracking dozens of build trains across iOS and Android usually ends in an internal release tool. Mobile tooling is maturing, but large mobile apps are still a less solved problem than large backend systems.

### What React Native gives you

- **Most edits skip the native build.** Metro bundles JavaScript and Fast Refresh applies changes in the running app, so the build-time maths applies mainly to native changes, not to everyday UI and logic work.
- **Faster native builds when they do happen.** Expo ships precompiled versions of its larger modules (Android since SDK 53, iOS by default from SDK 56). A build cache provider (`"buildCacheProvider": "eas"` with `eas-build-cache-provider`) lets `npx expo run:ios` and `run:android` download a build whose fingerprint matches instead of compiling.
- **Hosted build and release infrastructure.** EAS Build, EAS Submit and EAS Update cover signing, store upload and over-the-air releases. EAS Workflows chains `build`, `submit`, `testflight`, `maestro`, `fingerprint` and `update` jobs, and supports `on.schedule.cron` (paid plans), which is enough to cut a weekly release candidate automatically.
- **Mature JavaScript tooling.** TypeScript, ESLint, Jest and React Native DevTools (console, breakpoints, network, performance and memory panels, React components and profiler) are the same tools web teams already run at scale.

### What it does not solve

- **Native build systems.** React Native still builds with Gradle and Xcode with CocoaPods. There is no first-party Bazel or Buck support, so a team that needs those owns the integration.
- **Multi-app release orchestration.** EAS automates the steps, but a release train dashboard with sign-offs per stage (localisation, manual QA, performance, beta) across many apps is still something you build or assemble.
- **Two toolchains instead of one.** Engineers now need Metro, Node and the JavaScript tools on top of Xcode and Android Studio, and someone must keep both healthy.
- **Cost.** Hosted builds and scheduled workflows are paid; at high volume compare them with self-hosted runners (`eas build --local` exists but drops caching and secret variables).

### How to apply it

1. Measure build counts and durations per engineer, for both JavaScript-only and native changes, before buying or building anything.
2. Turn on the build cache provider and confirm precompiled modules are in use, then measure again.
3. Model the release train as an EAS Workflow on a schedule: cut, build, Maestro smoke tests, TestFlight and internal track.
4. Keep the stage sign-offs (QA, localisation, performance) in one tracked place per release and per app.
5. Review build and release tooling every quarter, with a named owner.

---

## Scaling build and merge times

**The challenge.** Native build times become a problem quickly, Xcode's in particular, and neither Apple nor Google has prioritised build speed for projects with hundreds of thousands or millions of lines and dozens of dependencies. Tools exist but take effort to integrate and tune; Bazel is the most common destination for companies moving from Buck or Gradle, and even then there is a lot of work left, so larger teams dedicate engineers to the build. Some fixes are cheap, for example using static libraries instead of dynamic frameworks on iOS, which helps build time, app size and cold start. A bigger change is moving to a monorepo: teams of 20 to 40 engineers start to ask, because fetching dependencies from many repositories gets slower as the codebase grows, even with caching, and good monorepo tools for mobile were scarce. The trade-off is between short builds, standardised versions and low investment in custom tooling. Keeping the main branch green is the other half: with fast builds and few merges it is easy, but with a 30-minute pipeline and ten pull requests an hour, builds must run in parallel and a submit queue that predicts which changes will pass becomes worth building, to keep merge time and feedback loops short.

### What React Native gives you

- **A cheap inner loop.** JavaScript changes go through Metro and Fast Refresh; only native changes need Gradle or Xcode.
- **Static linking by default.** Expo's iOS builds link Pods as static libraries unless you set `useFrameworks` in `expo-build-properties`, so that cheap build-time win is already the default.
- **Native caching.** Precompiled Expo modules, the remote build cache keyed on the project fingerprint, and on EAS Build an npm cache server, a Maven cache server, ccache (`EAS_USE_CACHE=1`, or `eas/restore_cache` and `eas/save_cache` in workflows) and a custom `cache` field in `eas.json`.
- **Skip native builds in CI when nothing native changed.** A `fingerprint` job in EAS Workflows decides whether a change needs a new binary or only an EAS Update; JavaScript-only pull requests can then be verified with an update preview instead of a fresh build.
- **Monorepo support.** Workspaces are first class in Expo, and JavaScript-side tools such as Turborepo or Nx can cache lint, type-check and test results so a pull request only reruns what it affects.

### What it does not solve

- **Native compile time itself.** Large native modules or many native dependencies still make clean builds slow, and the build system is still Gradle and CocoaPods.
- **One React Native version per monorepo.** Expo does not support duplicate React Native versions in a monorepo, so upgrades block every app at once.
- **Keeping main green.** Parallel CI, test sharding (`jest --shard`) and a merge queue (for example GitHub's merge queue) are yours to set up; there is no React Native specific submit queue.
- **Flaky end-to-end tests.** Maestro suites slow merges if they grow unchecked; keep the pre-merge set small.

### How to apply it

1. Split CI into a fast JavaScript path (type-check, lint, Jest with sharding) and a native path that runs only when the fingerprint changes.
2. Enable the remote build cache and EAS caching, then track native build time per week.
3. Keep native dependencies few and justified, since each adds compile time to every native build.
4. Use a merge queue once merges per hour make main-branch breakage common.
5. Hold the pre-merge Maestro suite to a time budget and move the rest to nightly runs.

---

## Mobile platform libraries and teams

**The challenge.** As mobile headcount grows, teams reinvent the same things: one builds its own logging, analytics or storage, and the next either copies or builds again. Internal libraries appear early, often as thin wrappers over a vendor so it can be swapped later, covering logging, analytics, persistence, flags and experimentation, networking and auth, testing and mocks, brand UI and themes, layout frameworks, message display, animation, images, navigation, architecture frameworks, performance tooling, push, and domain pieces such as calling, PDFs, scanning, location and maps. Maintenance is the real cost, found years later: the original authors leave and changes go in unchecked, short-term fixes erode quality, and product teams that own libraries have no time for upkeep or migrations. Platform teams, usually formed at around 20 to 30 mobile engineers, take over areas such as build infrastructure, store release management, developer tooling and experience, architecture and its governance, SDKs, reliability and performance, capabilities the market does not provide (custom UI testing, device labs, build trains), and shared libraries. A healthy platform team has a specific mission, measurable goals, enough people to do product work on the platform as well as support, a clear contract on what it owns, known support channels and a clear process for requests. Starting too late leaves duplication and poor abstractions; starting too early is hard to justify and pulls the strongest product engineers away.

### What React Native gives you

- **Much of the library list already exists.** The Expo SDK and ecosystem cover a large share: `expo-image` for images, Expo Router for navigation, Reanimated for animation, `expo-notifications` for push, `expo-sqlite` or `react-native-mmkv` for persistence, `expo-secure-store` for tokens, `expo-location`, `expo-camera` and `react-native-maps` for domain features, `@sentry/react-native` for crashes and performance, and `jest-expo` with React Native Testing Library for tests. Your libraries can be thin wrappers over these.
- **One library per concern, not two.** A shared analytics or logging package is written once in TypeScript and serves both platforms, which halves the maintenance.
- **A clear route for native capabilities.** When nothing exists, the Expo Modules API (Swift and Kotlin) or Turbo Modules (when C++ is involved) give the platform team a standard way to wrap a vendor SDK, including `.aar` and `vendored_frameworks` dependencies.
- **Library health signals.** `npx expo-doctor` checks dependencies against the React Native Directory and the installed SDK.

### What it does not solve

- **Ownership.** Shared packages in a monorepo decay unless a team owns them, reviews changes and plans migrations.
- **A new standing duty: upgrades.** Expo ships three SDKs a year, and React Native, Reanimated and other core libraries move with it. Somebody has to run those upgrades across every app, and that work belongs on the platform team's roadmap.
- **Native skills.** A React Native platform team still needs engineers who can debug Gradle, CocoaPods, Xcode and native crashes.
- **When to form the team.** The timing trade-off is the same; React Native only shrinks the team needed, since one group covers both platforms.

### How to apply it

1. List the internal libraries you need and mark which are a thin wrapper over an Expo or community package, and which must be built.
2. Give every shared package a named owning team, a README with its contract, and CODEOWNERS review.
3. Form the platform team with a written mission and goals such as crash-free sessions, build time and percentage of apps on the current SDK.
4. Put SDK upgrades, native module work and EAS configuration explicitly in its remit.
5. Publish a support channel, office hours and a request process that product teams can see and track.
