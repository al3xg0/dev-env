# App complexity

Each section: the challenge, what React Native and Expo give you, what they do not solve, and how to apply it. Written against Expo SDK 58 and React Native 0.88 (New Architecture only).

## Navigation architecture within large apps

**The challenge.** Navigation gets little thought while an app is small, then turns unmanageable as screens and transitions multiply. Neither platform ships a navigation architecture that scales, so teams invent their own. A large app needs a deliberate strategy that keeps navigation separate from app state: what may navigate where, what triggers each transition, and whether navigation depends on state. Without one, popups, toasts, modals and full screens are used inconsistently, animations differ from screen to screen and navigation code is duplicated. Asynchronous navigation (login, form submission) needs a plan for what happens when the user leaves mid-way. iOS has no standard navigation component while Android has a more opinionated back stack, so the two apps drift apart. Phones and tablets may need different flows for the same task.

### What React Native gives you

- **One navigation map for both platforms.** Expo Router derives the route tree from the files in `app/`, so the navigation map is the directory listing, and iOS and Android share it. `experiments.typedRoutes` in app config type-checks every `href`.
- **Presentation decided in one place.** Layouts set how a route appears (`<Stack.Screen name="confirm" options={{ presentation: "modal" }} />`), so screens call `router.push("/confirm")` without choosing an animation. That removes most duplicated navigation code and inconsistent transitions.
- **Navigation driven by state, not by screens.** `<Stack.Protected guard={isSignedIn} redirectTo="/sign-in">` (the `redirectTo` prop is new in SDK 58) and the `Redirect` component let auth state decide what is reachable, so a logout does not need every screen to reset the stack. Guards also apply to deep links.
- **A hook for asynchronous navigation.** `usePreventRemove(hasPendingWork, ({ repeat }) => ...)` from `expo-router` blocks leaving a screen while a submit is in flight or a form has unsaved data, and `repeat()` resumes the blocked action once it is safe.
- **Platform conventions handled.** The native stack gives iOS swipe-back and the Android back button without extra code. `router.dismissTo(href)` returns to a screen already on the stack, and `unstable_settings = { anchor: "index" }` fixes what sits under a deep-linked screen.

### What it does not solve

- **Conventions are still yours.** The router does not decide when to use a toast, a sheet, a modal or a screen. Write that down, or wrap it in a few shared helpers, or each team will pick its own.
- **Async flows beyond one screen.** `usePreventRemove` covers a single screen. A multi-step flow (sign-up, checkout) with a pending request needs its own state machine (for example `useReducer` or XState) that navigation reads from.
- **Phone and tablet layouts.** There is no stable cross-platform split view. `expo-router/unstable-split-view` is alpha and iOS only, and falls back to a plain `Slot` elsewhere. Most apps branch on `useWindowDimensions()` and render a combined screen on wide layouts.
- **Router upgrades are real migrations.** SDK 58 changed nested navigation params, removed `beforeRemove` and replaced `initialRouteName` with `anchor`. Budget for router changes at each SDK upgrade.

### How to apply it

1. Agree on a short list of presentation types (screen, modal, sheet, toast) and when each is used, and set `presentation` only in layouts.
2. Drive auth and onboarding with `Stack.Protected` guards and `redirectTo`, never with manual `router.replace` calls scattered across screens.
3. Wrap every submit-then-navigate screen in `usePreventRemove`, and model multi-step flows as an explicit state machine.
4. Decide the tablet behaviour per flow up front, and cover the main navigation paths with `renderRouter` tests (see Automated testing).

---

## Application state and event-driven changes

**The challenge.** Taps, network responses, timers and lifecycle events all change state, and each change can trigger others. Mobile apps have more states than web or desktop apps because of locking, app switching, background mode and patchy connectivity. The larger the app, the more bugs come from rare combinations of events (a background push arriving just as the screen locks, say), often consumed by components owned by different teams. These are hard to plan for and hard to test. The defences are immutable state that emits changes, and capturing invalid states with enough context to reproduce them: bug reports from beta users with the events and logs leading up to the problem. The ideal tool would replay, pause and rewind a user's session, including network events and per-thread activity, but native platforms have had nothing like the web's session replay.

### What React Native gives you

