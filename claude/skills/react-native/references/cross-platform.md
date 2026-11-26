# Languages and cross-platform approaches

Each section: the challenge, what React Native and Expo give you, what they do not solve, and how to apply it. Written against Expo SDK 58 and React Native 0.88 (New Architecture only).

## Adopting new languages and frameworks

**The challenge.** Tooling keeps changing, and each new language, framework or approach promises to fix mobile pain points: Objective-C or Swift, Java or Kotlin, a write-once framework such as Flutter, React Native or Cordova, or shared business logic in Kotlin, C#, C++ or another language. The right answer depends on constraints and the trade-offs a team accepts across iOS, Android and possibly other platforms. There is no simple rule for when to adopt something new, and research does not prevent regret. The more complex the app, the riskier a new language or a switch of core framework (networking, dependency injection, cross-platform business logic) becomes; an early all-in move to a young language can surprise a team with costs such as a much larger binary. Evaluation effort should match the size of the change and its risk, and it covers the same ground as evaluating a cross-platform framework, plus maturity (API stability, comparable success stories), future migrations of existing code, engineering enthusiasm and scepticism, and what could go wrong for the app, customers and business. A small pilot answers questions about usability, obvious issues and tooling, and any trial should limit the blast radius: a less important part of the app, an app with fewer users, or employees only. Always keep a plan B.

### What React Native gives you

- **A constant stream of "new framework" decisions inside one stack.** In React Native the question is usually a library or a major version (Expo Router, Reanimated 4, FlashList 2, Gesture Handler 3) rather than a language. The same evaluation applies at a smaller scale.
- **Low blast radius tools.** Internal distribution builds (`"distribution": "internal"`), TestFlight groups and Play internal tracks for staff-only trials; EAS Update with `--rollout-percentage` to expose JavaScript changes to a slice of users; `expo-brownfield` to try React Native on one screen of a native app.
- **Maturity signals.** The React Native Directory lists library platform and New Architecture support, and `npx expo-doctor` flags packages that do not fit the project's SDK.
- **A predictable upgrade path.** `npx expo install expo@^58.0.0`, then `npx expo install --fix` and `npx expo-doctor`, with an SDK release three times a year.

### What it does not solve

- **Platform-wide changes you cannot pilot.** The New Architecture became the only architecture in React Native 0.82, and Hermes is the default engine. Moves like these apply to the whole app at once, so the "one screen first" rule does not work for them; staying on an old version is the only alternative.
- **The decision to adopt React Native itself.** That is the cross-platform evaluation checklist, and it carries the biggest risk of all.
- **Enthusiasm and scepticism.** Web engineers may welcome React Native while native engineers resist it; that has to be surfaced and discussed, not assumed away.
- **Exit cost.** Leaving React Native, or a core library such as a state or navigation framework, later is expensive; know what plan B would cost before starting.

### How to apply it

1. Write a one-page evaluation for any new core library or framework: maturity, migration of existing code, team appetite, risks and the plan B.
2. Pilot in a low-traffic screen or an internal build, and measure startup, size and crash rate against the current version.
3. Roll out JavaScript-level changes with EAS Update rollouts, and native-level ones through staged store rollouts.
4. For upgrades that cannot be piloted (React Native, SDK, engine), branch, upgrade, run the full test suite and ship to staff first.

---

## Kotlin Multiplatform and KMM

**The challenge.** Kotlin Multiplatform shares code written in Kotlin and compiles it to JVM libraries for Android and servers, native frameworks for iOS and desktop, and JavaScript for web front ends and back ends. The typical model shares business logic and keeps each platform's UI native. KMM was a tooling layer on top for mobile, adding IDE integration, better debugging and CocoaPods support. Several large companies used it in production. Its appeal: Android engineers already write Kotlin, iOS engineers find it close to Swift and gain Android skills, the UI stays fully native unlike Flutter or React Native, and JetBrains and Google back it with first-class IDE support. The downsides at the time came from immaturity: experimental tooling, breaking changes, tooling gaps for large teams and few supported libraries. Common concerns were stability and long-term commitment, dependency management (Android modularisation works as usual; on iOS, Kotlin modules are wrapped into one Xcode framework, so each combination of modules needs its own wrapper framework, and teams must choose between building Kotlin locally and consuming prebuilt binaries), and the iOS developer experience, where Swift calls the framework directly through an Objective-C interface rather than a separate runtime.

### What React Native gives you

