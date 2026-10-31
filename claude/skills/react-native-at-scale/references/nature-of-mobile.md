# Part I: challenges from the nature of mobile apps (chapters 1 to 12)

Lines marked **RN** are React Native applications, not the book's claims.

## 1. State management

- State changes come from user input, network responses and lifecycle transitions in no fixed order. Most exotic bugs are an untested combination of events leaving state invalid, worst when shared state is mutated by components unaware of each other.
- The OS kills apps that use too much CPU, memory or energy, foreground or background. Save and restore state yourself.
- Keep component and app state tightly isolated; prefer reactive, immutable models that emit changes. Passing state down is tedious, and that friction is the point.
- Global device state (permissions, Bluetooth, connectivity): either each screen listens (duplication, self-contained) or one owner forwards changes (less code, tight coupling). Decide the owner before writing code.
- A bug that only reproduces after a specific sequence of events: suspect shared mutable state first.
- **RN:** server state in a query cache, UI state local, global state in one store with immutable updates; one hook or provider owns `AppState` and NetInfo; persist in-progress work because the JS process can be killed.

## 2. Mistakes are hard to revert

- Users keep a buggy binary until a fix ships and they update. Review takes a day or two on iOS, sometimes longer on Android. Many users update late, skip versions or never update.
- Stores forbid downloaded code that changes functionality; Apple tolerates interpreted JavaScript, which is why OTA tools exist for RN. Turning behaviour off with flags is acceptable to both stores.
- Limit damage: test at every level, run employee and beta builds for about a week before release, put risky work behind remote flags, use staged rollouts with monitoring, and have a force-upgrade mechanism (Android has in-app updates; iOS needs a homegrown check).
- **RN:** EAS Update fixes JS-only bugs fast but cannot fix native code; gate updates by runtime version; still ship a minimum-version gate.

## 3. The long tail of old app versions

- Old versions linger for years unless upgrades are forced. Laggards are often stuck on old devices or OS versions.
- "Non-breaking" backend changes break untested old clients. Prefer generated, strongly typed contracts (GraphQL, codegen) over hand-written parsing.
- Add endpoints instead of changing them; version endpoints (GraphQL evolves the schema instead); deprecate only when per-version traffic says so.
- Track the share of users several versions behind to decide how much compatibility to invest in. Upgrade-test major releases.
- **RN:** generated typed clients validated at the boundary; app version and build on every request.

## 4. Deeplinks

- No platform gives an opinionated framework; the work snowballs as links multiply and is far harder to retrofit on mobile than on the web.
- Questions to settle: do old links still work after navigation changes; does a link arriving in a running app push onto the stack or reset; how do iOS universal links and URL schemes map to Android intents?
- Default to resetting state on entry, with explicit exceptions for flows that must not be interrupted (checkout). Keep a registry of supported links and test it, including against old versions.
- **RN:** one linking config shared with navigation; handle cold start (initial URL) and warm start (URL event); queue links that arrive before auth or data.

## 5. Push and background notifications

- Device tokens from APNs or FCM, stored and used by the backend. Marketing pushes usually go through a vendor (Braze, OneSignal, Airship and similar).
- A push is a deeplink with a message: versioned, tolerant payloads.
- Opt-in may never happen; iOS can still deliver silent background notifications to users who opted out of visible ones.
- Delivery is not guaranteed and ordering is not either; bulk sends get throttled. Silent pushes can replace polling, but carry sequence numbers or timestamps and keep a fallback fetch.
- Never make a core flow depend on a push arriving.

## 6. App crashes

- Capture every crash with context first, then measure crash-free sessions and drive the rate down. Store-native reporting covers only opted-in users; most teams use a vendor (Crashlytics, Sentry, Bugsnag) for breadcrumbs, grouping, alerting and ticket integration.
- Many vendors miss ANRs and out-of-memory kills; track them separately.
- If it reproduces anywhere, fix it. Prioritise by sessions affected times the importance of the flow, not by stack trace.
- Targets: 99.9% crash-free is typical, 99.99% world-class.
- **RN:** capture JS errors and native crashes; upload source maps, dSYMs and ProGuard mappings per build and per OTA update; tag reports with app version, OTA bundle id, device and OS.

## 7. Offline support