- **Immutable, unidirectional state.** The React model is the recommended approach: state is replaced, never mutated, and the UI is a function of it.
- **Serialised app logic.** Your JavaScript runs on one JS thread, so event handlers never run concurrently with each other. Interleaving still happens across `await` points, but there are no data races between handlers.
- **Explicit transitions.** `useReducer`, a Redux Toolkit slice or an XState machine lists every event and the state it moves to, which makes impossible combinations unrepresentable rather than merely untested.
- **Session replay on mobile.** `@sentry/react-native` (6.5.0 or later) records replays with `integrations: [Sentry.mobileReplayIntegration()]` and `replaysOnErrorSampleRate`, showing taps, network requests and console output around an error, with text, images and input masked by default. Breadcrumbs give the event trail on every error.
- **In-app bug reports.** `Sentry.feedbackIntegration()` adds a feedback form, optionally opened by shaking the device, that attaches to the session for beta users.

### What it does not solve

- **True rewind.** Replay shows what happened; it cannot step state backwards or re-run the session. Deterministic replay needs your own event log, which reducers make practical: log each action and you can rebuild the state.
- **Native threads.** The JS thread is serialised, but native modules, the UI thread and Reanimated worklets run elsewhere. Bugs that cross that boundary still need native logs and tools (Xcode, Android Studio).
- **What to log.** No tool knows which events matter. You add breadcrumbs for lifecycle, push and connectivity events, and keep personal data out of them.
- **Cross-team events.** A push handler in one team's module changing state another team relies on is an ownership problem, not a library one.

### How to apply it

1. Model each non-trivial feature's state as a reducer or state machine with named events, including `AppState`, connectivity and push events.
2. Log every action as a Sentry breadcrumb, without personal data, so each crash or report carries the event sequence.
3. Turn on `mobileReplayIntegration()` with a low session sample rate and `replaysOnErrorSampleRate: 1.0`, and enable the feedback form in beta builds.
4. When a bug comes from an event combination, add a unit test that dispatches that exact sequence to the reducer.

---

## Localisation

**The challenge.** Both platforms localise through resources compiled into the binary, which works until the app is large and has many locales. Strings in the binary cannot be fixed after release, so a team must decide how much localisation the backend does instead; serving strings from the backend or a vendor allows changes and one pass for both platforms. With many locales, every translation must be finished before a release leaves the build train. iOS and Android should use the same wording, which helps the brand and customer support, and that needs shared keys and tooling. Custom brand fonts often lack glyphs for some languages, especially in user-generated content, and add to app size. Currencies, dates and times format differently per platform and locale, and client-side arithmetic on currency values causes errors. Right-to-left languages need layouts rethought, not just mirrored, with native speakers involved. Verbose languages such as German and Japanese break layouts. Testing every locale is costly, so teams need a workflow for string changes, snapshots and pseudo-localisation to catch issues early, and a rule for terms that must never be translated, such as brand names.

### What React Native gives you

- **One set of strings for both platforms.** With `i18next` and `react-i18next` (or another JS library), both apps read the same keys from the same JSON files, so platform drift in wording largely disappears. Most vendors (Crowdin, Phrase, Lokalise and others) sync JSON directly.
- **Strings outside the binary.** Translations bundled in JavaScript ship with EAS Update, so a wrong phrase can be fixed without a store release. Loading them from your backend at runtime is also straightforward.
- **Device locale and region.** `expo-localization` gives `getLocales()` and `useLocales()` with `languageTag`, `textDirection`, `currencyCode`, `regionCode` and `measurementSystem`. Its config plugin's `supportedLocales` turns on per-app language selection in system settings.
- **RTL support.** `I18nManager` (`isRTL`, `allowRTL`, `forceRTL`) and logical style props (`marginStart`, `paddingEnd`, `start`, `end`) flip layouts. The `expo-localization` plugin options `supportsRTL` and `forcesRTL` set this up, and `forcesRTL` is handy for testing.
- **Formatting through `Intl`.** Hermes supports `Intl.NumberFormat`, `Intl.DateTimeFormat` and `Intl.Collator` on both platforms. It has no `Intl.PluralRules`, which i18next needs for plurals, so add `@formatjs/intl-pluralrules`.

### What it does not solve

- **Platform formatting differences.** Hermes uses each platform's own locale data rather than bundling ICU, so output can differ between iOS and Android and between Android versions; for example, iOS lacks compact notation and `signDisplay` in `NumberFormat`. Have the backend format money, and never do currency arithmetic on the client.
- **Fonts and missing glyphs.** `expo-font` embeds your fonts, but nothing tells you which scripts a font lacks. Pick per-locale fallback families yourself, and remember each font adds to app size.
- **Real RTL design.** Mirroring is automatic; deciding what should not mirror (icons, charts, media controls) and getting native speakers to review is not. Switching direction at runtime also needs an app reload.
- **Workflow and completeness.** Blocking a release on missing translations, routing string changes to reviewers, protecting brand terms and testing verbose locales are process and vendor questions.

