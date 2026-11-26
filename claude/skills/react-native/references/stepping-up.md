# Stepping up: experiments, quality and operations

Each section: the challenge, what React Native and Expo give you, what they do not solve, and how to apply it. Written against Expo SDK 58 and React Native 0.88 (New Architecture only).

## Experimentation

**The challenge.** Apps that earn real money A/B test even small changes, to measure their effect and to catch changes that quietly hurt revenue. A feature flag is only the first piece: a full system also needs staged rollout, user bucketing, result analysis, regression detection and analysis after the experiment ends. With a handful of experiments this is easy; with hundreds running at once across regions and audiences, experiments start to affect each other. Large companies often build in-house because their needs are unusual, their data sources are internal, the system must serve many teams, the data stays theirs and fast experimentation is a competitive edge; others move to a vendor to cut cost or standardise. Small and mid-sized teams usually buy (remote config and flag vendors, plus a product analytics tool). The harder half is process: knowing which experiments are live, stopping them colliding, and deciding who owns them. Some teams run every change, bug fixes included, as a reversible experiment with guardrail metrics, because a fix can still lower conversion. Product managers or data scientists usually own the design and bucketing; engineers implement.

### What React Native gives you

- **One implementation per experiment.** Both platforms run the same JavaScript, so a variant, its exposure event and its metrics are written once. The usual drift where the iOS and Android variants behave or log slightly differently mostly disappears.
- **Vendor SDKs that work with Expo.** The Expo docs list PostHog (`posthog-react-native`), Statsig (`@statsig/expo-bindings`), LaunchDarkly (`@launchdarkly/react-native-client-sdk`) and Firebase Remote Config (`@react-native-firebase/remote-config`, which pairs with Firebase A/B Testing). Analytics tools such as Amplitude cover the deeper analysis.
- **Variant code can ship over the air.** Within a runtime version, EAS Update delivers new JavaScript without a store release, so a variant can be added or a losing one removed in days rather than a release cycle.
- **Percentage rollouts of an update.** `eas update --rollout-percentage=10`, then `eas update:edit` to widen it, gives a gradual rollout of a whole update. It is not an A/B test: there is no sticky assignment per user and no built-in analysis.

### What it does not solve

- **Statistics and assignment.** Bucketing, exposure logging, significance, guardrail metrics and interaction between experiments come from your vendor or data team, not from React Native.
- **First-launch flicker.** Flags arrive over the network, so the first render can show the wrong variant. Ship defaults in code, let the SDK cache the last values, and decide per experiment whether to wait for a fetch or use the cached assignment.
- **Native-only variants.** A change that needs new native code still waits for a store build, and only users on that build can enter the experiment.
- **Process and ownership.** A register of live experiments, a regular sync between product and data, and a named owner per experiment are yours to set up.

### How to apply it

1. Buy before building: pick a vendor with an Expo-compatible SDK unless you have a concrete need it cannot meet.
2. Wrap flag and experiment reads in one module so exposure is logged in a single place, with the same event names on both platforms.
3. Run risky changes, fixes included, as experiments with explicit guardrail metrics such as sign-up or payment success.
4. Keep a shared list of live experiments with owner, audience and end date, and check it before launching a new one.

---

## Feature flag hell

**The challenge.** Flags enable experiments, gradual rollouts and regional launches, but their cost grows with the number of flags, the team and the app. Flags can depend on each other: a sub-feature rolled out to half of its audience reaches far fewer people than expected when its parent feature is only partly rolled out. Flags can conflict: two teams each test their own flag in isolation, and the app breaks when both are on together. Stale flags pile up as dead branches that hurt readability, maintenance and slightly the binary size, and on mobile deleting them is risky because a mistake cannot simply be redeployed away. Automated clean-up (generating a pull request that removes a fully rolled-out flag and its dead branch) works well, but only when flag code follows one consistent pattern, ideally enforced by a linter or a shared library. Building your own flag system is a large job, mostly on the server side, and only worth it with a clear business case; a thin facade over vendor flags lets you switch or fall back between providers.

### What React Native gives you

