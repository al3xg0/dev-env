# The nature of mobile apps

Each section: the challenge, what React Native and Expo give you, what they do not solve, and how to apply it. Written against Expo SDK 58 and React Native 0.88 (New Architecture only).

## State management

**The challenge.** Events arrive in no fixed order: taps, network responses and lifecycle changes such as going to the background and coming back. Bugs come from a combination nobody tested leaving shared state invalid. The OS can also kill the app at any time to reclaim memory, so the app has to save and restore its own state. Global device state (connectivity, permissions, Bluetooth) needs an owner, and deeplinks can launch the app into a screen whose state was never built.

### What React Native gives you

- **Unidirectional, immutable state by default.** React's model is the one that scales: the UI is a function of state, updates replace objects rather than mutating them, and data flows down the tree. The tedium of passing props down is the safety itself: a component cannot quietly change state it does not own.
- **Lifecycle events through `AppState`.** `AppState.addEventListener("change", ...)` reports `active`, `background` and, on iOS, `inactive`. One listener covers both platforms, so you do not deal with iOS app states and Android Activity callbacks separately.
- **One owner for global state.** A context provider or a store (Zustand, Redux Toolkit, Jotai) listens once, and components subscribe with selectors. This is the middle ground between every screen listening and one central dispatcher: no listener duplicated on every screen, and no dispatcher that knows its consumers, because the consumers pull what they need.
- **Ready-made hooks for device state.** `useNetInfo()` from `@react-native-community/netinfo` for connectivity, and permission hooks from Expo modules (for example `useCameraPermissions()` from `expo-camera`).

### What it does not solve

- **Process death wipes JavaScript state.** When the OS kills the app, React Native starts the JS bundle from scratch. Nothing is restored automatically, so anything the user would miss must be persisted: a store with a persistence adapter (Zustand `persist` on AsyncStorage or MMKV), and form drafts or in-progress flows saved as they change.
- **Async races are still yours.** A slow response arriving after a newer one can overwrite fresh state. Keep server data in TanStack Query, which de-duplicates requests, discards stale responses and refetches on reconnect and refocus, and cancel effects with `AbortController` when the screen changes.
- **Permissions change behind your back.** The user can revoke a permission in Settings while the app is in the background. Re-check permissions when `AppState` returns to `active`.
- **Deeplinks need state built after launch.** Expo Router maps a URL to a screen, but the data that screen needs (auth, the loaded record) must be fetched or guarded. See Deeplinks.

### How to apply it

1. Split state three ways: server state in TanStack Query, UI state local to the component, and a small global store for session and preferences, updated immutably.
2. Put `AppState`, NetInfo and permission listeners in one provider or hook each, and let screens subscribe.
3. Persist whatever the user would miss after a kill, with a `version` and `migrate` on the persisted store.
4. Test process death on Android: turn on "Don't keep activities" in Developer options, or background the app and run `adb shell am kill <package>`, then reopen it.

---

## Mistakes are hard to revert

**The challenge.** A mobile app ships as a binary, so a user who installs a version with a client-side bug keeps that bug until a fixed version is released and they install it. Both stores restrict downloading executable code that changes what an app does, although rolling back broken behaviour (for example with a feature flag) is acceptable, and Apple permits interpreted code such as JavaScript. Getting a new version out takes hours to days: every iOS build is reviewed, and Android reviews, when they happen, can take a week. After release, users take days to update even with automatic updates on, and some never update or skip several versions. In principle every version ever shipped has to be supported, unless you build a way to force upgrades. Android offers in-app updates through Play Core; iOS has no equivalent. The mitigations are thorough testing (automated, manual and a beta that bakes with employees for a week), feature flags to switch bugs off, staged rollouts with monitoring, and forced upgrades, at the cost of some churn.

### What React Native gives you

- **Over-the-air JavaScript updates.** `expo-updates` with EAS Update ships a new JS bundle and assets without a store release: `eas update --channel production --environment production --message "Fix checkout"`. By default the app checks on launch and applies a downloaded update on the next cold start; `Updates.useUpdates()`, `checkForUpdateAsync()`, `fetchUpdateAsync()` and `reloadAsync()` let you apply an urgent fix sooner.
- **Staged rollouts and rollback for updates.** `eas update --rollout-percentage=10`, widened with `eas update:edit`; `eas update:republish --group <id>` puts a previous good update back, `eas update:rollback` chooses the previous or embedded update, and `eas update:roll-back-to-embedded` returns clients to the bundle inside the binary. `eas channel:pause` stops a channel serving new updates.
- **Staged store releases.** EAS Submit sets the Play track and `rollout` fraction (with `releaseStatus: "inProgress"`), so binaries can go out to a percentage too.
- **Remote feature flags.** Flag services with React Native SDKs (`@launchdarkly/react-native-client-sdk`, `@statsig/expo-bindings`, `posthog-react-native`, or the vendor-neutral `@openfeature/react-sdk`) turn a feature off without any release.
- **Testing and beta channels.** Internal distribution builds (`"distribution": "internal"`), TestFlight and Play internal testing for the bake period; a `preview` channel lets testers receive the exact update before production does.

### What it does not solve