- **A different model, not a competitor for the same slot.** React Native shares UI as well as logic, in TypeScript. Kotlin Multiplatform shares logic and leaves UI native. A team choosing between them is really choosing whether to share the UI layer.
- **A way to use KMP code from React Native.** A KMP library is ordinary Kotlin on Android and an Xcode framework on iOS, so an Expo module can wrap it: Kotlin calls it directly, and the Swift side links it through `vendored_frameworks`, as with any third-party framework. This is how shared Kotlin domain logic (for example, a pricing or offline sync engine also used by native apps or a server) can reach a React Native app.
- **Shared TypeScript logic as the default alternative.** If all clients are React Native or web, business logic in a TypeScript workspace package already serves every platform without a second language.

### What it does not solve

- **Two shared languages.** Combining KMP with React Native means Kotlin and TypeScript, two toolchains and a hand-written module boundary. Use it only when the Kotlin code must also serve native or server clients.
- **No first-party integration.** Neither React Native nor Expo documents a KMP integration path; the module wrapper is yours to build and maintain.
- **iOS interop limits.** Kotlin's Swift export is still Alpha, so iOS consumes KMP through Objective-C headers by default, with the usual awkward types.
- **The comparison has moved.** The core KMP technology is Stable for Android and iOS, and Compose Multiplatform is Stable on iOS, so KMP can now share UI too. That makes it a full alternative to React Native rather than only a logic-sharing option, and a cross-platform evaluation should include it.

### How to apply it

1. Decide first whether UI sharing is a goal; if not, compare KMP with keeping two native apps, not with React Native.
2. If a KMP library already exists for native or server clients, wrap it in one local Expo module with a small, typed API.
3. Build the KMP iOS framework in CI and consume it as a prebuilt binary, so React Native engineers do not need the Kotlin toolchain.
4. Otherwise keep shared logic in a TypeScript package, and revisit only if a non-JavaScript client needs it.

---

## Cross-platform feature development

**The challenge.** Writing the common parts of an app once and reusing them on iOS and Android has benefits: less time per feature (usually less than expected, since both platforms still need testing), no inconsistencies in business logic between platforms, one codebase to maintain, and fewer iOS and Android silos. Approaches include a shared architecture with separate codebases (shared terminology, component generators and lint rules on both sides), which enables joint planning, cross-platform code review and engineers working on both platforms, at the cost of a heavy structure that many find limiting. Shared C++ libraries are battle-tested for games, audio, video and other performance-heavy work, and also reach Windows, macOS and Linux, but need generated bindings (for example with Djinni) and a pipeline for them, and most mobile engineers are not fluent in C++. Other options such as Go Mobile, J2ObjC or JavaScript run in each platform's interpreter work but are rarely used for complex apps. The overhead is easy to underestimate: custom frameworks, a non-standard environment, platform differences and the cost of training and hiring can make sharing more expensive than writing code twice, and choosing a language other than Swift or Kotlin risks losing the strongest native engineers.

### What React Native gives you

- **Sharing goes further than business logic.** UI, navigation, state, networking and tests are shared by default, so the time saving is larger than with logic-only sharing, though both platforms still need testing.
- **Consistency by construction.** One implementation means iOS and Android cannot disagree on business rules unless someone adds a `Platform.OS` branch or a platform file (`.ios.tsx`, `.android.tsx`).
- **C++ when you need it.** Cross-platform Turbo Native Modules can be written purely in C++, with Codegen generating the scaffolding from a TypeScript spec, which is the documented way to share performance-sensitive native code across Android and iOS.
- **Desktop and other platforms.** React Native for Windows and React Native for macOS are maintained by partners, and React Native Web, React Native tvOS and others by the community, so TypeScript logic and some UI can reach clients beyond phones.

### What it does not solve

- **The overhead of a non-native stack.** A JavaScript runtime, Metro, native module interop and a second toolchain are exactly the non-standard environment that costs training and hiring. It is cheaper if the team already knows React.
- **Native engineer retention.** Strong iOS and Android specialists may leave if their work becomes mostly TypeScript; keep real native work (modules, performance, platform features) on their plate.
- **Platform-specific behaviour.** Shared code still needs per-platform testing, and native modules still differ per platform unless written in C++.
- **Sharing with non-React clients.** Logic in TypeScript does not help a native Swift or Kotlin app; that needs C++ or KMP.

### How to apply it

1. Keep business logic in plain TypeScript modules with no React or React Native imports, so it can serve web or tests directly.
2. Track `Platform.OS` branches and platform files as a metric; each one is a place the platforms can drift.
3. Use a C++ Turbo Module only for performance-critical or existing C++ code, and the Expo Modules API in Swift and Kotlin otherwise.
4. Budget for training, and give native specialists ownership of modules and performance work.

---

## Cross-platform app development versus native