- **One codebase to clean.** A flag lives in one JavaScript code path instead of two native ones, so dependency mapping and removal happen once.
- **Types as a flag registry.** Declare every flag in one TypeScript module (a union of names, a typed default for each) behind your own facade over the vendor SDK. Removing a key then turns every leftover read into a compile error from `tsc --noEmit`.
- **Lint-enforced access.** ESLint's `no-restricted-imports` can forbid importing the vendor SDK anywhere except the facade, which is the consistent pattern automated clean-up needs.
- **Automated removal works on TypeScript.** Uber's Polyglot Piranha supports `ts` and `tsx`, so the generate-a-removal-PR approach is available to React Native code.
- **Clean-up can ship over the air.** Removing a dead branch is a JavaScript change, so EAS Update can deliver it to every build on a compatible runtime version, not only to users who install a new binary.

### What it does not solve

- **Old binaries still read the flag.** Users on older store builds or older runtime versions keep evaluating it. Leave the flag served at its final value in the vendor until those versions are retired (see Forced upgrading).
- **Dependencies and conflicts.** Nothing detects that two flags break each other when both are on. Rollout plans have to record parent and child flags, and tests have to cover the combinations that matter.
- **Native flags.** Flags read in Swift or Kotlin code (custom modules, native SDK configuration) sit outside your TypeScript registry.

### How to apply it

1. Route every flag through one typed facade and block direct SDK imports with a lint rule.
2. Give each flag an owner, a parent flag if it has one, and an expiry date; fail CI or open a ticket when a flag outlives it.
3. Once a flag is fully rolled out, remove it with a generated pull request (Polyglot Piranha or a codemod), and keep serving its final value until old versions are gone.
4. Before a rollout, list the other live flags on the same screens and test with them on.

---

## Performance

**The challenge.** Performance barely matters for small apps and matters a lot as the app and team grow; Google Play ranks poorly performing apps lower and users abandon slow ones. Typical problems at scale: startup time creeping up as teams each add one small task; too many parallel network calls, often solved by a platform team owning networking and prioritising requests; poor performance on slow or high-latency networks, where some teams adopt other protocols such as QUIC or MQTT; battery drain from wasted CPU, in the foreground and the background; ANRs from a blocked UI thread; slow and frozen frames; and janky animations on older devices, where profiling itself adds overhead. Teams usually measure per screen, and a slow screen is often a mix of client and backend causes. Manual profiling (Instruments, Android Studio Profiler) is a fine start but does not reflect real devices and usage; automated profiling needs a large UI test suite and stable devices, and still misses real-world conditions. Sampling real-world measurements, on beta users and a small slice of production, scales best. Worth tracking: startup time, screen load latency, network latency, parallelism and error rates per endpoint, memory, local storage size and UI frame metrics, read at p95 and later p99. Production monitoring alone reacts too late on mobile because rollbacks are slow, so pair it with automated performance tests in CI. Simulating slow networks for the whole team (throttled days, dropped requests, injected latency) builds awareness.

### What React Native gives you

- **A fast baseline.** Hermes is the default engine and compiles JavaScript to bytecode at build time for faster startup; the New Architecture is the only architecture. FlashList v2 and `expo-image` cover the most common list and image problems.
- **Development profiling in one tool.** React Native DevTools has a Performance panel (from RN 0.83) showing JavaScript execution, React tracks, network events and your own `performance.mark` / `performance.measure` timings on one timeline, plus a React Profiler, Memory and Network panels. The Perf Monitor shows JS and UI frame rates separately. Measure in release builds only (`npx expo run:android --variant release`, `npx expo run:ios --configuration Release`).
- **Production sampling.** EAS Observe (`expo-observe`) records cold and warm launch, time to first render, time to interactive, bundle load time and per-route timings from real sessions, compared across store releases and OTA updates. Sentry React Native, with `tracesSampleRate` and `Sentry.wrap`, measures app start, slow and frozen frames and JS stalls, and reports iOS app hangs and Android ANRs. `@react-native-firebase/perf` is another option.
- **Render regressions in CI.** Reassure (Callstack) measures component render counts and durations in Jest and compares them against the base branch, which is far cheaper than device-based performance tests.
- **Request discipline.** TanStack Query de-duplicates identical requests, caches and retries, which tames the many-components-fetching-at-once problem without a custom networking layer.