- **Native code is still a binary.** An update cannot change native code, native dependencies, permissions or the SDK version. A crash in native code or a config plugin needs a store release like any native app.
- **An update only reaches matching builds.** Updates go to builds with the same platform and `runtimeVersion`. A fix for an older runtime has to be published to that runtime separately, or it never arrives.
- **Store rules still apply.** Expo's docs say updates must follow store guidelines and that behaviour changes should be reviewed. Use updates for fixes, then ship the same fix in the next store build; do not use them to deliver features that bypass review.
- **Updates are not instant.** A user who never relaunches keeps the old bundle. Forced upgrades still have to be built (see The long tail of old app versions and Forced upgrading).

### How to apply it

1. Install `expo-updates`, run `eas update:configure`, and pick a `runtimeVersion` policy (`appVersion` is the documented default) so every build knows which updates it accepts.
2. Put risky features behind remote flags with a safe default when the flag service is unreachable.
3. Release every update with `--rollout-percentage`, watch crash and error rates per update ID (see App crashes), then widen or roll back.
4. Practise the rollback: publish a deliberately bad update to a test channel and time `eas update:republish` or `eas update:rollback` until it is routine.

---

## The long tail of old app versions

**The challenge.** Old app versions stay in use for years unless the team enforces a strict, rolling force-upgrade policy. Most users update within days, but a long tail lags several versions behind: some turn off automatic updates, and many are stuck on old phones or OS versions. The team rarely tests these versions because it is costly and pays off little, and a backend change that seems harmless, such as altering the content of one response, can still break them. The defences are robust response handling with strongly typed, generated client and server contracts rather than hand-parsed REST; planning breaking backend changes early, with a channel to the backend team and a way to test old versions; versioned endpoints, where a breaking change gets a new endpoint and the old one is deprecated but kept until a forced upgrade has moved everyone off it (GraphQL avoids versioning on principle); careful deprecation that watches traffic and has a migration plan; usage statistics per app version to decide how much effort old versions deserve; client-side monitoring and alerting with an on-call owner; and upgrade testing for major releases, which is expensive and rarely done.

### What React Native gives you

- **OTA updates shorten the JavaScript tail.** Every build on a given runtime version picks up the latest update on launch, so most JS logic converges even when users skip store releases. The tail that remains is one per runtime version.
- **Version identity for every request.** `expo-application` exposes `nativeApplicationVersion` and `nativeBuildVersion`; `expo-updates` exposes `Updates.runtimeVersion`, `Updates.updateId` and `Updates.channel`. Send them as headers so the backend can count traffic per version and branch behaviour where it must.
- **Generated, typed contracts.** OpenAPI generators (`openapi-typescript`, Orval, Kubb) or GraphQL Codegen give the app types generated from the backend schema; runtime validation with Zod catches a response that no longer matches instead of crashing deep in a screen.
- **Per-version health.** `@sentry/react-native` tags events with release and dist, and the Expo Sentry guide adds update ID tags, so crashes and errors can be filtered by version and update.
- **Forced upgrade building blocks.** `sp-react-native-in-app-updates` wraps Play Core in-app updates on Android (`IAUUpdateKind.IMMEDIATE` or `FLEXIBLE`); on iOS it can only check the store version and show an alert linking to the App Store. It needs a development build, not Expo Go.

### What it does not solve

- **Native changes create a new tail.** Each new runtime version stops older builds receiving updates, so a binary from two years ago runs two-year-old JS against today's API.
- **Backend compatibility is a backend discipline.** Additive changes, versioned endpoints and deprecation monitoring are the server team's work; React Native has no say in it.
- **A minimum-version policy is yours to build.** A "minimum supported version" endpoint, the blocking screen and the decision on where to set the bar are not provided.
- **Upgrade testing is manual.** Nothing installs last year's build, fills it with data and upgrades it for you.

### How to apply it

