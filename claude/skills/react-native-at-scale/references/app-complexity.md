# App complexity


## Navigation architecture

- Neither platform ships navigation that scales; teams reinvent it after coding themselves into a corner, ending with inconsistent modals, toasts and transitions and duplicated navigation code.
- Settle early: which transitions exist, what triggers them, and is navigation independent of app state?
- Map flows (push, pop, modal, dismiss, reset) and check the map matches on iOS and Android.
- Async navigation (login, form submit): define what happens when the user leaves mid-way, and test it.
- One navigation framework and one set of presentation conventions for the whole app. Plan phone versus tablet layouts up front.
- **React Native:** one navigator setup (Expo Router or React Navigation); serialisable, minimal params (ids, not objects); auth gating driven by state, not imperative resets scattered around; route map shared with the deeplink config.

## Application state and event-driven changes

- Mobile has more states than web: locking, switching apps, background, offline. In big apps rare event combinations cause the worst bugs (a background push changing a component as the user locks the screen), often across teams' components.
- Apply the state rules: immutable state, models that emit changes.
- Record invalid states with enough to replay them: a bug reporter for beta users that attaches the event sequence and logs. Full session replay is the ideal; on native you mostly build it.
- Log state transitions and inbound events with timestamps as breadcrumbs. Assert on impossible states and report them as non-fatal errors rather than rendering garbage.
- **React Native:** explicit state machines or reducers for complex flows; attach store action logs or query-cache events to crash and bug reports.

## Localisation

- Platform tooling bundles strings in the binary, so a wrong string needs a release. The more the backend localises, the thinner the client and the faster the fixes.
- Block the release train on missing translations (automated check).
- Keep wording identical across platforms with shared keys and tooling; vendors (Phrase, Lokalise, Crowdin, Transifex and others) beat building your own.
- Brand fonts often lack glyphs for some languages: map a fallback font per locale, the same on both platforms.
- Currency formatting differs between iOS and Android in some locales: let the server format money, or use one shared formatter, and never do currency maths in floats on the client. Same care for dates.
- Right-to-left can need layout changes, not just mirroring; involve native speakers.
- Stress-test verbose locales (German, Japanese). Snapshot tests per locale and pseudo-localisation (accented, padded, bracketed strings) expose layout bugs and give translators context.
- Keep a do-not-translate list for brand terms. Define the workflow for string changes (who reviews, does it justify a release).
- Never concatenate translated fragments or hardcode text widths.
- **React Native:** i18next or similar with ICU plurals, `Intl` for dates and numbers (check Hermes `Intl` coverage), `I18nManager` for RTL, screenshot tests with a pseudo-locale.

## Modular architecture and dependency injection

- Large apps split into team-owned modules (platform owns networking, payments team owns payment components), mirroring team structure.
- DI makes code unit-testable by passing in fakes. Start with manual constructor injection; adopt a container only when wiring gets laborious or cycles appear.
- Modules depend on interfaces, not concrete implementations owned by other teams.
- **React Native:** inject services through function parameters, factories or context providers; native SDK wrappers behind interfaces; import boundaries enforced by lint in a monorepo.

## Automated testing

- Test types: unit (fast, isolated), integration (several units, often a module's public API), snapshot (render and compare against a reference image), UI (drive the app; slowest).
- Unit tests on business logic plus code review is the baseline beyond a few engineers on a complex app. For untested legacy code, add integration tests around it and unit tests for new code; retrofitting unit tests is rarely worth it.
- Snapshot tests catch unintended UI changes cheaply; start with core flows. Thousands of reference images slow the repo; store them outside it if needed.
- UI tests past 20 to 30 get slow: use page object or robot patterns, parallelise, detect flaky tests, track cost versus value, and revisit whether lower layers are doing their share.
- Mocked network data gives speed and determinism but drifts from reality: generate mocks from contracts or recorded fixtures and detect drift. Organise test data by use case.
- Typical shape across large apps: a large unit base, many snapshots, very few blocking E2E tests.
- Real devices: cloud device farms are more practical than an in-house lab for most.
- **React Native:** Jest and React Native Testing Library for unit and component tests, screenshot tests for core screens, Maestro or Detox for a short list of critical E2E flows, MSW or a mock server for the network. Fast suites on every change; slow suites nightly or pre-release.

## Manual testing

- Goal: main always shippable, with as little dependence on manual testing as possible.
- Answer: who tests (engineers, in-house QA, vendors, or a mix; calculate engineer time spent), where instructions, accounts and test data live and who owns them, and what blocks a release.
- Last-minute regressions mean testing started too late: test continuously and in parallel with development, and budget time to fix, not only to test.
- Manual testing stays essential for camera, NFC and other physical-world input, end-to-end payments (fraud systems block automation; pair with monitoring and staged rollouts), and exploratory testing by skilled QA.
- Every manual case has an owner, written steps and test data. A deterministic check run every release should be automated.