### What it does not solve

- **A busy JS thread.** All JavaScript runs on one thread. Heavy work at module scope or during startup, large re-renders and synchronous parsing still cause jank and slow launches; React Native only moves the bottleneck.
- **Native profiling.** Battery, native memory, image decoding and UI thread work still need Instruments and Android Studio Profiler (or Perfetto). There is no React Native tool for battery use.
- **Network protocols.** There is no first-party QUIC or MQTT transport; that means a native module or a third-party library.
- **Slow-network simulation.** The DevTools Network panel does not throttle. Use the Android emulator's network settings, Network Link Conditioner on iOS, or a test-only fetch wrapper that adds latency and drops requests.
- **Budgets and ownership.** Someone still has to own startup time, set p95 targets and block regressions.

### How to apply it

1. Instrument production from the first release (EAS Observe or Sentry tracing at a low sample rate) and watch p95 startup and screen times per release and per update, split by device class.
2. Add `performance.mark` / `performance.measure` around startup and key screens, and review new startup work in code review.
3. Run Reassure in CI for critical screens, and profile release builds on a low-end Android device before each release.
4. Give one team ownership of startup time and the networking layer, and run the dev build on a throttled network regularly.

---

## Analytics, monitoring and alerting

**The challenge.** Backend teams alert on errors and page someone; mobile teams usually stop at crash reporting, while business monitoring comes as an afterthought. Mature teams detect when a critical flow regresses and investigate. First decide what to measure, then pick a tool: a free option such as Firebase Analytics, a vendor such as Amplitude or Mixpanel, or an in-house system for cost, custom features, internal data and ownership. A major pain is iOS and Android emitting different events for the same flow, which needs coordination with product and data science at planning time. Next, define the critical business events (for example the key payment actions and their errors) and monitor them across platforms, drillable by region or feature. Metrics are often wrong for months without anyone noticing, usually because each platform logs slightly differently, which misleads budget decisions; certifying metrics against a written spec, then verifying them through anomaly detection, comparison with related data and automated UI tests of the logging, catches most of it. For alerting, crash spikes are the common case; in-house crash grouping is harder than it looks. Rollout alerts on key health metrics, and anomaly alerts on business events, are rarer and noisy: usage is cyclical, differs by region and spikes with real-world events. Per-region, per-feature alerting brings cardinality and sparse-data problems that usually need in-house tooling.

### What React Native gives you

- **One event schema by construction.** The same JavaScript emits the same event, with the same properties, on iOS and Android. Define events as a typed catalogue (a TypeScript map from event name to payload) and the cross-platform matching problem shrinks to the few native-only paths.
- **Screen tracking from the router.** Expo Router always has a URL, so `usePathname()` and `useGlobalSearchParams()` in the root layout give screen views for every screen. From SDK 58 it also records `expo-router:page-focused` performance marks you can forward to analytics.
- **Analytics SDKs.** `@react-native-firebase/analytics`, Amplitude, Segment and PostHog (which also runs in Expo Go) all document React Native support; most need a development build.
- **Crash and release alerting.** Sentry (`@sentry/react-native`) groups JavaScript and native errors, symbolicates with source maps uploaded on EAS Build and through `npx sentry-expo-upload-sourcemaps dist` after `eas update`, and can tag events with `Updates.updateId` so a spike points at a specific update. EAS shows users and failed installs per update, and EAS Insights (`expo-insights`) shows usage by store version.

### What it does not solve

- **Deciding what matters.** Critical business events, their definitions and edge cases come from product and data science.
- **Proving the logging is right.** End-to-end tests cannot see analytics calls by default. Route events through your own wrapper with a test sink, then assert on the events a Maestro flow produced.
- **Business alerting.** Anomaly detection, seasonality, regional cardinality and noise tuning are backend and data work; no React Native library does them.
- **Web and backend parity.** If the same metric is also counted on the web or server, those implementations can still drift from the app.

### How to apply it

1. Write a spec for each critical business event and implement it once in a typed analytics wrapper.
2. Track screens from the root layout and tag crashes with app version and update ID.
3. Assert key events in E2E tests through a test sink, and add week-over-week anomaly checks on the certified metrics.
4. Alert on crash spikes per release first, then on a few business funnels with deliberately loose thresholds, adding regional detail only where it pays off.