### How to apply it

1. Keep all strings in i18next JSON keyed by feature, mark brand terms as do-not-translate in your vendor's glossary, and fail CI when any shipping locale is missing a key.
2. Let the backend format currency and, where possible, dates, and use `Intl` on the client only for display.
3. Use logical style props everywhere and run one build with `forcesRTL` and one with German as part of each release check.
4. Generate a pseudo-locale (accented, 30 to 40 percent longer strings) with a small script and add it as a selectable language in internal builds.

---

## Modular architecture and dependency injection

**The challenge.** Large apps are split into reusable modules, usually along team lines (a platform team owning networking, a payments team, a maps team), so the code ends up mirroring the organisation. Modules must declare their dependencies at module and class level, which is dependency injection, a form of inversion of control that mobile teams use less than backend and web teams. Injection lets classes be unit tested with mock dependencies, but wiring dependencies by hand gets slow and error-prone as they multiply, and circular dependencies become hard to spot. Android has compile-time frameworks for this; iOS historically had none, so large teams built their own.

### What React Native gives you

- **Packages as modules.** Expo detects monorepos built on Bun, npm, pnpm or Yarn workspaces and configures Metro automatically (SDK 52+), so each team can own a package under `packages/` with an `exports` map as its public API, and both apps consume it.
- **Context as the injection mechanism.** A provider at the root supplies services (`<ApiClientProvider client={api}>`), and components read them with a hook. Tests render the same tree with a fake client. Plain factory functions that take their dependencies as arguments cover non-React code.
- **Module-level substitution in tests.** `jest.mock` and the `jest-expo` preset's built-in mocks of Expo native modules replace a dependency without changing the code under test, so testability does not depend on a DI framework.
- **Cycle and boundary checks.** Metro warns about require cycles in development. `import/no-cycle` (eslint-plugin-import), `dependency-cruiser` or `eslint-plugin-boundaries` can fail CI on cycles and on imports that cross team boundaries.
- **Native code per team.** `npx create-expo-module --local` creates a native module inside the app, so platform code can be owned like any other package.

### What it does not solve

- **No compile-time dependency graph.** Nothing like Dagger or Hilt checks the full graph at build time. TypeScript checks types, not that every provider is mounted, so a missing provider is a runtime error.
- **Shared native dependencies.** All packages end up in one binary, so a native library can exist in only one version across every team. Upgrades need agreement.
- **Boundaries are convention.** Metro bundles everything together, so nothing stops a deep import unless lint rules and `exports` maps forbid it.
- **`jest.mock` can hide coupling.** Mocking modules makes tightly coupled code testable without fixing the coupling. Prefer passing dependencies in.

### How to apply it

1. Split the app into workspace packages along team ownership, each with an `exports` map and a CODEOWNERS entry.
2. Inject services (API client, analytics, storage, feature flags) through context providers or factory arguments, never through direct imports of singletons.
3. Add `import/no-cycle` and boundary rules to CI so cycles and cross-team deep imports fail the build.
4. Keep a single owner for native dependency versions, and upgrade them together with the Expo SDK.

---

## Automated testing

**The challenge.** Without enough automated tests, a large app becomes a trap. The test types are unit, integration, snapshot and UI tests, in rising order of cost and run time. Unit tests are the baseline, a safety net for refactoring and a way to share knowledge; in an untestable inherited codebase you add integration tests and unit-test only new code. Integration tests cover libraries and modules through their public API, and UI-level checks such as "this button opens that screen". Snapshot tests compare a rendered screen with a stored image; they are cheap but sensitive to device variety, and stored images bloat the repository. Native UI test tooling gets limiting at scale and needs patterns such as robots or page objects, plus separate tools to mock the network. Large UI suites are slow, which forces a choice between running them before merge or occasionally, and teams need parallel runs and flaky-test detection. Mocked data brings speed, edge cases, reliability and frequent runs, but mocks drift from live data, need structured storage and labelling, and must support scenarios where data changes mid-test. Test mixes vary widely between companies, and teams must also choose between their own device lab and a cloud device farm.

### What React Native gives you

