---
name: react-native-at-scale
description: >-
  Engineering practices for mobile apps with many users and many engineers, applied to React Native. Use when designing or reviewing anything hard to undo once shipped in a store binary, such as state and app lifecycle, offline and retries, deeplinks and push, old app versions, forced upgrades, OTA updates, crash reporting, accessibility, localisation, navigation architecture, testing strategy, CI/CD and release trains, third-party SDKs, in-app purchases, feature flags, performance, analytics and alerting, privacy and security, client-side data migrations, app size, or React Native versus native, Flutter or Kotlin Multiplatform. Also trigger on "can we just roll it back", "should this be behind a flag", "how do we drop old versions", "the app is slow on Android" or "build or buy". Pairs with react-native-fundamentals and react-native-production.
---

# Mobile apps at scale, for React Native

## The one idea behind all of it

A mobile release is a binary on users' phones. You cannot roll it back, users update late or never, and stores review what you ship. Every practice below exists because mistakes are hard to revert. Before shipping anything, ask: if this is wrong, how do we turn it off, and how long do old versions keep running it?

## Scale the process to the app

Small app, small team: simple is correct. Templates, libraries and shortcuts are fine. Adopt a practice when the pain it solves appears, not before. Rough thresholds:

| Signal | Adopt |
|---|---|
| First public release | Crash reporting, minimum-version check, kill-switch flags, version on every request |
| A few engineers on a complex app | Unit tests on business logic, code review, design docs for cross-cutting features |
| Merge conflicts on shared screens | Feature isolation, lint-enforced boundaries, generators, CODEOWNERS |
| 20 to 30 mobile engineers | A platform team, build-time investment, monorepo question |
| A 1% drop in a key metric is very costly | Experiment on every change, business-metric alerting, on-call |

## Rules that apply from day one

1. **Ship escape hatches in v1.** A minimum-supported-version check with soft and hard thresholds (separate thresholds for binary and OTA bundle), a remote kill switch for risky features and every third-party SDK, and crash reporting. You cannot add a force-upgrade to a version that already shipped without one.
2. **Assume old versions live for years.** Never remove or reshape a field an old client reads until version analytics show it is gone. Clients tolerate unknown fields and enum values. Add endpoints rather than changing them. Send app version, build and OTA bundle id on every request.
3. **OTA updates fix JS, not native code.** Gate every update by runtime version so a bundle needing a new native module never reaches a binary without it. Keep updates to fixes within store rules.
4. **Treat state as event-driven and killable.** Events arrive in any order and the OS kills backgrounded apps. Keep state isolated and immutable, give global device state (connectivity, permissions, `AppState`) one owner, and persist what is needed to restore the user.
5. **Design deeplinks with navigation, not after.** One route map shared by navigation and linking, ids in params, cold and warm start handled, links arriving before auth or data handled, old links kept working. Push payloads are deeplinks with a message: same rules, and never make a core flow depend on a push arriving.
6. **Offline is a product decision.** Choose which flows work offline, treat very slow as offline, de-duplicate in-flight submits, and give every retryable state-changing request a persisted idempotency key (payments above all). Do not trust the "connected" flag alone.
7. **Server is the source of truth.** Prefer re-downloading over migrating local data. Version every persisted store, chain migrations from every historic version, log failures, keep a reset-and-resync escape hatch.
8. **Accessibility and localisation are cheap only at the start.** Labels and roles on every interactive element as it is written, font scaling left on, layouts tested at the largest text size and with a pseudo-locale, no concatenated translations, money formatted in one place (or by the server), RTL considered.
9. **Validate purchases on the server.** Entitlements come from the backend, product ids from the backend, store notifications persisted before processing. With more than one store, use a service such as RevenueCat unless IAP is core to the business.
10. **Every dependency is a risk.** Before adding one: size, maintenance, responsiveness, New Architecture support, whether it will block an RN, Xcode or Gradle upgrade. Initialise SDKs defensively and behind a flag.
11. **Never log PII; never ship secrets in the bundle.** Tokens in `expo-secure-store` (iOS Keychain, Keystore-encrypted storage on Android), never AsyncStorage. Scrub crash breadcrumbs, analytics and bug report screenshots. Inspect real traffic with a proxy to see what SDKs send.
12. **Measure what users feel.** Crash-free sessions (world-class is 99.99%), cold start to interactive, screen load at p95, dropped frames on the JS and UI threads, app size per PR. Profile release builds on a low-end Android device; dev builds lie.

## Decisions that need a design doc

Write a short doc, reviewed across iOS, Android and backend, for: anything touching shared architecture, navigation or deeplink schemes, persisted data shapes, purchase flows, adopting a new framework or core library (pilot it with a small blast radius, measure size and startup, keep a plan B), and any rewrite (rewrite only when a change will touch most of the codebase anyway; otherwise migrate incrementally, new screens first). Timebox the decision; on mobile tooling questions, prototype rather than debate.

## Choosing React Native

React Native fits organisations with strong JS and web talent and apps not dominated by brand-new OS APIs or heavy custom rendering. It does not remove the need for native expertise: platform-only bugs now span your code, the framework and the OS, new OS APIs need native modules, and RN upgrades are recurring work. Evaluate on: startup and screen performance on low-end devices, dev experience and tooling, native look and feel, binary size, native interop and type safety across the boundary (Expo Modules, TurboModules), build speed, OTA versioning, and whether the mobile team owns the decision. KMP is the alternative when the goal is shared logic with native UI.

## Reference files

Load the part that matches the task:

- `references/nature-of-mobile.md`: state, irreversible releases, old versions, deeplinks, push, crashes, offline, accessibility, CI/CD and the release train, third-party SDKs, fragmentation, in-app purchases.
- `references/app-complexity.md`: navigation architecture, event-driven state bugs, localisation, modules and dependency injection, automated and manual testing.
- `references/large-teams.md`: planning and RFCs, architecture that keeps teams apart, shared architecture across apps, tooling, build and merge times, platform teams.
- `references/cross-platform.md`: adopting languages and frameworks, KMP, shared business logic, React Native versus Flutter versus native, web views and server-driven UI.
- `references/stepping-up.md`: experimentation, feature flag hygiene, performance, analytics and alerting, on-call, code quality checks, privacy and security, client-side migrations, forced upgrades, app size.