---

## Mobile oncall

**The challenge.** Once alerts exist, someone has to be paged, and the obvious person is a mobile engineer with context. Large teams can run a mobile-only rotation (often an iOS and Android pair); most end up with a very small one because mobile on-call is quiet, though a rotation under about five people is fragile. A rotation is only the start: there must be an incident process (assess severity and impact, escalate, assign a lead, split communication and investigation) that people are trained in, and a postmortem habit that records context, timeline, impact, root cause and follow-up actions so the same failure does not recur. Merging mobile and backend rotations is tempting for small teams, but neither side knows what to do with the other's alerts. It only works when most alerts have short, simple runbooks; without them, on-call depends on a few experienced people and new joiners take longer to start.

### What React Native gives you

- **Faster mitigation for JavaScript faults.** A broken update can be undone in minutes: `eas update:rollback` (to the previous update or the embedded one), `eas update:republish --group <id>` to re-serve a known good update, `eas update:revert-update-rollout` during a staged rollout, and `eas channel:pause` to stop serving new updates. A forward fix ships with `eas update` without store review.
- **Flags as kill switches.** Remote flags (see Feature flag hell) turn off a failing feature for every build that reads them.
- **One codebase to know.** Most incidents live in shared TypeScript, so one engineer can cover both platforms, and backend or web engineers can read the stack traces. That makes merged rotations more realistic than with two native codebases.
- **Context in one place.** Sentry tagged with app version and update ID, plus the EAS deployments page, tells the on-call engineer which release or update a spike belongs to.

### What it does not solve

- **Native and store-bound failures.** A crash in native code, a broken native dependency or a bad binary still needs a store release, and users who already updated keep it until they update again.
- **Updates that cannot reach a build.** OTA mitigation only applies to builds with a matching runtime version and a working update check; a crash before the update loads defeats it.
- **The human process.** Rotations, escalation, training, runbooks and postmortems are unchanged.

### How to apply it

1. Write a runbook for each alert, starting with "bad OTA update" (pause or roll back, then fix forward) and "crash spike in a new binary" (halt the staged store rollout, flag off, hotfix).
2. Rehearse an update rollback on a staging channel so the commands are known before they are needed.
3. Keep at least five people on the rotation, mobile only or merged with backend once runbooks cover most alerts.
4. Run a blameless postmortem for every user-facing incident and share it beyond the team.

---

## Advanced code quality checks

**The challenge.** The shorter the feedback loop, the more productive the team, so feedback should arrive before code review. Productive teams set up formatting, linting and static analysis early. A formatter enforces the agreed style before a pull request. Linters range from indentation and naming to team-wide patterns and architecture rules (for example, a view may not call business logic directly). Many rules lead to lint fatigue, where warnings are ignored; failing the build on errors, or fixing them automatically, counters it. Static analysis catches deeper problems such as null access, unused variables or empty catch blocks, giving faster feedback, lighter reviews and more stable, secure apps, at the cost of integration and upkeep; good-enough tools beat custom ones. Code coverage, wired into CI, shows coverage per change, can enforce a minimum, tracks trends against incidents and highlights poorly tested areas.

### What React Native gives you

- **Lint and format out of the box.** `npx expo lint` sets up ESLint with `eslint-config-expo` in flat config (SDK 53 and later), and the Expo guide pairs it with Prettier. `eslint --fix` and Prettier fix most findings automatically.
- **The type checker as static analysis.** TypeScript in strict mode (`tsc --noEmit` in CI) catches null and undefined access, wrong props and dead parameters at compile time: the class of crash the native tools target.
- **Architecture rules in the same tool.** `no-restricted-imports` and `import/no-restricted-paths` (from `eslint-plugin-import`), or dependency-cruiser, encode layer and module boundaries, for example "screens may not import the API client directly".
- **Project health checks.** `npx expo-doctor` flags known configuration and dependency problems, and `npx expo install --check` reports packages that do not match the SDK.
- **Coverage from the test runner.** `jest --coverage` with the `jest-expo` preset produces coverage reports that services such as Codecov or SonarQube (which supports TypeScript) can show per pull request.