- **One test suite for most logic.** Business logic and components are tested once in Jest for both platforms. `jest-expo` (which needs Jest 30 on SDK 58) mocks the Expo SDK's native side, and tests live in `__tests__/`, never in `app/`.
- **Component tests through accessibility queries.** React Native Testing Library v14 is fully async (`await render(...)`, `const user = userEvent.setup(); await user.press(...)`), queries by role and label, and ships its own matchers such as `toBeOnTheScreen`.
- **Navigation integration tests.** `renderRouter` from `expo-router/testing-library` (RNTL v14+) mounts real routes, `initialUrl` simulates a deep link, and `expect(screen).toHavePathname("/profile")` checks that a button opens a screen without a device.
- **UI tests in YAML.** Maestro flows in `.maestro/` drive the built app on both platforms. EAS Workflows run them with a `type: maestro` job after a build with an `e2e-test` profile, or on Maestro's cloud with `maestro-cloud`. Detox still works, but there is no current first-party Expo setup guide for it.
- **Typed mocks.** Generating TypeScript types (and fixtures) from your API schema makes a mock that drifts from the contract fail type-checking.

### What it does not solve

- **Pixel snapshots.** Jest's `toMatchSnapshot` stores the rendered tree, not an image, and the Expo docs recommend E2E tests over snapshot tests for UI. There is no mature first-party screenshot-diff tool for React Native; you assemble one (for example Maestro `takeScreenshot` plus an image diff in CI) and must store the images outside the repository yourself.
- **Native code paths.** Jest mocks the native side, so native modules, gestures and animations on the UI thread are only covered by device tests.
- **Mock data management.** Where fixtures live, how they are labelled and how scenarios switch data mid-test is your design. Point E2E builds at a mock server through an `EXPO_PUBLIC_` variable and keep scenarios in one place.
- **Running UI tests at scale.** Sharding, flaky-test quarantine and deciding what blocks a merge stay with you. Device farms such as Firebase Test Lab or Maestro's cloud cost money; Microsoft's App Center has been retired.

### How to apply it

1. Unit-test reducers, hooks and services in Jest, and component-test screens with RNTL v14 queries by role.
2. Test the main navigation paths and deep links with `renderRouter`, which is far cheaper than device tests.
3. Keep a small set of Maestro flows for core journeys, run them on every pull request with EAS Workflows, and run the full set nightly.
4. Generate API types and fixtures from the schema, and store scenario data in labelled JSON files that tests and the mock server share.

---

## Manual testing

**The challenge.** Testing each release by hand works for a small app but breaks down with weekly releases and many engineers; the aim is a main branch that is always shippable with little or no manual testing. Where manual testing stays, someone must decide who does it (engineers or a dedicated team), how test instructions, test accounts and test data stay current, whether to keep testing in-house, outsource it or mix the two, and how it fits the release train, including which issues block a release. Manual testing tends to find regressions just before release, long after the offending change merged, so teams should test earlier, in parallel or continuously, and leave time to fix what is found. Some testing stays manual even with excellent automation: anything touching the physical world (camera, QR codes, document scanning, AR, NFC), end-to-end payments (fraud systems ban automated traffic) and exploratory testing by people trying to break the app.

### What React Native gives you

- **Builds for testers on demand.** EAS Build with `"distribution": "internal"` produces installable builds from a URL, and `eas submit` can send builds to TestFlight groups or the Play internal track automatically.
- **Testing before merge.** EAS Update publishes the JS for a pull request (for example with `expo/expo-github-action/preview@v8`), and testers open it in a development or preview build. Manual checks can then run in parallel with review instead of at the end of the train.
- **One codebase to test.** Shared logic is tested once, so manual effort concentrates on platform-specific behaviour rather than repeating every check per platform.
- **Readable test steps.** Maestro flows are plain YAML, so a manual checklist step that gets automated stays understandable to the people who wrote it.

### What it does not solve

- **Both platforms still need hands-on checks.** Native components, permissions, keyboard behaviour and OEM quirks differ, so a release still needs a pass on iOS and on Android devices.
- **Hardware and payments.** Camera, NFC and AR flows, and real payments against production fraud systems, stay manual.
- **Process and people.** Who tests, where instructions and test accounts live, outsourcing, and what blocks a release are organisational decisions.

### How to apply it

1. Publish an EAS Update preview for every pull request that touches UI, so manual checks happen before merge.
2. Keep manual test cases with their test accounts and data in one owned place, and move every stable case into Maestro.
3. Define which severities block a release and leave buffer time in the train for fixes.
4. Reserve manual effort for hardware, payments and regular exploratory sessions on both platforms.
