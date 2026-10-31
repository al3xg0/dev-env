# Languages and cross-platform approaches


## Adopting new languages and frameworks

- The more complex the app, the riskier swapping a language or core framework (networking, DI, shared logic). An early all-Swift rewrite nearly failed on binary size alone.
- Evaluate: maturity and API stability, comparable success stories, size of future migrations, engineer enthusiasm and the reasons of sceptics, concrete risks to customers and business.
- Pilot small and limit the blast radius (a low-traffic area, an employee-only build). Scale evaluation effort with the engineers and revenue affected. Always keep a plan B.
- **React Native:** the same rule for a new navigation or state library, a major native dependency, or moving to Expo (the New Architecture and Hermes are no longer choices: they are the only architecture and default engine): one screen or internal build first, measure size and startup, keep a rollback path.

## Kotlin Multiplatform

- Shares Kotlin business logic across Android and iOS while UI stays native. Natural for Android engineers and close to Swift.
- Downsides at the time: immaturity, tooling gaps at scale, missing libraries. On iOS, ship one wrapper framework per app rather than one per Kotlin module, and decide whether iOS engineers build Kotlin locally or consume prebuilt binaries.
- **React Native:** KMP is the main alternative when you want shared logic with native UI; RN shares UI too. Mixing them doubles the toolchains.

## Shared business logic

- Time saved is usually overestimated (both platforms still need testing). The real wins: consistent behaviour, one place to maintain, fewer iOS and Android silos.
- Options: shared architecture with separate code (same structure and vocabulary in Swift and Kotlin, enables cross-platform review); shared C++ (proven for performance-heavy and desktop-shared logic, but few mobile engineers know it); Go Mobile, J2ObjC or shared JS (little adoption in complex apps).
- Sharing has real overhead: one large company abandoned shared C++ because custom tooling, platform differences and hiring cost more than writing it twice. A shared language other than Swift or Kotlin tends to cost you strong native engineers.
- **React Native:** the shared layer is TypeScript. Keep domain logic in plain TS modules free of React and native APIs so it stays testable and portable; isolate platform differences in `.ios.ts` / `.android.ts` files or native modules.

## React Native, Flutter and native

- Shared-logic approaches keep UI native; RN, Flutter and Cordova share UI and give up some UI-level control.
- Why teams want it: faster features, one engineer shipping both platforms, identical behaviour, unified design, hot reload and shipping fixes without the store.
- As of 2021: Flutter had the most momentum for whole apps (Dart is the cost). React Native suited organisations with many JS engineers, often for new or less complex apps; some large companies used it for parts of apps, others left it citing technical and organisational problems. The easier-hiring promise often does not hold.
- Early downsides: an extra layer where bugs can hide (your code, the framework or the OS); native code still needed for advanced features; always behind new OS APIs.
- Later downsides: champions leave and the team doubts the choice; most mobile specialists prefer native; tooling changes hurt; framework limits keep resurfacing.
- Evaluation checklist:
  1. Startup and screen performance, and headroom to optimise.
  2. Dev experience: hot reload, iteration speed, reliable tools.
  3. Tooling: debugging, profiling, tests, static analysis, CI/CD.
  4. Low-end device support and how much business runs on them.
  5. Native look and feel.
  6. Release speed and which quality checks can be automated.
  7. Binary size overhead.
  8. Known limitations and their fix timelines.
  9. Mixing with native code, with tests and analysis on the native side.
  10. Type safety across the framework and native boundary.
  11. Build and test speed.
  12. OTA versioning: targeting JS updates only at binaries that can run them.
  13. Whether the mobile team owns the decision.
- Start from your biggest pain points, not from what other companies chose.
- **React Native:** measure cold start, per-screen time to interactive and JS versus UI thread frame drops on a low-end Android release build; typed native modules (Expo Modules, TurboModules with Codegen); OTA gated by runtime version; keep native engineers on the team and budget for upgrades; plan native modules for new OS APIs.

## Web, PWA and server-driven UI

- Ways to change behaviour without a release:
  - **PWA:** a good upgrade to mobile web, not a replacement for a complex app.
  - **Web views:** easiest for dynamic content. Apple rejects apps that only wrap a website, but web views inside real apps are fine. The cost is UX that does not feel native; optimise the pages hard (payload, server time, bundle size).
  - **Server-driven UI:** the app interprets backend metadata. Metadata is safe with store rules; executable code is not. Keep business logic out of the shell, design v1 several backend versions ahead, and expect versioning and testing to be hard.
- Web views for content that changes often and is not interaction-heavy; server-driven UI for areas with frequent business or regional variation, if you will invest in versioning and testing.
- **React Native:** OTA updates are the "JS from the backend" case: fixes and incremental changes, gated by runtime version. A server-driven layer in RN needs a versioned component registry the server can target.