- Decide explicitly which flows work offline; start with key flows and expand on feedback.
- The OS may say "online" behind a captive portal; ping known endpoints when it matters. Treat very slow connections as offline and say so.
- Soft timeouts plus retries produce duplicate and out-of-order responses: design for the first request returning late.
- Syncing needs a conflict protocol for parallel offline edits and a connection dropping mid-sync. Use conditional requests (ETags).
- Non-retryable requests: a timeout is not a failure. Idempotency keys, persisted so they survive a crash.
- De-duplicate submits while a request is in flight. Test with Network Link Conditioner and emulator network throttling.
- **RN:** NetInfo plus a reachability check; persisted query cache and mutation queue; versioned storage.

## 8. Accessibility

- Large user bases include many people with accessibility needs, and inaccessible apps carry legal risk.
- Agree a WCAG 2.1 depth first. Baseline: usable with VoiceOver and TalkBack, enough contrast on key elements, Dynamic Type and scalable text respected (some OEMs ship larger default fonts).
- Cheap from the start, expensive to retrofit. Put it in designs and design docs, including screen reader focus order.
- Automate what you can (missing labels), add a manual pass to the release process, recruit beta users with accessibility needs, and develop with accessibility features switched on.
- **RN:** `accessibilityLabel`, `accessibilityRole`, `accessibilityState` on every interactive element; never disable font scaling globally; test at the largest text size; lint for missing labels.

## 9. CI/CD and the build train

- Fully continuous deployment to the App Store is impossible because of review. Each platform needs its own pipeline.
- Buy CI unless someone owns it; unowned homegrown CI quietly decays.
- Release train: cut, automated tests, manual tests, translations check, performance tests, dogfood and beta, store upload, staged rollout (iOS phased release, Android percentages). Someone owns the train and a dashboard shows where it stands.
- Cadence: weekly for large mature teams, every two weeks for most, monthly or ad hoc for small apps (bigger releases, more regressions).
- Write go/no-go gates down, then automate them: full UI suite before release, sanity tests by owning teams, missing translations, no new crashes in beta, no memory regressions, no business metric drop during rollout.
- **RN:** a pipeline per platform or EAS Build and Submit, a separate JS lint and test job, OTA updates tracked as part of the train, staged rollouts on both stores.

## 10. Third-party libraries and SDKs

- Dependencies bring breaking changes, vulnerabilities and outages you cannot fix: vendor SDKs have crashed every app embedding them through server-side changes alone.
- Monitor vulnerabilities continuously. Wrap each SDK behind a remote flag that controls initialisation and every call site.
- Major library upgrades are among the riskiest changes: staged rollout, extra dogfooding, watch crashes through the train.
- Before adding a dependency: binary size, risk of blocking a toolchain upgrade, likelihood of abandonment, maintainer responsiveness. Keep an inventory and prune it.
- **RN:** native dependencies also gate RN and Expo SDK upgrades; check New Architecture support first.

## 11. Device and OS fragmentation

- Android: device and OEM-specific bugs (Samsung, foldables, devices without Google Play services, so no FCM). iOS: mild OS fragmentation.
- Use a device lab or a cloud device service; expect unreadable driver-level stack traces.
- Set the minimum OS with data: drop a version when its users' revenue is below the cost of supporting it, unless legally required. Revisit after each major OS release.
- Guard platform-specific APIs with runtime checks.
- **RN:** the RN and Expo SDK raise minimum OS versions themselves; align with them.

## 12. In-app purchases

- Stores take 15% to 30%. Platform models differ (pausing subscriptions on Google, not Apple).
- Client-only validation is simple but abusable (clock changes, modified apps) and hardcodes products in the binary. Validate server side, drive entitlements from the backend, fetch product ids from the backend.
- Store server notifications are the source of truth: your webhook needs near-perfect availability, at least to persist events before processing. Store APIs have unannounced outages.
- Edge cases to cover: cancel and repurchase, trials and grace periods, upgrades, downgrades and crossgrades, promotional offers, refunds, card failures, account hold, paused subscriptions, changes made while the app is closed (reconcile on launch and resume), restore on a new device (iOS transaction ids can change).
- Map store identities to your users. iOS gives developers no way to cancel or refund; say so in support copy.
- Testing: Apple sandbox and StoreKit testing, Play licence testers, documented scenarios and test accounts, real devices for what sandboxes cannot do (Family Sharing, other storefronts).
- Avoid many subscription groups: they lock customers in and reset Apple's reduced second-year rate. Grandfather retired packages for a while.
- Finance will need engineering help with gross versus net revenue, payouts, tax and store accounting calendars.
- **RN:** a maintained IAP library or RevenueCat's SDK; never unlock content purely on the client.