### What it does not solve

- **Native code.** Custom native modules and config plugins still need SwiftLint, ktlint or Android lint in their own CI steps.
- **Rules and their upkeep.** Choosing rules, keeping them current and upgrading the tools is ongoing work; a `--max-warnings 0` policy is what stops fatigue.
- **What types cannot see.** Data from the network or storage is untyped until validated; parse it at the boundary (for example with Zod) or the compiler's guarantees end there.

### How to apply it

1. Run Prettier, `npx expo lint --max-warnings 0` and `tsc --noEmit` in a pre-commit hook and in CI, failing on any error.
2. Turn the architecture rules your reviewers repeat into lint rules.
3. Report coverage per pull request and set a floor for new business logic, not a global target.
4. Add `npx expo-doctor` to CI, and lint native code separately if you have any.

---

## Compliance, privacy and security

**The challenge.** Most apps must meet compliance and privacy rules specific to their domain, usually worked out with an in-house or external compliance team, because violations cost money and reputation. Personal data must be reachable only by those who need it, not by engineers or support staff. GDPR widened what counts as personal data and requires a lawful purpose to store or process it. Industry rules may add PCI DSS, HIPAA or ISO 27001, FERPA, FCRA, US Section 508 and the European Accessibility Act, plus national privacy laws. Two areas affect nearly everyone with EU users. Logging: avoid logging personal data (or anonymise it), write guidance on what and how to log, audit logs, keep personal data out of bug report screenshots and ticketing tools, and review regularly. App audits: third-party SDKs are often not GDPR-compliant by default and may have to be reconfigured or dropped, flows may need consent steps and information screens, and network traffic should be inspected with a proxy such as mitmproxy or Charles to spot personal data leaving the app. Training a few engineers, or naming privacy and security champions, catches problems earlier; a full compliance review is a long project, and the earlier the better. For security, map likely vulnerabilities, train engineers (OWASP Mobile Top 10, MASVS) and scan in CI for hardcoded credentials and dangerous functions.

### What React Native gives you

- **Platform privacy declarations in config.** `ios.privacyManifests` in app config writes `PrivacyInfo.xcprivacy`, including required-reason APIs, tracking domains and collected data types. `expo-tracking-transparency` requests App Tracking Transparency permission.
- **Secure storage.** `expo-secure-store` uses the iOS Keychain and, on Android, SharedPreferences encrypted with a Keystore key. Mind the documented edges: iOS Keychain items can survive an uninstall, Android Auto Backup must exclude these entries, and `requireAuthentication` data is lost when biometrics change. For larger data, `react-native-mmkv` v4 takes an `encryptionKey`, and `expo-sqlite` can build with SQLCipher (`useSQLCipher`).
- **Screenshot protection.** `expo-screen-capture` provides `usePreventScreenCapture()` (FLAG_SECURE on Android, which also blanks the app switcher preview) and `enableAppSwitcherProtectionAsync()` on iOS for sensitive screens.
- **Scrubbing crash data.** Sentry offers `beforeSend`, `beforeBreadcrumb` and `sendDefaultPii` to strip personal data, and mobile session replay masks text, images and inputs by default (`Sentry.Mask` and `Sentry.Unmask` for exceptions).
- **Secrets handling.** EAS environment variables with secret visibility stay on EAS servers. `EXPO_PUBLIC_` variables, by contrast, are inlined into the bundle.

### What it does not solve

- **The JavaScript bundle is readable.** It ships inside the app and can be extracted, Hermes bytecode included. Never put API secrets in JS or `EXPO_PUBLIC_` variables; keep them on a server. Treat Expo Atlas files as source code too, since they contain inlined variables.
- **Every npm package is a dependency to audit.** Analytics, ads and attribution libraries bring native SDKs with their own data collection and privacy manifests; review their defaults like any third-party SDK.
- **Law and process.** Which regulations apply, consent design, Play data safety and App Store privacy answers, logging policy and retention are decisions for you and your legal and security experts.
- **Certificate pinning and jailbreak detection** are not built in; libraries such as `react-native-ssl-public-key-pinning` exist, but weigh the outage risk of a pinned key rotation.

### How to apply it