1. Add app version, build number, runtime version and update ID headers to every API call, and build a dashboard of traffic share per version.
2. Generate the API client from the schema in CI and validate responses tolerantly: unknown enum values and extra fields must not crash.
3. Serve a minimum supported version per platform from the backend; below it, show a blocking screen with a store link (or Play's immediate update), and use it to retire old endpoints.
4. Before a major release, install the oldest supported build from `eas build:list`, create data, install the new build over it (`adb install -r`, or install over it on a simulator) and check that nothing is lost.

---

## Deeplinks

**The challenge.** Opening a specific part of the app from a web or device link is harder on mobile than it looks, because iOS and Android provide APIs but no opinionated framework or recommended approach. Existing links must keep working in older and newer app versions after navigation or logic changes. A link that arrives while the app is running with existing state forces a choice: push the new screen on top and keep the current stack, or reset; a full reset is the most predictable, but some flows must not be broken. iOS uses universal links and URL schemes while Android uses intents, which is why third-party link providers exist to hide the difference. Deeplinks are usually added late, after several versions have shipped, and retrofitting them is difficult because they depend on state management and navigation architecture. With no platform guidance on designing and testing them, the cost of keeping links working grows with every link added, so planning ahead matters.

### What React Native gives you

- **One route table for both platforms.** Expo Router makes every file in `app/` a URL, so deep linking is on by default: set `scheme` in app config for custom URLs, and the same paths serve iOS, Android and web.
- **Universal links and App Links from config.** `ios.associatedDomains: ["applinks:example.com"]` and an `android.intentFilters` entry with `autoVerify: true`, with `apple-app-site-association` and `assetlinks.json` hosted under `.well-known` (in Expo Router projects, `public/.well-known/`).
- **A compatibility layer for old URLs.** `+native-intent.tsx` exporting `redirectSystemPath({ path, initial })` rewrites incoming paths before routing, so legacy or third-party link formats keep resolving after routes move.
- **Predictable stacks on cold start.** `unstable_settings = { anchor: "index" }` in a layout puts the anchor screen beneath a deep-linked screen, so Back works; `Stack.Protected` guards screens that need a session.
- **Testing tools.** `npx uri-scheme open myapp://path --ios`, `adb shell am start -a android.intent.action.VIEW -d <url> <package>`, and `renderRouter(..., { initialUrl })` from `expo-router/testing-library` for unit tests of link resolution.
- **Attribution providers.** `react-native-branch` for links that must survive install or fall back to the web. Firebase Dynamic Links has been shut down, so do not build on it.

### What it does not solve

- **The warm-app policy.** Whether a link pushes onto the current stack or resets it is a product decision you implement with `router.push`, `router.replace` or `router.dismissTo`.
- **Data and auth behind the route.** The router opens the screen; loading the record, handling a missing or forbidden one and resuming after sign-in are yours.
- **Renamed routes break old links.** File moves change URLs. Without a `redirectSystemPath` mapping or redirects, links in old emails and notifications stop working.
- **Domain files and verification.** Hosting the association files, signing certificate fingerprints (`eas credentials -p android`) and checking verification still sit with the team.

### How to apply it

1. Treat URLs as a public API: write down the supported link formats and design routes around them from the start.
2. Configure `scheme`, associated domains and verified intent filters, and host both association files over HTTPS.
3. Keep every retired path mapped in `+native-intent.tsx`, with a `try/catch` that sends unknown input to a fallback screen.
4. Decide the warm-app behaviour per link type, then cover cold start, warm start and signed-out cases with `renderRouter` tests and a manual `uri-scheme` run.

---

## Push and background notifications

**The challenge.** The business will want push notifications, and they are complex to set up and run. The app obtains a token from FCM on Android or APNs on iOS and stores it on the backend, and sending happens on the backend, so the backend team has to learn the mobile push infrastructure and agree which notifications to send and what triggers them. Combining push with email and SMS for marketing can conflict with Apple's guidelines, yet it is common, and most teams use a third-party engagement service rather than building it. A notification is effectively a deeplink, with the same backward compatibility, state and planning problems. Users can opt out or never opt in, and the two platforms differ in how, and how far, you can detect that; on iOS, silent background notifications still reach users who opted out. Delivery is not guaranteed: bulk sends can be throttled by opaque rules, devices go offline, and the OS limits apps that have not been used recently, so push is best treated as a nice to have. Testing is hard: simulators allow manual tests, but automation needs costly end-to-end UI tests. Background notifications (data messages on Android) carry no UI and are useful for syncing and multi-device use, replacing polling with push, but they bring delivery and ordering problems and need local caching for offline use.

### What React Native gives you

- **One API for both platforms.** `expo-notifications`: `getPermissionsAsync()` and `requestPermissionsAsync()` (with `ios.status` distinguishing provisional authorisation), `setNotificationChannelAsync()` on Android (required before the Android 13 prompt and before fetching a token), `getExpoPushTokenAsync()` or `getDevicePushTokenAsync()` for raw FCM or APNs tokens, and `addPushTokenListener()` for token rotation.
- **Expo Push Service.** One HTTP API for both platforms (`expo-server-sdk-node` and community SDKs), with push tickets and receipts that report errors such as `DeviceNotRegistered`, so the backend can prune dead tokens. EAS manages the FCM and APNs credentials (`eas credentials`).
- **Notification as deeplink.** `addNotificationResponseReceivedListener()` and `getLastNotificationResponse()` (or `useLastNotificationResponse()`) read a `url` from the payload and pass it to `router.push`, so taps go through the same routes as deeplinks. `setNotificationCategoryAsync()` adds action buttons.
- **Background handling.** `Notifications.registerTaskAsync()` with `TaskManager.defineTask` from `expo-task-manager` runs JS when a notification arrives in the background or while the app is killed; on iOS enable `enableBackgroundRemoteNotifications` in the plugin config and send `contentAvailable: true`.
- **Engagement vendors.** OneSignal, Braze, Airship and others publish React Native SDKs if marketing owns campaigns.

### What it does not solve

- **Delivery guarantees.** Expo documents a limit of 600 notifications per second per project, and the OS can still drop background notifications (Doze on Android; Apple advises no more than two or three background pushes per hour). Receipts confirm handoff to Apple or Google, not that the user saw anything.
- **Ordering and deduplication.** Background messages can arrive late, twice or out of order; treat them as a hint to sync, not as the data.
- **Opt-in strategy and copy.** When to ask, pre-permission screens and what to send are product work.
- **Automated end-to-end tests.** Simulator pushes (`xcrun simctl push` on iOS) are manual aids; asserting real delivery in CI remains expensive.

### How to apply it

1. Register the token after sign-in, send it with the user and device ID, and update it from `addPushTokenListener()`; delete tokens the receipts mark as `DeviceNotRegistered`.
2. Make every notification carry a URL that resolves through the router, and version the payload so older builds can ignore fields they do not understand.
3. Use background notifications only to trigger a fetch of current state, with polling or refetch on focus as the fallback.
4. Re-check permission when the app returns to the foreground and hide push-only features for users who declined.

---

## App crashes

**The challenge.** Crashes are among the most visible bugs and can cost a lot: users abandon key flows, churn or leave bad reviews. Backend teams watch uncaught exceptions and 5xx responses, and the web crashes less because it runs single-threaded in a sandbox. The first rule is to record every crash with enough information to debug it, then report the share of sessions that crash and drive it down. Apple and Google provide crash logs (Xcode and App Store Connect, and Android vitals in Play Console), but only from users who agreed to share them, which suffices for small apps. Third-party or custom tools add breadcrumbs that lead up to a crash, grouping and cross-platform comparison, alerts on new or spiking crashes, and links to ticketing and pull requests; many miss app-not-responding (ANR) and memory problems, and large organisations may build their own for cross-app reporting and tool integration. Crashes are harder to reproduce on mobile because of the spread of devices, OS versions and app versions, so a prioritisation framework is needed that weighs frequency, user value and the cost of fixing against other work. The target metric is session stability: under one crashed session in 10,000 is good, and 99.99% crash-free counts as world class.

### What React Native gives you

- **Crash and error reporting that covers both layers.** `@sentry/react-native`, set up with `npx @sentry/wizard@latest -i reactNative`, captures native crashes and JS errors, records breadcrumbs, and reports crash-free sessions per release. It tracks iOS app hangs by default (`enableAppHangTracking`, 2 second threshold) and Android ANRs. `@react-native-firebase/crashlytics` and BugSnag (Expo has a guide) are alternatives.
- **Readable stack traces.** Source maps upload automatically on EAS Build when `SENTRY_AUTH_TOKEN` is set; after `eas update`, run `npx sentry-expo-upload-sourcemaps dist`. Tag the scope with `Updates.updateId` so a crash points to the exact update.
- **Containment of JS errors.** An Expo Router route can export an `ErrorBoundary` component, so a render error in one screen shows a recovery UI instead of taking down the app.
- **Store-side data still applies.** Xcode Organizer and Android vitals keep working for native crashes and ANRs alongside your SDK.
- **Fast fixes for JS crashes.** A JS crash can often be fixed with an EAS Update to the affected runtime, rolled out by percentage (see Mistakes are hard to revert).

### What it does not solve

- **Errors outside render.** Error boundaries do not catch errors in event handlers, promises or effects after render; the reporting SDK records them, but the code must still handle them.
- **Memory and native SDK crashes.** Out-of-memory terminations and crashes inside third-party native SDKs are hard to attribute and usually need a binary release.
- **Reproduction.** Device-specific crashes still need the device, a device farm or careful reading of breadcrumbs and device tags.
- **Thresholds and priorities.** Deciding which crashes justify the work, and owning the alert, is a team process.

### How to apply it

1. Install Sentry (or an alternative) before launch, verify a test crash in a release build, and confirm symbolicated native and JS traces for both build and update.
2. Set a crash-free sessions target per platform, show it on the release dashboard and block widening a rollout that regresses it.
3. Add an `ErrorBoundary` to every top-level route group and log non-fatal errors with context (screen, user action, update ID).
4. Alert on new issues and spikes, route them to an owner, and triage by affected users and flow importance rather than raw count.

---

## Offline support

**The challenge.** Users expect a mobile app to keep working when the signal drops and never to lose their state. Proper offline support adds complexity and edge cases. Detecting being offline is unreliable: the OS can report a connection that carries no data, such as a captive Wi-Fi portal, so the app may need to probe known hosts. Connection speed and latency may need to change behaviour, from adapting a stream to warning the user. Local state has to persist offline and sync back later, with races when the same user is on several devices, some offline, and with migrations when an update changes the stored format. Teams should decide which features work offline, starting with the core ones and expanding once the main mode works. Edge cases need decisions: very slow connections are safest treated as offline, and timeouts raise the question of retries. A soft timeout followed by a retry can produce two responses and corrupt data. Syncing device and backend data needs a conflict resolution approach that handles parallel offline edits and dropped connections. Retry strategy must answer whether the network is actually up, how to stop frantic users creating parallel duplicate requests, how to tell a slow backend from a slow network, when the network has truly recovered, and whether to use conditional requests with ETags or If-Match. Reactive networking libraries help. Some requests, such as payments, must not be blindly retried, because a timed-out request may still have succeeded on the server; idempotent endpoints with idempotency keys fix this but add state that must survive a crash. Simplicity is the key: immutable state, simple sync and simple slow-connection rules, tested with network throttling tools.

### What React Native gives you

- **Connectivity with a reachability check.** `@react-native-community/netinfo` reports `isConnected` and `isInternetReachable` separately, and `NetInfo.configure({ reachabilityUrl, reachabilityTest, ... })` lets you probe your own endpoint, which catches captive portals. `details.cellularGeneration` gives a rough speed hint. `expo-network` is a lighter alternative.
- **Offline-aware server state.** TanStack Query with `onlineManager.setEventListener` wired to NetInfo pauses queries and mutations while offline and resumes them on reconnect; `networkMode: 'offlineFirst'`, built-in retries with backoff, and request de-duplication prevent parallel duplicates. `PersistQueryClientProvider` with `@tanstack/query-async-storage-persister` keeps the cache and paused mutations across restarts (`setMutationDefaults` plus `resumePausedMutations()`).
- **Local databases and sync engines.** `expo-sqlite` for a local store; WatermelonDB, PowerSync (`@powersync/react-native`) or similar for synced data with conflict handling.
- **Idempotency keys.** `Crypto.randomUUID()` from `expo-crypto`, generated when the user acts and persisted with the pending request, so a retry after a crash reuses the same key.

### What it does not solve

- **Conflict resolution.** Last write wins, field merges or CRDTs is a product and backend decision; libraries only carry out the policy you choose.
- **Idempotent endpoints.** The server must accept and honour idempotency keys; the client cannot make a payment safe by itself.
- **Scope.** Which features work offline, and what the UI shows for queued actions and slow connections, has to be designed.
- **Stored data migrations.** Changing the shape of persisted data needs versioned migrations (see Client-side data migrations).

### How to apply it

1. List the features that must work offline and build only those first; mark the rest clearly as needing a connection.
2. Wire NetInfo into TanStack Query's `onlineManager`, point the reachability check at your API, and treat a failed probe or very slow responses as offline.
3. Queue writes as persisted mutations carrying an idempotency key, and never retry non-idempotent calls without one.
4. Test on throttled networks: Network Link Conditioner on iOS, the Android emulator's network speed and latency settings, plus airplane mode mid-request and a kill and relaunch with writes still pending.

---

## Accessibility

**The challenge.** With a large user base, many people have some accessibility need, and an app that ignores them is unusable for them and a legal exposure for the publisher. Accessibility also raises quality for everyone. The team first has to agree how far to go against the WCAG mobile guidance: a usable screen reader experience (VoiceOver, TalkBack) and sufficient colour contrast are the usual floor, with hearing and other needs depending on the product. It goes beyond screen readers: the app must honour the user's preferred text size (Dynamic Type on iOS, scale-independent units on Android), and some Android manufacturers ship different default font sizes. Building it in from the start is cheap; retrofitting is slow, so it belongs in design and planning. Testing needs a plan of its own: automated checks for things such as missing labels, regular manual passes in the release process, users with accessibility needs in the beta group, and engineers turning the features on during development.

### What React Native gives you

- **One set of props for both screen readers.** `accessibilityLabel`, `accessibilityHint`, `accessibilityRole` (or `role`), `accessibilityState`, `accessibilityValue` and `accessibilityActions` with `onAccessibilityAction` map to VoiceOver and TalkBack. ARIA-style equivalents exist (`aria-label`, `aria-checked`, `aria-hidden` and so on). Platform-specific props cover the rest: `accessibilityViewIsModal` and `onMagicTap` on iOS, `accessibilityLiveRegion` and `importantForAccessibility` on Android.
- **Grouping and focus.** `accessible={true}` merges a row into one focusable element. `AccessibilityInfo.sendAccessibilityEvent(host, 'focus')` moves focus after navigation (`setAccessibilityFocus` is deprecated), and `AccessibilityInfo.announceForAccessibility()` speaks status changes.
- **Font scaling on by default.** `<Text>` respects the system text size (`allowFontScaling` defaults to `true`). `maxFontSizeMultiplier` caps growth where a layout truly cannot cope, `dynamicTypeRamp` picks the iOS Dynamic Type style, and `useWindowDimensions().fontScale` exposes the current scale, which covers manufacturers with non-standard defaults.
- **User preferences as data.** `AccessibilityInfo.isScreenReaderEnabled()`, `isReduceMotionEnabled()`, `isBoldTextEnabled()` (iOS) and `isHighTextContrastEnabled()` (Android), with change events such as `screenReaderChanged` and `reduceMotionChanged`. Reanimated animations accept a `reduceMotion` option.
- **Automated label checks in unit tests.** React Native Testing Library queries by role and accessible name (`getByRole('button', { name: 'Pay' })`) and ships matchers such as `toHaveAccessibleName`, so a test that finds controls this way fails when a label is missing.

### What it does not solve

- **Correct semantics are still hand-written.** Nothing infers a label for an icon-only button or the right reading order for a custom component. Custom touchables built from `Pressable` and `View` need a role and state set explicitly.
- **Layouts that survive large text.** Font scaling is on, so fixed heights, single-line rows and truncated buttons break at the largest sizes. Capping with `maxFontSizeMultiplier` everywhere defeats the point.
- **Contrast and colour.** React Native has no contrast checker; it belongs in the design system and design review.
- **Real screen reader testing.** VoiceOver does not run in the iOS simulator. Xcode's Accessibility Inspector and Google's Accessibility Scanner help, but only devices with VoiceOver and TalkBack show the real experience, and the two differ.
- **Deciding the target.** Which WCAG level you commit to, and which needs beyond sight and text size you cover, is a product decision.

### How to apply it

1. Agree a written baseline (screen reader usable, contrast, text scaling to the largest size) and add an accessibility section to the design and RFC template.
2. Put roles, labels and state into the shared component library, so product screens inherit them and icon buttons cannot be created without a label.
3. Write component tests with `getByRole` and accessible names, so a missing label fails CI.
4. Add a VoiceOver and TalkBack pass at the largest font size to the release checklist, and run the app day to day with large text and reduce motion turned on.
5. Recruit users who rely on assistive technology into the TestFlight and Play testing groups.

---

## CI/CD and the build train

**The challenge.** Mobile cannot be continuously deployed the way a backend can: App Store review is a manual gate, so only Android (and enterprise iOS distribution) can be fully automated. iOS and Android need separate build systems and pipelines, and a CI vendor has to treat both as first-class at the scale the team needs. Running CI in-house gives control but needs people dedicated to it; without them, buying is safer. On top of CI sits the build train: a release candidate is cut on a regular cadence, passes automated tests, manual testing, localisation, performance checks and a dogfood or beta period, is submitted and approved, then goes out gradually (phased release on iOS, staged rollout on Android). Stages typically run from nightly internal builds, through employee and beta builds, to staged production. The team must choose whether to couple the two platforms' releases, and how often to ship: weekly, every two weeks, or ad hoc, where rarer releases bundle more change and more regressions. The train should show which commit was cut, where validation stands and how far the rollout has got, and the "ready to ship" checks (UI tests, manual sanity tests, complete translations, crash and memory regressions, business metrics) should be written down and automated as far as possible.

### What React Native gives you

- **One codebase, one pipeline definition.** Both platforms build from the same JS and app config, so coupling iOS and Android releases is the natural default rather than an extra cost.
- **Hosted mobile CI.** EAS Build runs iOS builds on macOS VMs and Android builds on Linux, with credentials stored on EAS (`eas credentials`). The build image is pinnable per profile in `eas.json` (for example the `sdk-58` alias), so an Xcode upgrade is a deliberate change. `"cli": { "appVersionSource": "remote" }` with `"autoIncrement": true` removes build-number bookkeeping.
- **Pipelines as code.** EAS Workflows (`.eas/workflows/*.yml`, created with `eas workflow:create`) chain `build`, `submit`, `update`, `fingerprint`, `maestro` and `testflight` jobs on git triggers. The deploy template uses a fingerprint job to decide whether a change needs a new binary or can ship as an update. GitHub Actions works too via `expo/expo-github-action` and `EXPO_TOKEN`; fastlane remains an option, and EAS uses it internally.
- **Train stages map to build profiles.** `development` (dev client, internal), `preview` (internal distribution, the nightly or dogfood build), `production` (store). Each profile can point at its own update `channel`.
- **Submission and staged rollout.** `eas submit` (or `eas build --auto-submit`) uploads to TestFlight and Play. The Android submit profile takes `track` (`internal`, `alpha`, `beta`, `production`), `releaseStatus: "inProgress"` and a `rollout` fraction; iOS profiles can target TestFlight `groups`.
- **A faster lane between store releases.** EAS Update ships JS-only fixes with `eas update --rollout-percentage=10`, then `eas update:edit` to widen and `eas update:rollback` to retreat.

### What it does not solve

- **The review gate.** EAS cannot shorten App Store review, and an OTA update must stay within store rules; behaviour changes still go through a binary.
- **iOS phased release.** It is set in App Store Connect for the version; I found no EAS submit option for it.
- **The release dashboard.** Nothing in EAS shows a train view of cut commit, check status and rollout percentage together. Small teams track it by hand; larger ones build or buy one.
- **The checks themselves.** Defining and automating the release gates (crash rate, memory, missing translations, funnel metrics) is the team's job, using its own crash reporting and analytics.
- **Two release lanes to govern.** OTA updates make it easy to bypass the train. Decide which fixes may go out as updates and who approves them.

### How to apply it

1. Model the train as build profiles (`development`, `preview`, `production`) with matching update channels, and pin the build image.
2. Write an EAS Workflow per stage: PR checks with unit tests and a Maestro smoke test, a scheduled nightly `preview` build, and a release workflow that builds, submits to TestFlight and the Play internal track.
3. Pick a fixed cadence (weekly or fortnightly), cut from a release branch, and couple both platforms by default.
4. Write the go/no-go checklist, automate what you can (tests, `--check` on dependencies, translation completeness), and gate promotion on crash-free rate in the beta.
5. Roll out gradually: Play `rollout` from 1 to 100 per cent, phased release on iOS, and the same percentages for OTA updates.

---

## Third-party libraries and SDKs

**The challenge.** As dependencies pile up, the build gets harder and every new version can break the app and need re-testing. Libraries are a security risk: vulnerabilities in widely used SDKs can expose users' data or let unknown code run, so they need ongoing monitoring, possibly through a security vendor. They are a stability risk too: SDKs that talk to their vendor's backend have crashed apps in production because of a server-side change that no app team could have tested for and could not undo in shipped binaries. A per-SDK feature flag that stops the library loading is the defence. Library upgrades are among the riskiest changes because they are hard to make reversible: shipping two versions side by side is close to impossible, so they need extra testing, closer monitoring through the build train and longer beta periods. Before adopting a dependency, assess its size, whether it could block a future Xcode or Android Studio upgrade, the chance it stops being maintained, and how responsive its owner is. Treat every dependency as a risk, keep a list, and review it regularly.

### What React Native gives you

- **A curated, version-locked core.** The Expo SDK covers much of what apps used to pull in from the community, and `npx expo install` picks the version tested with your SDK. `npx expo install --check` fails CI when a package drifts from the recommended version; `--fix` repairs it. `npx expo-doctor` runs further project checks.
- **Somewhere to evaluate libraries.** React Native Directory (reactnative.directory), which the Expo docs point to first, shows platform support, Expo Go compatibility and maintenance signals for each package.
- **New Architecture as a quality bar.** On RN 0.88 the New Architecture is the only one, so a library that has not been updated for it does not work: an early, visible sign of an unmaintained package.
- **Size visibility.** Expo Atlas (`EXPO_ATLAS=true npx expo start --no-dev`) shows which libraries make up the JS bundle.
- **Gating SDKs from JS.** Because most SDKs are initialised from JS, a remote flag checked before `init` (or before the component mounts) can switch one off for an installed binary, and EAS Update can ship that change without a store release.
- **Privacy declarations.** `ios.privacyManifests` in app config adds required-reason API entries alongside those that SDKs ship.

### What it does not solve

- **Native-side crashes before JS runs.** An SDK started from native code (for example by a config plugin in the app delegate) or crashing inside its native layer cannot be gated by a JS flag. Prefer libraries you initialise lazily from JS.
- **OTA cannot change native code.** Rolling back a native library upgrade needs a new binary; only the JS that calls it can be reverted by update.
- **Security monitoring.** `npm audit` (or the pnpm and Yarn equivalents), Dependabot, Renovate or a commercial scanner, plus Google Play's SDK warnings, are yours to wire up. Native pods and Gradle dependencies pulled in by libraries are not covered by npm tooling.
- **Upgrades still carry risk.** Each Expo SDK upgrade (three a year) moves many native dependencies at once, and community libraries may lag.
- **The adoption decision.** Size, maintenance, upgrade blocking and owner responsiveness have to be judged by the team.

### How to apply it

1. Keep a dependency register: owner, purpose, native or JS-only, and last review date. Re-review it every SDK upgrade.
2. Before adding a library, check the Expo SDK first, then React Native Directory (New Architecture support, recent releases, open issues), and measure its bundle cost with Atlas.
3. Wrap every vendor SDK behind your own module, initialised from JS behind a remote kill switch.
4. Run `npx expo install --check` and a vulnerability scan in CI; let Renovate or Dependabot raise upgrade PRs.
5. Treat SDK and native library upgrades as high risk: land them early in a release cycle, extend the beta, and watch crash reports through the staged rollout.

---

## Device and OS fragmentation

**The challenge.** Every year both platforms add, change and deprecate APIs, some exist on only one of them, and keeping up takes deliberate effort. The harder part is keeping the app working on older OS versions and devices, which needs an in-house device lab or a third-party device testing service. Android is worse: device-specific crashes from manufacturer customisations, unusual form factors such as foldables, troublesome hardware drivers and sensors, and stack traces that are hard to read. Android forks without Google Play Services (Fire OS, Huawei) also lose services such as Firebase push. Crash reports, user reports and large manual test runs are the way to stay on top of it, and all cost more than expected. The team should set a policy early for dropping old OS versions, weighing the cost of support against the revenue from those users, within any legal obligations; Android teams usually support a few years back, and iOS teams drop all but the last two or three versions soon after a new release.

### What React Native gives you

- **Minimum versions decided per SDK.** Expo SDK 58 supports Android 7 (API 24) and later and iOS 16.4 and later, with `targetSdk` 36. Each SDK upgrade raises the floor in a predictable way, so OS support follows your SDK upgrade cadence.
- **Platform differences behind one API.** Core components and Expo modules absorb many OS differences. Where you need to branch, `Platform.OS`, `Platform.Version` and `Platform.select()` do it in JS, and `expo-device` reports model, manufacturer and OS version for diagnostics.
- **Adaptive layout primitives.** Flexbox, `useWindowDimensions()` and `react-native-safe-area-context` handle varied screen sizes, notches and foldable states without per-device code.
- **Native escape hatch.** Expo Modules (Swift and Kotlin) let you call a new OS API on day one when no library exposes it yet.
- **Device testing in CI.** EAS Workflows runs Maestro flows on emulators and simulators (`maestro` job) and on a device cloud (`maestro-cloud` job); release builds can also go to Firebase Test Lab, AWS Device Farm or BrowserStack.

### What it does not solve

- **Device-specific bugs.** Manufacturer quirks, GPU and driver issues and odd sensors still need real devices to reproduce; abstraction does not remove them.
- **Libraries' own floors.** A library can require a higher OS version than the SDK, quietly raising your minimum.
- **Devices without Google Play Services.** `expo-notifications` push on Android depends on FCM, so Fire OS and Huawei devices get no push without a separate native integration; maps and other Google-backed services have the same problem. There is no first-party Expo answer.
- **The deprecation policy.** When to drop an OS version, and what to show users stuck on it, is a business decision; Expo only sets the lower bound.

### How to apply it

1. Write an OS support policy tied to Expo SDK upgrades, using your own analytics on OS share and revenue to decide when to move faster than the SDK floor.
2. Keep a small device set covering the oldest supported OS, a low-end Android, a Samsung device and a foldable or tablet; use a device cloud for breadth.
3. Tag crash reports with model, manufacturer and OS version (`expo-device`) and watch for clusters during staged rollouts.
4. Track each year's iOS and Android releases: build against the betas, then adopt new APIs through Expo modules or a small custom module.

---

## In-app purchases

**The challenge.** Digital goods sold in a mobile app usually have to go through the stores' billing, which takes a substantial cut (15 per cent on the first million dollars a year, more above), and comes with many constraints:

- **Different models.** iOS and Android differ in what they support (Google can pause subscriptions, Apple cannot), and both differ from the web.
- **Reliable state changes.** Users expect purchases to take effect at once. Client-only validation is simpler but ties entitlement to the store account and is open to clock changes and modified apps; server-side validation adds delay and edge cases. On-device receipt checks also cost load time, need Apple's public key embedded, and require hardcoded product IDs.
- **Rigid pricing.** Fixed price tiers, awkward subscription price changes, hard per-country prices, and products baked into the binary if everything is client-side.
- **Weak tooling and documentation.** Apple's subscription APIs are thinly documented, and neither store supports much beyond simple one-off and subscription products.
- **Reporting and finance.** Net revenue per user is close to impossible to compute; payouts, taxes and Apple's fiscal calendar differ by store, and engineers end up helping finance reconcile.
- **Support limits.** On iOS the developer cannot cancel or refund a subscription, which confuses users and earns one-star reviews.
- **Identity, restore and outages.** Store purchases must be mapped to your users, restore must just work on a new phone (iOS transaction IDs can change on restore), and store validation endpoints have outages that are rarely announced.
- **Other stores and B2B.** Amazon and Huawei need separate integrations; there is no volume licensing for IAP, and VAT invoices come from the stores.
- **Edge cases.** Cancelling and re-buying, trials and grace periods, upgrades, downgrades and crossgrades, discounts (Apple promotional and offer codes, Google promo codes), refunds, failed payments, account hold, paused subscriptions, and changes made outside the app while it was closed. Your server notification endpoint must persist every event even when processing is down.
- **Testing.** Apple sandbox, StoreKit testing and Google license testers exist, but sandboxes cannot reproduce everything (Family Sharing, storefronts, some product types), the backend must accept sandbox traffic and tell it apart by its environment field, and real devices across OS versions are needed. Test plans should cover every purchase type, receipt content, every tier change, grace periods and out-of-app changes, and be documented before they can be automated.
- **People and process.** Support needs runbooks and a direct line to the engineers who own IAP, and engineers need visibility of reviews and complaints. Users switching platforms raise transfer and duplicate-subscription questions.
- **Experiments.** Neither store supports A/B pricing; experiments mean extra subscription groups that lock users in (and on Apple, moving groups resets the one-year point at which the cut falls), and retired plans must be grandfathered. Plan success criteria, keep tests short, use cancellable monthly plans, and be generous to affected users.
- **Backend collaboration.** The backend team has to model each platform's billing; mobile engineers usually have to teach them.

### What React Native gives you

- **Two maintained routes, both needing a development build** (not Expo Go):
  - `react-native-purchases` (RevenueCat), installed with `npx expo install react-native-purchases react-native-purchases-ui`. It wraps StoreKit and Google Play Billing and runs a hosted backend: `Purchases.configure({ apiKey })`, `Purchases.getOfferings()` (products and prices configured remotely, not hardcoded), `Purchases.getCustomerInfo()` and `addCustomerInfoUpdateListener()` for entitlements, `Purchases.logIn(appUserID)` to tie purchases to your user across platforms, `Purchases.restorePurchases()`, `Purchases.showManageSubscriptions()`, and `beginRefundRequestForActiveEntitlement()` (iOS). It handles store notifications, receipt validation, cross-platform entitlements, revenue charts and price experiments, and supports Amazon (`useAmazon: true`) and Galaxy Store. In Expo Go it falls back to a Preview API Mode with mocked calls, useful for UI work only.
  - `expo-iap` (OpenIAP specification), with the `useIAP` hook, `fetchProducts`, `requestPurchase` (separate `apple` and `google` request fields) and `finishTransaction`, on StoreKit 2 (iOS 15+) and Google Play Billing. It leaves the backend to you. `react-native-iap` 14 (Nitro Modules, RN 0.79+, also with an Expo config plugin) is the older sibling from the same ecosystem.
- **Paywalls as remote config.** `react-native-purchases-ui` renders paywalls configured on the RevenueCat dashboard; with either library, product lists can come from your backend and change through EAS Update without a store release.
- **Platform test tooling still applies.** Apple sandbox accounts, a StoreKit configuration file (in the prebuilt Xcode project) and Google Play license testers all work with development and preview builds.

### What it does not solve

- **Store rules and economics.** The commission, price tiers, review rules and the inability to refund or cancel on iOS on the user's behalf are unchanged.
- **Server-side truth if you go without RevenueCat.** With `expo-iap` you must build validation against the App Store Server API and the Google Play Developer API, consume App Store Server Notifications and Google real-time developer notifications (via Pub/Sub), store events durably before processing, and model every subscription state. Apple's old `verifyReceipt` endpoint is deprecated.
- **Vendor dependency if you go with it.** RevenueCat becomes a critical third-party service in the purchase path (see Third-party libraries and SDKs): plan for its outages and keep your own copy of entitlements through its webhooks.
- **Identity and cross-platform policy.** Whether a purchase on iOS unlocks Android, and how you detect double subscriptions, is a product and backend decision.
- **Reporting, tax and reconciliation.** Libraries give gross figures and estimates; finance still needs store reports.
- **Hard-to-test scenarios.** Family Sharing, storefront changes and long grace periods cannot be fully reproduced in sandboxes, and IAP automation remains limited.
- **Support process and pricing experiments.** Runbooks, customer messaging and grandfathering plans are organisational work.

### How to apply it

1. Choose early: RevenueCat if the team has no billing backend or sells on several platforms; `expo-iap` plus your own server if billing is core and you have the people to own it.
2. Make the server the source of truth: validate purchases server-side, ingest store notifications into a durable queue first, call `logIn` (or your equivalent) with your user ID, and have the app read entitlements rather than receipts.
3. Keep products, prices and paywalls remote, never in the binary, and use subscription groups and offers sparingly so experiments do not leave permanent debt.
4. Write a test matrix covering purchase, restore, upgrade, downgrade, crossgrade, cancel, refund, grace period, account hold and out-of-app changes; run it with sandbox and license testers on real devices each release, and filter sandbox events by environment on the backend.
5. Give support a runbook (refunds go through Apple or Google, platform switches, restore steps) and route IAP complaints and reviews to the owning engineers.