**The challenge.** Sharing only business logic keeps the UI native; frameworks such as Flutter, React Native or Cordova share the UI too, which can limit apps that want close control of native UI. The motivations are the need for speed, one engineer shipping to both platforms instead of two coordinated changes, identical behaviour on iOS and Android, one look and feel favoured by design, and changes and fixes without waiting for the store train. In 2021 Flutter had the most momentum, backed by Google's own apps; React Native was seen as a fit for teams with many web and JavaScript engineers, often used for MVPs, simpler apps or parts of apps after high-profile departures, with more cautious adoption by large companies; Xamarin, becoming .NET MAUI, suited C# shops; and Cordova, Ionic and NativeScript had fewer complex case studies, held back by performance and tooling. The promises are lower cost, reuse (perhaps including web), novelty, identical functionality, and the belief that web engineers make hiring easier, which often proves false. The immediate downsides are an extra layer to debug, native code still needed for advanced and platform-specific features, and always trailing new OS APIs. The later ones are that the engineers who championed the move may leave, most mobile engineers prefer native, tooling changes hurt more than expected, and the framework will keep limiting UX, performance or what is possible. Large apps mostly stay native or share only logic, because of tooling and UI control. Evaluate your own pain points and constraints instead of copying other companies, against thirteen areas.

### What React Native gives you

1. **Performance versus native.** Rendering uses real platform views through Fabric, and the New Architecture (the only architecture since 0.82) removes the old asynchronous bridge in favour of JSI. Hermes is the default engine and compiles JavaScript to bytecode at build time, which helps startup. Reanimated 4 and Gesture Handler 3 run animation and gesture work on the UI thread. Leeway to optimise is good but not native-level: startup still includes loading the JavaScript bundle, and heavy JavaScript work competes for one thread. Measure in release builds.
2. **Development experience.** Fast Refresh applies most changes in the running app without a rebuild, and a development build with `expo-dev-client` only needs rebuilding when native code changes. This is React Native's strongest point against native.
3. **Tooling.** React Native DevTools covers console, breakpoints, network (since 0.83), performance traces, memory heap snapshots and the React component tree and profiler; Xcode and Android Studio remain for native code. `jest-expo`, React Native Testing Library and Maestro cover testing, `npx expo lint` covers linting, TypeScript covers static analysis, and EAS Build, Submit, Update and Workflows cover CI/CD. Mature, with two toolchains to own.
4. **Device support.** Expo SDK 58 supports Android 7 and later and iOS 16.4 and later. Low-end Android is where React Native needs the most care (list virtualisation with FlashList, fewer re-renders, and the React Compiler, turned on with `experiments.reactCompiler: true`, with Babel set up automatically from SDK 54); test on real low-end devices.
5. **Native look and feel.** Core components are native views, and native navigation is available (`expo-router/native-tabs` from SDK 58, native stacks via react-native-screens). `@expo/ui` exposes SwiftUI and Jetpack Compose components directly. Custom JavaScript components can still feel generic; that is a design choice, not a constraint.
6. **Release speed and quality.** EAS Submit automates store uploads, EAS Update ships JavaScript fixes over the air with staged rollouts and rollbacks, and Maestro flows run in EAS Workflows. Store review still applies to every native change.
7. **Binary size.** React Native and Hermes add a fixed native overhead to every app, and each native dependency adds more. Expo Atlas (`EXPO_ATLAS=true npx expo start`) shows what is in the JavaScript bundle. Measure the base cost before deciding; it matters most for size-sensitive markets.
8. **Platform limitations.** New iOS and Android APIs reach React Native libraries after a delay. Expo ships three SDKs a year, and the Expo Modules API lets you call a new API from Swift or Kotlin yourself the week it ships, so the gap is a small module, not a blocker.
9. **Mixing with native code.** Good: local Expo modules (`npx create-expo-module --local`), config plugins for native project changes, and `expo-brownfield` for adding React Native to a native app. Native tests and static analysis still run in Xcode and Gradle, separately from Jest.
10. **Type safety across the boundary.** Turbo Modules generate native interfaces from a TypeScript spec through Codegen, so the boundary is typed on both sides. Expo modules declare types in Swift and Kotlin and in a hand-written TypeScript file, which can drift; keep the module surface small and test it.
11. **Build performance.** JavaScript builds are fast. Native builds are Gradle and Xcode, helped by precompiled Expo modules, the fingerprint-based remote build cache and EAS caching. Clean native builds are no faster than a native app's.
12. **Versioning of hot-reload-style updates.** This is solved: EAS Update matches updates to builds by `runtimeVersion` (policies `appVersion`, `nativeVersion` or `fingerprint`) and by channel, so code only reaches binaries that can run it, and rollouts can target a percentage.
13. **Autonomy of the mobile team.** Nothing technical here. If React Native is imposed on the mobile team rather than chosen by it, expect the retention and motivation problems listed above.

