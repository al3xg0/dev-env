---
name: react-native
description: >-
  React Native and Expo, from the first screen to an app at scale. Use when writing screens and components, styling, Expo Router navigation, lists, TextInput, AsyncStorage or local notifications; when taking an app to the stores (development builds, app.config.ts, config plugins, Zustand, forms, Reanimated 4, Gesture Handler 3, jest-expo and Maestro, EAS Build, Submit and Update, signing, TestFlight, Google Play); or when designing anything hard to undo once shipped in a store binary (old app versions, forced upgrades, OTA updates, offline and retries, deeplinks and push, crash reporting, accessibility, localisation, feature flags, performance, app size, React Native versus native or Kotlin Multiplatform). Also trigger on "Text strings must be rendered within a <Text> component", "Expo Go doesn't support this library", "runOnJS is deprecated", "eas update", "runtimeVersion", "can we just roll it back" or "the app is slow on Android".
---

# React Native with Expo

Written against Expo SDK 58 (React Native 0.88, React 19.3). New SDKs ship three times a year: check the current SDK
and install packages with `npx expo install` so versions match it.

## Which reference to load

| Task | Load |
|---|---|
| Starting a project, screens, styling, Expo Router basics, lists, input, AsyncStorage, notifications, dates and timers | `references/fundamentals.md` |
| Moving off Expo Go: development builds, config, auth and protected routes, state, animation, gestures, testing, performance, EAS and store release | `references/production.md` |
| Anything hard to undo in a shipped binary, scaling process and teams, choosing React Native | `references/at-scale.md`, then the file it points to |

## The one idea behind all of it

A mobile release is a binary on users' phones. You cannot roll it back, users update late or never, and stores review
what you ship. Before shipping anything, ask: if this is wrong, how do we turn it off, and how long do old versions
keep running it?
