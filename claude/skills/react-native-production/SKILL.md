---
name: react-native-production
description: Taking an Expo React Native app from Expo Go to the app stores, from Kadi Kraman's Intermediate React Native v2 course (Frontend Masters). Use when structuring Expo Router for a real app (route groups, tabs inside a root stack, modals, onboarding or auth guards, dynamic routes, cold-start deep links), adding global state with Zustand and AsyncStorage persistence, building forms and custom buttons, picking and storing images, moving to development builds with prebuild and Continuous Native Generation, writing app.json and config plugins, adding custom fonts, splash screens, app icons, quick actions or deep links, signing builds, or submitting to the App Store and Google Play. Also trigger on "Expo Go doesn't support this library", "should I commit the ios and android folders", "my font works on Android but not iOS", "back button missing after a deep link", "router.navigate doesn't go back", "eas build", "eas update" or "TestFlight". Builds on react-native-fundamentals; for release process, monitoring and architecture at scale, use react-native-at-scale.
---

# Production React Native with Expo

Source: Kadi Kraman, Intermediate React Native v2 (https://kadikraman.github.io/intermediate-react-native-v2-course/). The course spans Expo SDK 51 to 54. Sections marked **(not from the course)** are general Expo practice added to fill gaps; check them against the current Expo docs before relying on details.

## Project baseline

- Blank TypeScript template plus the `@/*` path alias (already in the default template):

```json
{ "extends": "expo/tsconfig.base", "compilerOptions": { "strict": true, "paths": { "@/*": ["./*"] } } }
```

- Restart the editor and Metro after alias, Babel or Router changes: `npx expo start --reset-cache`.
- Every dependency through `npx expo install`.
- Local native toolchain (Xcode, Android Studio) lets you debug native issues and work offline; EAS builds in the cloud when that is not an option.

## Expo Router for a real app

### Route tree

```
app/
  _layout.tsx               root Stack: (tabs), onboarding modal, new modal
  onboarding.tsx
  new.tsx
  (tabs)/
    _layout.tsx             Tabs + guard
    profile.tsx
    (home)/
      _layout.tsx           Stack + unstable_settings
      index.tsx             /
      plants/[plantId].tsx  /plants/:plantId
```

- Put tabs in a `(tabs)` group under a root `Stack`, so top-level modals are not tabs.
- The header belongs to the innermost stack; set `headerShown: false` on the parent so there is never a double header. Pushed detail screens then get a back button for free.

```tsx
// app/_layout.tsx
<Stack>
  <Stack.Screen name="(tabs)" options={{ headerShown: false, animation: "fade" }} />
  <Stack.Screen name="onboarding" options={{ presentation: "modal", headerShown: false, animation: "fade" }} />
  <Stack.Screen name="new" options={{ presentation: "modal", title: "New plant" }} />
</Stack>
```

### Guards (onboarding, auth)

Guard in the layout of the protected group:

```tsx
export default function TabsLayout() {
  const done = useUserStore((s) => s.hasFinishedOnboarding);
  if (!done) return <Redirect href="/onboarding" />;
  return <Tabs>{/* ... */}</Tabs>;
}
```

- On completion update state, then `router.replace("/")` so Back cannot return to onboarding or login.
- **(not from the course)** Expo Router v5+ also offers `<Stack.Protected guard={isLoggedIn}>` as a declarative alternative.
- Hold the splash while checking auth: `SplashScreen.preventAutoHideAsync()` at module scope in the root layout, `SplashScreen.hideAsync()` when ready (both from `expo-router`).

### Dynamic routes

```tsx
const params = useLocalSearchParams();   // values are string | string[]; narrow with typeof
const plant = usePlantStore((s) => s.plants.find((p) => String(p.id) === params.plantId));
const navigation = useNavigation();
useEffect(() => { navigation.setOptions({ title: plant?.name }); }, [plant?.name, navigation]);
if (!plant) return <NotFound />;
```

- Pass ids in params, not objects: `<Link href={{ pathname: "/plants/[plantId]", params: { plantId: id, action: "water" } }}>`.
- `export const unstable_settings = { initialRouteName: "index" }` in a nested stack layout makes a cold-start deep link to `/plants/1` still have `index` beneath it, so Back works.
- Expo Router 4 / React Navigation 7: `router.navigate()` no longer returns to an existing screen. Dismiss modals with `router.back()`.

## State: Zustand with persistence

```sh
npx expo install zustand @react-native-async-storage/async-storage
```

```ts
export const useUserStore = create(
  persist<UserState>(
    (set) => ({
      hasFinishedOnboarding: false,
      toggleHasOnboarded: () => set((s) => ({ ...s, hasFinishedOnboarding: !s.hasFinishedOnboarding })),
    }),
    { name: "app-user-store", storage: createJSONStorage(() => AsyncStorage) },
  ),
);
```

- One store per domain (`userStore`, `plantsStore`); export the entity types from the store.
- Select narrowly, one selector per value: `useUserStore((s) => s.hasFinishedOnboarding)`.
- Actions may be async (copy a file, then `set`).
- SDK 53+: if Zustand fails on `import.meta`, set `unstable_transformImportMeta: true` on `babel-preset-expo` in `babel.config.js`.
- Persisted stores outlive app versions: give them a `version` and a `migrate` function before the first release (see react-native-at-scale).
- **(not from the course)** Server data belongs in TanStack Query, not a Zustand store.

## UI patterns

- Custom button: `Pressable` with `style={({ pressed }) => [styles.button, pressed && styles.pressed]}`, light haptic on press guarded for web.
- Images: bundled with `require("@/assets/x.png")`, remote or file with `{ uri }`; size responsively with `useWindowDimensions()`. `expo-image` for caching and advanced cases.
- Gradients: `expo-linear-gradient`. Status bar style per screen with `<StatusBar style="light" />` from `expo-status-bar`.
- Shadows: `shadow*` props are iOS only, Android needs `elevation`, and the view needs a `backgroundColor` or the shadow lands on its children.
- Forms: controlled inputs, validate on submit, `Number(x)` plus `Number.isNaN`, `keyboardType="number-pad"`, `autoCapitalize="words"`. Wrap in `ScrollView keyboardShouldPersistTaps="handled"` so the first tap on Submit is not swallowed dismissing the keyboard. Long forms: `KeyboardAvoidingView` or `react-native-keyboard-aware-scroll-view`.
- Heavier lists: FlashList.

## Files and media

```sh
npx expo install expo-image-picker expo-file-system
```

```ts
import * as ImagePicker from "expo-image-picker";
import { File, Paths } from "expo-file-system";   // SDK 54 object API

const result = await ImagePicker.launchImageLibraryAsync({ mediaTypes: ["images"], allowsEditing: true, aspect: [1, 1], quality: 1 });
if (!result.canceled) {
  const src = new File(result.assets[0].uri);
  const dest = new File(Paths.document, `${Date.now()}-${src.name}`);
  src.copy(dest);
  save(dest.uri);
}
```

Picker URIs live in temporary storage; copy into the document directory before saving a reference.

## Expo Go versus development builds

- A React Native app is a JS bundle plus a native binary. Expo Go is a prebuilt binary, so it only has the native modules it ships. A development build is your own Expo Go with exactly your native dependencies.
- Needed for: in-app purchases, vision camera, Firebase, quick actions, bundled fonts, custom icon and splash, any library with a config plugin. Switch early.

```sh
npx expo install expo-dev-client
npx expo prebuild --platform ios       # asks for the bundle id the first time
npx expo run:ios                       # or run:android
npx expo prebuild --clean --platform ios   # after any native config change, when native dirs exist
```

- **Continuous Native Generation:** `ios/` and `android/` are generated output. Keep them in `.gitignore`. Committing or hand-editing them opts you into the bare workflow; change native projects through config plugins instead.
- App id (`ios.bundleIdentifier`, `android.package`): reverse domain, globally unique on Apple, permanent once uploaded to a store. Choose it carefully.
- Emulator will not start: launch it from Android Studio's Device Manager. Simulator missing: open Xcode once and accept the download.

## app.json and config plugins

```json
{ "expo": {
  "name": "Plantly", "slug": "plantly", "scheme": "plantly", "version": "1.0.0",
  "icon": "./assets/icon.png", "userInterfaceStyle": "light",
  "ios": { "supportsTablet": true, "bundleIdentifier": "com.example.plantly" },
  "android": { "package": "com.example.plantly",
    "adaptiveIcon": { "foregroundImage": "./assets/adaptive-icon.png", "backgroundColor": "#ffffff" } },
  "plugins": [
    "expo-router",
    ["expo-font", { "fonts": ["node_modules/@expo-google-fonts/caveat/Caveat_400Regular.ttf"] }],
    ["expo-splash-screen", { "image": "./assets/splash.png", "imageWidth": 150, "backgroundColor": "#9CF089",
      "dark": { "image": "./assets/splash.png", "backgroundColor": "#56A082" } }]
  ] } }
```

- Plugins are a string or `[name, options]`; `npx expo install` often adds them for you.
- `name` is the display name; `slug` stays lowercase.
- **(not from the course)** `app.config.ts` can vary name and bundle id per environment (`process.env.APP_VARIANT`). `EXPO_PUBLIC_*` variables are inlined into the JS bundle, so they are public: never put secrets there.

## Fonts, splash, icons

- Fonts: `useFonts` loads at runtime and works in Expo Go; the `expo-font` plugin embeds fonts in the binary (development builds). All Google Fonts are on npm as `@expo-google-fonts/*`; prefer OTF.
- Font family names differ: Android uses the file name, iOS the PostScript name. Rename files to their PostScript name, or `Platform.select({ ios: "Caveat-Regular", android: "Caveat_400Regular" })`.
- Splash (SDK 52+): background colour plus centred image via the `expo-splash-screen` plugin, with a `dark` variant. Full-screen splash images are gone.
- Icons: iOS 1024x1024 PNG without transparency; Android adaptive icon 1024x1024 foreground plus background colour; web favicon 48x48.
- Rebuild with `prebuild --clean`. The iOS simulator caches the old splash: uninstall the app.

## Quick actions and deep links

```tsx
import * as QuickActions from "expo-quick-actions";
import { useQuickActionRouting } from "expo-quick-actions/router";

useQuickActionRouting();
useEffect(() => {
  QuickActions.setItems([{ id: "0", title: "Add a plant", icon: Platform.OS === "ios" ? "symbol:leaf" : "leaf", params: { href: "/new" } }]);
}, []);
```

- iOS quick action icons are SF Symbols. Tell App Review about entry points that only a quick action reaches, or expect a rejection.
- Every Router screen has a URL, so `scheme` gives deep links for free. Query params arrive in `useLocalSearchParams()`.

```sh
npx uri-scheme open plantly://plants/1 --ios
npx uri-scheme open plantly://plants/1\?action=water --android   # escape ? in zsh
```

- Custom schemes are not unique to your app. For production links use Universal Links (iOS) and App Links (Android) with an associated domain.

## Signing

- Android: keystore. Debug builds use the generated debug keystore; release builds use an upload keystore and Play App Signing holds the real key.
- iOS: three build types, each a provisioning profile plus a certificate.

| Build | Install route | Paid account |
|---|---|---|
| Development | Direct to device via Xcode | No (Personal Team) |
| Ad Hoc | Direct, registered device UDIDs only | Yes |
| App Store | TestFlight and App Store only | Yes |

- EAS manages credentials for you; `eas build --local` builds on your machine with EAS-managed signing.

## EAS **(not from the course)**

```sh
npm i -g eas-cli && eas login
eas build:configure                     # writes eas.json: development, preview, production profiles
eas build -p ios --profile development
eas submit -p android
eas update --channel production         # needs expo-updates; the channel is set per build profile
```

- OTA updates replace JS and assets only. Set `runtimeVersion` (`{ "policy": "fingerprint" }` or `"appVersion"`) so an update never reaches a binary missing the native code it needs.
- Keep OTA updates to fixes and incremental changes; new functionality goes through review.

## Store release checklist

1. Accounts: Google Play (one-off fee, identity checks take days), Apple Developer Program (yearly). Paid apps publish the seller's address, so consider a company account.
2. Create the app record in each console.
3. Production build: Android `.aab`, iOS `.ipa` signed for the App Store.
4. Upload: the first Android build goes up manually in Play Console; after that, `eas submit` or the console. iOS via `eas submit`, Transporter or Xcode.
5. Metadata: privacy and data-tracking declarations, description, keywords, countries, pricing.
6. Screenshots at the required sizes; Android feature graphic.
7. Testing tracks: TestFlight internal (no review) and external (short review); Play internal, closed, open. New personal Play accounts need 20 opted-in testers for 14 days before production.
8. Review: give demo credentials, specific permission usage strings, and notes for hidden features. Crash on launch is the classic rejection.

## Further libraries named by the course

Reanimated, Gesture Handler, Skia, Vision Camera, FlashList, NativeWind, Tamagui, react-native-bootsplash, Maestro for E2E, Ignite as a boilerplate, React Native Directory to vet packages.