### What it does not solve

- **Native expertise.** Every serious React Native app still needs engineers who can write and debug Swift, Kotlin, Gradle and CocoaPods.
- **The extra layer.** A bug on one platform may sit in your code, a library, React Native or the OS; finding which takes time.
- **People risk.** Champions leaving, native engineers preferring native, and the cost of switching tools are organisational problems no framework fixes.
- **The comparison set.** Flutter and Kotlin Multiplatform with Compose Multiplatform (now Stable on iOS) are the main alternatives today; evaluate them against the same thirteen areas rather than against the 2021 picture.

### How to apply it

1. Write down the two or three pain points you are trying to solve and the constraints (team skills, UX bar, size, low-end devices).
2. Score React Native and the alternatives on the thirteen areas with a prototype of one real, demanding screen, measured in release builds on a low-end Android device.
3. Measure the baseline binary size and cold start of an empty app against your current one.
4. Make the decision with the mobile engineers, record it with a plan B, and revisit it after the first two production releases.

---

## Web, PWA and backend-driven mobile apps

**The challenge.** Being unable to update an app instantly causes many of the pain points covered earlier (mistakes that are hard to revert, the long tail of old versions), and several approaches avoid the store for at least part of the app. Progressive web apps use browser APIs for a native-like experience (an app shell, push on Android, asset caching) and are a natural step for a mobile website, but are unlikely to replace complex native apps. Embedding web screens with WKWebView or Android's WebView is the most common approach for dynamic parts; Apple rejects apps that only wrap a website, but web views alongside real app logic are fine. Offline support means loading web content from local data and syncing back later; the experience rarely feels native (some platform transitions cannot be reproduced); Android web views have gotchas on old devices; older iOS web views were slow; and the web pages need heavy optimisation of payload, server time and bundle size. Backend-driven apps go further: a native shell interprets instructions from the backend, which suits areas that change often or vary by region or user segment. Sending executable code is risky because Apple's rules on downloaded code can change; sending metadata the shell interprets is the safer, more common route. The shell must hold no business logic beyond interpretation, must be designed several backend versions ahead, cannot itself be updated easily, and the backend must send each app version messages it understands, which forces decisions about API versioning and makes testing hard.

### What React Native gives you

- **The "magic wand" built in.** EAS Update replaces the JavaScript and assets of a React Native app without a store release, with channels, runtime versions, staged rollouts and rollbacks. The limit is policy: Apple's guideline 2.5.2 bars downloading code that introduces or changes features, and Expo's docs say behaviour changes need review, so use it for fixes and keep features in store releases.
- **Web from the same codebase.** React Native Web and Expo Router build a website from the app's code, rendered statically (`web.output: "static"`) or on the server. Expo documents PWA setup (manifest, icons, Workbox service workers), while recommending native apps for the best offline support.
- **Embedded web done more natively.** `react-native-webview` for full web screens, and DOM components (`'use dom'`) for embedding individual React DOM components in a native screen; from SDK 56 they use `@expo/dom-webview` with no extra install. This allows moving a web feature into the app one component at a time.
- **A good host for server-driven UI.** A backend-driven screen in React Native is a JSON schema plus a registry mapping each node type to a component, so the shell is ordinary TypeScript and itself updatable over the air within the same runtime version. React Server Components in Expo Router go further, rendering components on the server, but are experimental and in beta.

### What it does not solve

- **Web view UX and offline.** Embedded web content still lacks native transitions, needs its own offline storage and sync, and needs web performance work. DOM components are still web views.
- **Versioning the contract.** The backend must know which component types each app version understands. Send the app version and `runtimeVersion` with each request, render unknown node types as a safe fallback, and never remove a type while supported versions use it.
- **Testing combinatorics.** Every backend response must be tested against every supported shell version; snapshot the payloads and render them in Jest per version.
- **Store risk.** Over-the-air updates and backend-driven screens do not exempt the app from review rules; changing what the app does without review can get it removed.

### How to apply it

1. Use EAS Update for fixes with staged rollouts, and keep feature changes in reviewed store releases.
2. Use DOM components or a web view only for content-heavy, frequently changing screens, and measure them on low-end Android.
3. For server-driven screens, define a versioned schema, a component registry with a fallback for unknown types, and contract tests per supported app version.
4. Treat React Server Components as an experiment until Expo marks them stable.
