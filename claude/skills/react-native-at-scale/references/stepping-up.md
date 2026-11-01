# Stepping up: experiments, quality and operations


## Experimentation

- Revenue-bearing apps A/B test even small changes. A full system covers flags, bucketing, staged rollout, analysis, regression detection and post-experiment analysis; at scale experiments interfere with each other.
- Small and mid-sized teams buy (Firebase Remote Config, LaunchDarkly, Optimizely, Split, plus product analytics such as Amplitude). Large companies often build because data, regulation and scale are specific to them.
- Track live experiments so they do not collide; PMs or data scientists usually own design and bucketing, engineers own correct implementation.
- Experimenting on every change, bug fixes included, catches surprises (a "fix" that confused users and cut conversions). Worth it when a 1% drop in a key metric is very costly; overkill for small apps.

## Feature flag hell

- Dependent flags: a sub-feature at 50% inside a main feature at partial rollout reaches far fewer users than planned. Map dependencies in rollout plans.
- Conflicting flags: each team tests only its own flag; both on together breaks.
- Stale flags: dead branches pile up because deleting a live path cannot be quickly undone on mobile.
- Automate removal once a flag reaches 100% (generate the PR). That only works with one consistent flag coding pattern, enforced by lint or an opinionated shared library.
- Do not build your own flag system without a strong business case; a facade over vendors lets you switch or fall back.
- **React Native:** one typed `useFlag("key")` wrapper; a flag registry with owner and removal date; lint banning direct SDK calls; test the matrix of flags touching one screen; a scheduled codemod for fully rolled-out flags.

## Performance

- Rarely matters for small apps, increasingly as app and team grow; stores rank slow apps lower.
- Common bottlenecks: startup creep (every team adds "one small thing" at launch; someone must own startup time and its regression tests), too many parallel requests (priorities and limits), poor networks, battery drain, ANRs (blocked UI thread), slow and frozen frames, animations on old devices.
- Measure per screen; slow screens are often client and backend together. Profile the client first, remove redundant calls, then fix slow endpoints.
- Manual profiling is a start; sampled real-world measurement scales better (screen, network and function latency, split by device class, alerting owners). Sample beta and a small share of production, since measuring costs performance.
- Network hygiene: throttle the network in employee builds on a set day; drop a share of requests and inject latency in dev builds to force minimal round trips, good loading states and idempotent mutations.
- Measure: startup over time, screen load, network latency and errors per endpoint, parallel requests, memory, local storage size, dropped frames. Use p95 by default, p99 at very large scale.
- Production monitoring alone is weak on mobile (no instant rollback); add automated performance tests to catch regressions before release.
- **React Native:** cold start to first interactive screen, JS bundle evaluation, JS and UI thread FPS, list virtualisation (FlashList, FlatList tuning), image decoding. Profile release builds with Hermes on low-end Android. Defer non-critical startup work, batch requests, sample production at p95 (Sentry, Firebase Performance).

## Analytics, monitoring and alerting

- Teams alert on crashes but neglect business flows. Plan analytics events during design and keep them identical across platforms.
- Business event monitoring: define critical events with PMs and data scientists (sign-up, add payment method, checkout, errors), build real-time cross-platform dashboards, allow drill-down by region and feature.
- Metrics can be wrong for years unnoticed (DAU counted differently per platform). Certify the metrics money decisions depend on: written definition and edge cases, data and technical specs, tests, sign-off. Verify with anomaly detection, cross-checks against other data, and UI tests asserting events reach the server. Keep monitoring after launch.
- Alerting: crash alerts to the pager are the norm; add health-metric checks at each rollout step, then business anomaly alerts. Noise is the main problem (regional cycles, real-world events); tune before paging people.
- **React Native:** one analytics module with a typed event schema (one emitter, identical payloads on both platforms); E2E tests that assert key events fire.

## Mobile on-call

- Once alerts exist, someone with context must be reachable. Mobile-only rotations work for large teams; be wary of fewer than five people.
- A rotation is not enough: an incident process (severity, escalation, incident lead, separate comms and investigation), practised; postmortems with timeline, impact, root cause and tracked actions, shared widely.
- Merge mobile and backend rotations only when runbooks cover most alerts.

## Code quality checks

- The shorter the feedback loop, the better: formatting and linting before review, custom rules for team patterns and architecture boundaries, static analysis, coverage per change.
- Lint fatigue: warnings pile up and get ignored. Make lint errors fail the build, or provide auto-fixes.
- Prefer good-enough off-the-shelf tools over custom ones; every tool has a setup and upgrade cost.
- **React Native:** ESLint with type-aware TypeScript rules, react-hooks and react-native plugins, Prettier, `tsc --noEmit` in CI, custom boundary rules, warnings as errors in CI, SwiftLint and ktlint for native code, Jest coverage on PRs.

## Compliance, privacy and security

- Know the rules that apply: GDPR and local privacy law, PCI DSS for cards, HIPAA for health, accessibility law for public-sector work. PII visible only to those who need it.
- Do not log PII, or anonymise it. Publish logging guidance, audit logs, scrub PII from bug report screenshots.
- Audit third-party SDKs (often non-compliant by default), consent flows, and real network traffic with mitmproxy or Charles.
- Train privacy and security champions in the team; review early, as staying compliant is cheaper than getting there late.
- Security: OWASP Mobile Top 10 and MASVS training, CI scanning for hardcoded secrets and dangerous functions, external pen testing.
- **React Native:** the JS bundle is readable, so no secrets in it (including `EXPO_PUBLIC_*`); tokens in `expo-secure-store` (Keychain on iOS, Keystore-encrypted storage on Android), never AsyncStorage; strip PII from Sentry breadcrumbs and analytics; audit npm packages that pull in native SDKs; secrets scanner in CI.

## Client-side data migrations

- Writing the migration is the easy part. Test with realistic data from power users, test upgrades from many old versions (users skip releases), log and alert on migration outcomes from the client, and plan support and fallback for failures.
- A migration that corrupts data can leave users stuck with no client-side rollback; reinstalling may be the only fix.
- Prefer the backend as source of truth so the client can re-download instead of migrating.
- **React Native:** explicit versions on every persisted store (SQLite, WatermelonDB, MMKV, persisted Zustand or Redux with `version` and `migrate`), migrations chained from every historic version, failures reported to crash reporting, a reset-and-resync escape hatch.

## Forced upgrading

- Reasons: retiring API versions, testing and support cost of old versions, urgent fixes and security issues that must reach everyone.
- Patterns: a rolling window of supported versions; soft (skippable) and hard prompts configured remotely and targeted by OS, app version or device.
- Build it before you need it: a version shipped without the check can never be prompted. Exercise it in production so you know it works.
- Android has an in-app update API; iOS needs a homegrown check.
- Decide policy for users on devices that cannot run new versions, and agree the strategy with product and business.
- **React Native:** a minimum-version check (remote config or a version endpoint) with soft and hard thresholds in the first release, working without OTA; separate thresholds for binary and OTA bundle.

## App size

- Bigger apps get fewer installs and more uninstalls, especially on low-storage devices and in emerging markets. iOS has a cellular download limit; crossing it costs installs.
- Android app bundles are much smaller than universal APKs.
- Lite apps (vector images, no heavy frameworks, server-driven payloads) are an extreme option with a dedicated-team cost.
- Someone must own size, usually the platform team; size checks in CI catch stray assets. Installed size grows through caches: cap them.
- **React Native:** track APK, AAB and IPA size per PR; Hermes and ABI splits; remove unused native dependencies; vector or remote assets; inspect the JS bundle with a visualiser; cap image and HTTP cache sizes.