1. Keep a register of every SDK and what data it sends, and confirm it by proxying a release build through mitmproxy or Charles.
2. Route all logging and crash reporting through a wrapper that drops personal fields, and configure Sentry's `beforeSend`.
3. Store tokens in `expo-secure-store`, keep secrets off the client, and run a secret scanner (for example gitleaks or SonarCloud) in CI.
4. Name a privacy and security champion per team and train them on OWASP MASVS.

---

## Client-side data migrations

**The challenge.** Apps that store data locally face schema migrations, which backend and desktop engineers know well but web engineers rarely meet. Writing the migration function is the small part. The hard parts are testing it against realistic production data, especially from heavy users with complex local state; testing upgrades from many older versions, since users skip releases and some are more than one migration behind; logging and alerting on the device, because backend logs show nothing; and supporting users whose migration failed. The worst case is a bug that corrupts the new schema: there is no client-side rollback, so users may only recover by wiping the app. Where possible, make the backend the source of truth so the app can re-download data instead of migrating it.

### What React Native gives you

- **Versioned persisted stores.** Zustand's `persist` middleware takes a `version` and a `migrate(persistedState, version)` function, which runs before the store hydrates.
- **SQLite migrations.** `expo-sqlite` documents a migration step in `<SQLiteProvider onInit={migrateDbIfNeeded}>` that reads and bumps `PRAGMA user_version`. With Drizzle ORM, `drizzle-kit generate` produces SQL migrations that `useMigrations` (from `drizzle-orm/expo-sqlite/migrator`) applies on startup.
- **Logging from JavaScript.** Migration failures can be reported to Sentry or your analytics wrapper with the old and new versions attached.
- **Testable in Jest.** Migration functions are plain TypeScript, so fixtures captured from each released schema can be run through every upgrade path in unit tests.

### What it does not solve

- **OTA updates add a new failure mode.** An EAS Update can change the JavaScript that reads stored data without a new binary, and `eas update:rollback` can put older JavaScript back on data that newer code has already migrated. Migrations must be forward-only, and code must tolerate a schema newer than it expects.
- **Key-value stores have no schema.** AsyncStorage and MMKV need your own version key and migration code.
- **Recovery.** A reset-and-refetch path, user support and backups are yours to build.
- **Real-world data shapes.** Representative heavy-user data still has to be collected or synthesised.

### How to apply it

1. Prefer server-owned data: if the local copy can be rebuilt, ship "clear and re-download" instead of a migration.
2. Version every store (`persist` `version`, `PRAGMA user_version` or a version key), with forward-only migrations that tolerate unknown fields.
3. Keep a fixture per released schema and test every path to the latest in CI.
4. Wrap migrations in error handling that logs the failure and falls back to a reset, never to a crash loop.

---

## Forced upgrading

**The challenge.** Most mature apps can now force old versions to upgrade. The reasons: backend API versions cannot be retired otherwise; old versions need testing; support costs grow with every version in use, as users report bugs that are already fixed; the backend must stay backwards compatible and moves slower; severe bugs need a guaranteed fix; and old versions may carry security holes that cannot otherwise be closed. Common designs include a rolling window of supported versions, blocking play until upgrade, recommended versus mandatory upgrades, remotely configured windows, and soft and hard kill switches targeted by OS version, app version or device maker. The catch is that the mechanism must ship long before it is needed, because versions without it can never be forced, and it must be exercised in production so it is trusted when needed. Android offers an in-app update API; iOS needs a homegrown solution. Old phones that newer versions no longer support force a business decision: support old versions for years or drop those users with notice. It is a strategy agreed with product and business, not just a tool.

### What React Native gives you

- **Fewer forced upgrades.** EAS Update delivers JavaScript fixes to every build on a matching runtime version without the store, so many urgent fixes no longer need a binary. `Updates.checkForUpdateAsync()`, `fetchUpdateAsync()` and `reloadAsync()` (or the `useUpdates()` hook) let you apply an urgent update while the app is open.
- **Version data for the check.** `expo-application` exposes `nativeApplicationVersion` and `nativeBuildVersion` to send with each request or compare against a remote minimum.
- **Store prompts.** `sp-react-native-in-app-updates` uses Play Core in-app updates (flexible and immediate) on Android and an App Store lookup on iOS that sends the user to the store; `expo-in-app-updates` is a younger community alternative. Neither works in Expo Go.
- **A gate in the router.** A blocking "update required" screen fits naturally as a `Stack.Protected` guard or a root-layout check before the rest of the app renders.

### What it does not solve

- **Mandatory OTA updates.** The Expo docs state that `expo-updates` has no first-class support for critical or mandatory updates; you build that logic yourself.
- **Native changes and old runtimes.** A native fix, or a build on an older runtime version, still needs a store upgrade, so the forced-upgrade path is still required.
- **iOS in-app updating.** Apple has no equivalent of Play in-app updates; the best you can do is detect a newer version and open the App Store.
- **Dropped OS versions.** Each Expo SDK raises the minimum OS (SDK 58 needs Android 7 and iOS 16.4), so an SDK upgrade can strand users on older phones. Decide that before upgrading, not after.

### How to apply it

1. Ship the check in version 1.0: on launch and on foreground, compare the native version with a remotely configured minimum and recommended version.
2. Support both a soft prompt and a hard block, targetable by app version, OS version and platform.
3. Use EAS Update for JavaScript fixes, and the forced upgrade for native changes and runtime versions you want to retire.
4. Trigger a soft prompt in production regularly so you know the mechanism works, and agree the support window with product.

---

## App size

**The challenge.** Bigger apps get fewer downloads and are uninstalled sooner when storage runs low. Google's data links each few megabytes of APK size to lower install conversion, and size matters most to users in emerging markets; on iOS, downloads above a size threshold are restricted on cellular connections, which can hurt installs badly. Android App Bundles cut download size substantially compared with universal APKs. Some companies build a separate "lite" app for emerging markets, with features removed, heavy frameworks dropped, vector assets, a server-driven client and very small network payloads, at the cost of a dedicated team, backend work and less functionality. Ownership is the hard part with many teams, usually landing on a platform team that monitors size; forgotten assets (an image left over from an experiment) creep in without monitoring. Installed size also grows through caches and can drive uninstalls; Google Play reports it, Apple does not, so iOS needs manual checks.

### What React Native gives you

- **Small defaults.** EAS Build produces an Android App Bundle by default, from which Play serves per-device, per-ABI APKs. Expo's docs put a minimal React Native app at just under 4 MB to download from the App Store. Hermes precompiles JavaScript to bytecode.
- **Bundle analysis.** Expo Atlas (`EXPO_ATLAS=true npx expo export`, then `npx expo-atlas .expo/atlas.jsonl`, or Shift + M with `npx expo start`) shows which libraries make up the JavaScript bundle.
- **Android shrinking via config.** `expo-build-properties` sets `enableMinifyInReleaseBuilds` (R8), `enableShrinkResourcesInReleaseBuilds`, `gifEnabled` / `webpEnabled: false` when `expo-image` handles images, and `buildArchs` to limit ABIs.
- **Store-accurate numbers.** Play Console's App size page in Android vitals estimates download size; TestFlight's App File Sizes in App Store Connect lists download and install size per device.
- **Cache control.** `expo-image` exposes `Image.clearDiskCache()` and `cachePolicy`, which helps keep installed size in check.

### What it does not solve

- **The runtime baseline.** React Native and Hermes add native libraries a minimal native app does not carry, so a sub-5 MB "lite" app is hard to reach. There is no good React Native answer there; such apps are usually native.
- **Size budgets in CI.** Nothing built in fails a pull request that grows the app. Script it: compare `npx expo export` output or a bundletool size estimate of the AAB against the base branch.
- **Asset hygiene and ownership.** Images, fonts, videos and native SDKs still creep in; someone has to own the budget.
- **Installed size on iOS.** Caches, downloaded updates and local databases grow on the device, and Apple gives no reporting; test it yourself.

### How to apply it

1. Record download size per release from Play Console and TestFlight, and track the JS bundle with Expo Atlas.
2. Add a CI check that fails or warns when the bundle or AAB grows past a set amount.
3. Turn on R8 and resource shrinking, drop unused image decoders, and remove experiment assets with the experiment.
4. Cap caches and evict old data, and check installed size after a long session on both platforms.
