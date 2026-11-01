---
name: react-native-production
description: >-
  Taking an Expo React Native app from Expo Go to the app stores. Use for Expo Router in a real app (route groups, tabs in a root stack, modals, protected routes and auth, dynamic routes, cold-start deep links), Zustand with persistence, forms, images and files, development builds and prebuild, app.json, app.config.ts, config plugins and env vars, fonts, splash, icons, quick actions, deep links, Reanimated 4, Gesture Handler 3, testing with jest-expo, Testing Library and Maestro, list and image performance, signing, EAS Build, Submit and Update, and App Store or Google Play release. Also trigger on "Expo Go doesn't support this library", "should I commit the ios and android folders", "runOnJS is deprecated", "estimatedItemSize", "eas update", "runtimeVersion" or "TestFlight". Builds on react-native-fundamentals; for scale and release process use react-native-at-scale.
---

# Production React Native with Expo

Written against Expo SDK 58 (React Native 0.88, React 19.3, Expo Router 58, Reanimated 4, Gesture Handler 3, RNTL 14). New SDKs ship three times a year: check the current SDK, and install everything with `npx expo install` so versions match it.

## Project baseline

- The default template (SDK 55+) puts routes and code under `src/` with the `@/*` alias; the blank template has no alias, so add it:

```json
{ "extends": "expo/tsconfig.base", "compilerOptions": { "strict": true, "paths": { "@/*": ["./src/*"], "@/assets/*": ["./assets/*"] } } }
```

- Routes live in `src/app/` (or `app/` in older projects; both work).
- Restart with a clean cache after alias, Babel, plugin or Router changes: `npx expo start --clear`.
- A local native toolchain (Xcode, Android Studio) lets you debug native issues and work offline; EAS builds in the cloud when that is not an option.

## Expo Router for a real app

### Route tree

```
app/
  _layout.tsx               root Stack: protected (tabs), sign-in, modals
  sign-in.tsx
  new.tsx
  (tabs)/
    _layout.tsx             Tabs
    profile.tsx
    (home)/
      _layout.tsx           Stack + unstable_settings
      index.tsx             /
      plants/[plantId].tsx  /plants/:plantId
```

- Put tabs in a `(tabs)` group under a root `Stack`, so top-level modals are not tabs.
- The header belongs to the innermost stack; set `headerShown: false` on the parent so there is never a double header. Pushed detail screens then get a back button for free.

```tsx
<Stack>
  <Stack.Screen name="(tabs)" options={{ headerShown: false, animation: "fade" }} />
  <Stack.Screen name="new" options={{ presentation: "modal", title: "New plant" }} />
</Stack>
```

### Protected routes and auth (SDK 53+)

Guard screens declaratively with `Stack.Protected` (also `Tabs.Protected`, Drawer). The canonical shape: a session provider, a splash controller inside it, and guards in the root layout.

```tsx
// splash.tsx
import { SplashScreen } from "expo-router";
SplashScreen.preventAutoHideAsync();

export function SplashScreenController() {
  const { isLoading } = useSession();
  if (!isLoading) SplashScreen.hide();
  return null;
}

// app/_layout.tsx
export default function Root() {
  return (
    <SessionProvider>
      <SplashScreenController />
      <RootNavigator />
    </SessionProvider>
  );
}

function RootNavigator() {
  const { session } = useSession();
  return (
    <Stack>
      <Stack.Protected guard={!!session}>
        <Stack.Screen name="(tabs)" />
      </Stack.Protected>
      <Stack.Protected guard={!session}>
        <Stack.Screen name="sign-in" />
      </Stack.Protected>
    </Stack>
  );
}
```

- Navigation to a guarded screen redirects to the anchor route or first available screen; when a guard flips to false, the user is redirected and that screen's history is removed. SDK 58 adds `redirectTo="/login"`.
- Store the session token with `expo-secure-store` (Keychain/Keystore), never AsyncStorage.
- Sign-in calls `signIn()` then `router.replace("/")`; sign-out just clears the session and the guard does the rest.
- Guards are client-side only: the server still authorises every request.
- Onboarding works the same way: a persisted `hasFinishedOnboarding` flag as the guard.
- SDK 52 and earlier: return `<Redirect href="/sign-in" />` from the protected group's layout instead.

### Dynamic routes

```tsx
const params = useLocalSearchParams();   // values are string | string[]; narrow with typeof
const plant = usePlantStore((s) => s.plants.find((p) => String(p.id) === params.plantId));
const navigation = useNavigation();
useEffect(() => { navigation.setOptions({ title: plant?.name }); }, [plant?.name, navigation]);
if (!plant) return <NotFound />;
```

- Pass ids in params, not objects: `<Link href={{ pathname: "/plants/[plantId]", params: { plantId: id, action: "water" } }}>`.
- `export const unstable_settings = { anchor: "index" }` in a nested stack layout makes a cold-start deep link to `/plants/1` still have `index` beneath it, so Back works.
- Do not rely on `router.navigate()` to return to a screen already in the stack: use `router.dismissTo(href)`, and `router.back()` to close a modal.

## State: Zustand with persistence

```sh
npx expo install zustand @react-native-async-storage/async-storage
```

```ts
export const usePlantStore = create(
  persist<PlantState>(
    (set) => ({
      plants: [],
      addPlant: (plant) => set((s) => ({ plants: [plant, ...s.plants] })),
    }),
    { name: "plant-store", version: 1, storage: createJSONStorage(() => AsyncStorage) },
  ),
);
```

- One store per domain; export the entity types from the store.
- Select narrowly, one selector per value: `usePlantStore((s) => s.plants)`.
- Actions may be async (copy a file, then `set`).
- Persisted stores outlive app versions: set `version` and a `migrate` function from the first release.
- Server data belongs in TanStack Query, not a Zustand store.

## UI patterns

- Custom button: `Pressable` with `style={({ pressed }) => [styles.button, pressed && styles.pressed]}`, light haptic on press guarded for web.
- Images: use `expo-image` (disk and memory caching, blurhash placeholders, `contentFit`, `transition`). Bundled assets with `require("@/assets/x.png")`; size responsively with `useWindowDimensions()`.
- Gradients: `expo-linear-gradient`. Status bar style per screen with `<StatusBar style="light" />` from `expo-status-bar`.
- Shadows: use `boxShadow` (web syntax, both platforms, e.g. `boxShadow: "0 1px 3px rgba(0,0,0,0.2)"`). The older `shadow*` props are mostly iOS-only, with `elevation` on Android. Give the view a `backgroundColor` or the shadow lands on its children.
- Forms: controlled inputs, validate on submit, `Number(x)` plus `Number.isNaN`, `keyboardType="number-pad"`, `autoCapitalize="words"`. Wrap in `ScrollView keyboardShouldPersistTaps="handled"` so the first tap on Submit is not swallowed dismissing the keyboard. Long forms: `KeyboardAvoidingView` or `react-native-keyboard-aware-scroll-view`.

## Files and media

```sh
npx expo install expo-image-picker expo-file-system
```

```ts
import * as ImagePicker from "expo-image-picker";
import { File, Paths } from "expo-file-system";

const result = await ImagePicker.launchImageLibraryAsync({ mediaTypes: ["images"], allowsEditing: true, aspect: [1, 1], quality: 1 });
if (!result.canceled) {
  const src = new File(result.assets[0].uri);
  const dest = new File(Paths.document, `${Date.now()}-${src.name}`);
  await src.copy(dest);   // async from SDK 56; copySync also exists
  save(dest.uri);
}
```

Picker URIs live in temporary storage; copy into the document directory before saving a reference.

## Animations: Reanimated 4

```sh
npx expo install react-native-reanimated react-native-worklets
```

- New Architecture only. Worklets live in the separate `react-native-worklets` package. In Expo, `babel-preset-expo` configures the Babel plugin; bare projects add `react-native-worklets/plugin` last in `plugins`. Rebuild the dev client and start with `--clear` after installing.
- Start with the CSS-style APIs for state-driven and looping animations:

```tsx
<Animated.View style={{ width, transitionProperty: "width", transitionDuration: 300 }} />

<Animated.View style={{
  animationName: { from: { opacity: 0.4 }, to: { opacity: 1 } },
  animationDuration: "1s", animationIterationCount: "infinite", animationDirection: "alternate",
}} />
```

- CSS transitions react to values that change between renders, not to shared values. For gesture, scroll or frame-by-frame work use shared values:

```tsx
const offset = useSharedValue(0);
const style = useAnimatedStyle(() => ({ transform: [{ translateX: withSpring(offset.value) }] }));
offset.value = 100;   // always .value; reassigning the variable is the classic bug
```

- Enter and exit: `<Animated.View entering={FadeIn} exiting={FadeOut.duration(200)} />`; define builders outside the component or in `useMemo`.
- Calling JS from a worklet: `scheduleOnRN(fn, ...args)` from `react-native-worklets` (replaces `runOnJS(fn)(args)`; `runOnUI` becomes `scheduleOnUI`).
- v4 springs: `duration` is perceptual and `energyThreshold` replaces the rest thresholds; `useAnimatedGestureHandler` and `useWorkletCallback` are gone.

## Gestures: Gesture Handler 3

```sh
npx expo install react-native-gesture-handler
```

- Wrap the app in `GestureHandlerRootView` as close to the root as possible (Android modals need their own).
- Use the hook API; callbacks run on the UI thread by default:

```tsx
const offset = useSharedValue({ x: 0, y: 0 });
const pan = usePanGesture({
  onUpdate: (e) => { offset.value = { x: offset.value.x + e.changeX, y: offset.value.y + e.changeY }; },
});
const style = useAnimatedStyle(() => ({ transform: [{ translateX: offset.value.x }, { translateY: offset.value.y }] }));

<GestureDetector gesture={pan}><Animated.View style={[styles.ball, style]} /></GestureDetector>
```

- Renames from v2: `Gesture.Pan()` becomes `usePanGesture({...})` (and `useTapGesture`, `usePinchGesture`, ...), `onStart` becomes `onActivate`, `onEnd` becomes `onDeactivate`, `onChange` folds into `onUpdate`. Compose with `useSimultaneousGestures`, `useCompetingGestures`, `useExclusiveGestures`. Hook and v2-style gestures cannot be related to each other.
- Callbacks defined outside the config object need a `'worklet'` directive.

## Testing

### Unit and component: jest-expo plus React Native Testing Library

```sh
npx expo install jest-expo jest @types/jest @testing-library/react-native --dev
```

```json
{ "scripts": { "test": "jest --watchAll" }, "jest": { "preset": "jest-expo" } }
```

- `jest-expo` mocks the native side of the Expo SDK. SDK 58 needs Jest 30.
- Keep tests out of `app/` (every file there is a route); use `__tests__/`.
- RNTL 14 needs React 19 and `test-renderer`, and everything is async: `await render(...)`, `await fireEvent.press(...)`, `await act(...)`. Its Jest matchers are built in.
- Query by role first (`getByRole`, then label, placeholder, text, test id); `findBy*` for things that appear later, `queryBy*` only to assert absence. Prefer `userEvent` over `fireEvent`:

```tsx
import { render, screen, userEvent } from "@testing-library/react-native";

test("adds a plant", async () => {
  const user = userEvent.setup();
  await render(<NewPlantForm />);
  await user.type(screen.getByRole("textbox", { name: "Name" }), "Fern");
  await user.press(screen.getByRole("button", { name: "Add" }));
  expect(await screen.findByText("Fern")).toBeOnTheScreen();
});
```

- Router: `expo-router/testing-library` gives `renderRouter` (await it; `initialUrl` simulates a deep link), `testRouter` and matchers such as `toHavePathname`:

```tsx
await renderRouter(["index", "profile"]);
await testRouter.push("/profile");
expect(screen).toHavePathname("/profile");
```

- Reanimated in tests: `resolver: "react-native-reanimated/jest/resolver"` in the Jest config and `require("react-native-reanimated").setUpTests()` in the setup file; drive with fake timers.

### End to end: Maestro

Flows live in `.maestro/` next to `eas.json`; run locally with `maestro test .maestro/home.yml` against an installed build, or in EAS Workflows with a `maestro` job after a build job.

```yaml
appId: com.example.plantly
---
- launchApp
- assertVisible: "Welcome!"
- tapOn: "Add a plant"
```

Build profile for E2E: `{ "withoutCredentials": true, "ios": { "simulator": true }, "android": { "buildType": "apk" } }`.

## Performance

- Measure in release builds only; dev mode slows the JS thread. Hermes is the default engine. Perf Monitor (Dev Menu) shows JS and UI frame rates separately; profile with Instruments and the Android Studio Profiler.
- Long or heavy lists: FlashList v2 (`npx expo install @shopify/flash-list`). It needs no `estimatedItemSize`; refs are `FlashListRef<T>`; masonry is a `masonry` prop; padding goes in `contentContainerStyle`.
- In recycling lists give `expo-image` a `recyclingKey` so the previous image does not flash.
- Animate size with `transform: [{ scale }]`, not width and height. Strip `console.*` from release bundles.

## Expo Go versus development builds

- A React Native app is a JS bundle plus a native binary. Expo Go is a prebuilt binary with a fixed set of native modules. A development build is your own Expo Go with exactly your native dependencies.
- Needed for: in-app purchases, vision camera, Firebase, quick actions, bundled fonts, custom icon and splash, any library with a config plugin, and EAS Update with a runtime version. Switch early.

```sh
npx expo install expo-dev-client
npx expo prebuild --platform ios           # asks for the bundle id the first time
npx expo run:ios                           # or run:android
npx expo prebuild --clean --platform ios   # after any native config change
```

- **Continuous Native Generation:** `ios/` and `android/` are generated output. Keep them in `.gitignore` and change native projects through config plugins. Committing or hand-editing them opts you into the bare workflow.
- App id (`ios.bundleIdentifier`, `android.package`): reverse domain, globally unique on Apple, permanent once uploaded. Choose it carefully.
- Emulator will not start: launch it from Android Studio's Device Manager. Simulator missing: open Xcode once and accept the download.

## App config, plugins and environment variables

```json
{ "expo": {
  "name": "Plantly", "slug": "plantly", "scheme": "plantly", "version": "1.0.0",
  "icon": "./assets/icon.png", "userInterfaceStyle": "automatic",
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

- Plugins are a string or `[name, options]`; `npx expo install` often adds them for you. `name` is the display name; `slug` stays lowercase.
- Per-variant config in `app.config.ts` (it wins over `.js`; no Promises):

```ts
import { ExpoConfig, ConfigContext } from "expo/config";

const variant = process.env.APP_VARIANT;
const id = variant === "development" ? "com.example.plantly.dev" : variant === "preview" ? "com.example.plantly.preview" : "com.example.plantly";

export default ({ config }: ConfigContext): ExpoConfig => ({
  ...config,
  name: variant === "development" ? "Plantly (Dev)" : variant === "preview" ? "Plantly (Preview)" : "Plantly",
  slug: "plantly",
  ios: { ...config.ios, bundleIdentifier: id },
  android: { ...config.android, package: id },
});
```

  Set `APP_VARIANT` in each build profile's `env`; locally `APP_VARIANT=development npx expo start`.
- `EXPO_PUBLIC_*` variables are inlined into the JS bundle, so they are public: never put secrets there. Read them with dot notation (`process.env.EXPO_PUBLIC_API_URL`); bracket access is not inlined. Expo loads `.env`, `.env.local` and the `.development` / `.production` variants; from SDK 58 other names such as `.env.staging` are ignored. Gitignore `.env*.local`.
- EAS environment variables (`eas env:set --name X --value Y --environment production --visibility plaintext|sensitive|secret`) per `development`, `preview`, `production` environment. Secret variables exist only on EAS build servers: not in local builds, local config or updates.

## Fonts, splash, icons

- Fonts: `useFonts` loads at runtime and works in Expo Go; the `expo-font` plugin embeds fonts in the binary (development builds). All Google Fonts are on npm as `@expo-google-fonts/*`; prefer OTF.
- Font family names differ: Android uses the file name, iOS the PostScript name. Rename files to their PostScript name, or `Platform.select({ ios: "Caveat-Regular", android: "Caveat_400Regular" })`.
- Splash: background colour plus centred image via the `expo-splash-screen` plugin, with a `dark` variant. Full-screen splash images are no longer supported.
- Icons: iOS 1024x1024 PNG without transparency; Android adaptive icon 1024x1024 foreground plus background colour; web favicon 48x48.
- Rebuild with `prebuild --clean`; if the old splash sticks, `npx expo run:ios --no-build-cache`.

## Quick actions and deep links

```tsx
import * as QuickActions from "expo-quick-actions";
import { useQuickActionRouting } from "expo-quick-actions/router";

useQuickActionRouting();
useEffect(() => {
  QuickActions.setItems([{ id: "0", title: "Add a plant", icon: Platform.OS === "ios" ? "symbol:leaf" : "leaf", params: { href: "/new" } }]);
}, []);
```

- iOS icons use the `symbol:` prefix for SF Symbols; Android icon names must be declared under `androidIcons` in the `expo-quick-actions` plugin config. Tell App Review about entry points that only a quick action reaches, or expect a rejection.
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

- EAS generates and stores credentials on first `eas build` (`eas credentials` to inspect them and set up push keys). Once iOS credentials exist, teammates build without Apple team access.

## EAS Build

```sh
npm install --global eas-cli && eas login
eas build:configure                        # writes eas.json
eas build --platform android               # android | ios | all; defaults to the production profile
eas build --profile preview --platform ios
eas build -p android --local               # on your machine; one platform, no secret variables, macOS or Linux
```

```json
{
  "cli": { "appVersionSource": "remote" },
  "build": {
    "development": { "developmentClient": true, "distribution": "internal", "env": { "APP_VARIANT": "development" } },
    "development-simulator": { "extends": "development", "ios": { "simulator": true } },
    "preview": { "distribution": "internal", "channel": "preview", "env": { "APP_VARIANT": "preview" } },
    "production": { "channel": "production", "autoIncrement": true }
  },
  "submit": {
    "production": { "android": { "track": "internal" }, "ios": { "ascAppId": "1234567890" } }
  }
}
```

- `distribution: "internal"` gives a shareable install link; `store` (the default) is for upload. Android `buildType` defaults to `app-bundle`.
- `environment` picks the EAS variables: defaults to `production` for store builds, `development` for dev clients, otherwise `preview`.
- `env` is for values you would commit; it is not applied by `eas update`.
- `appVersionSource: "remote"` lets EAS own `versionCode` and `buildNumber` with `autoIncrement`; you still bump the user-facing `version`. Sync existing store numbers once with `eas build:version:set`.
- `eas build:run -p ios --latest` installs the latest simulator build.
- From another CI: `npx eas-cli build --platform all --non-interactive --no-wait` with `EXPO_TOKEN` set.

## EAS Submit

```sh
eas submit --platform ios
eas build --platform android --auto-submit   # uses the submit profile named like the build profile
```

- Android needs the app created in Play Console and a Google service account key uploaded to EAS (`eas credentials`). The first upload no longer has to be manual: `eas submit` creates the first release on the internal track.
- iOS in CI needs an App Store Connect API key and `ascAppId`. Builds reach TestFlight after processing.
- Auto-submit makes builds available for testing; it does not send them for public review.

## EAS Update

```sh
npx expo install expo-updates
eas update:configure                       # runtimeVersion, updates.url, channels on profiles
eas update --channel production --environment production --message "Fix login"
eas update --rollout-percentage=10 ...     # staged; eas update:edit to raise it
eas update:rollback
```

- `--environment` is required from SDK 55.
- A build reads one channel (from its profile); a channel points to a branch. Simplest model: think in channels and runtime versions, ignore branches.
- An update reaches a build only when platform and runtime version match exactly. `runtimeVersion: { "policy": "appVersion" }` is the configured default and what the deploy guide recommends: bump `version` with every native change. `fingerprint` derives the runtime from native inputs, safer at the cost of more builds.
- Updates change JS, styling, assets and copy. They cannot change native code or dependencies, permissions, the SDK or `app.json` native settings: those need a build.
- A downloaded update applies on the next launch. Updates with a runtime version do not load in Expo Go.
- Store rules apply: ship fixes by update and follow with a store release; behaviour changes go through review.

## EAS Workflows

```sh
eas workflow:create --template build     # .eas/workflows/build.yml
eas workflow:run .eas/workflows/build.yml
```

```yaml
name: Production builds
on:
  push:
    branches: ["main"]
jobs:
  build_android:
    type: build
    params: { platform: android, profile: production }
  build_ios:
    type: build
    params: { platform: ios, profile: production }
```

Job types include `build`, `submit`, `update`, `fingerprint`, `get-build` and `maestro`. The deploy template uses a `fingerprint` job to decide between a new build plus submit or an update. Git triggers need the Expo GitHub app linked.

## Store release checklist

1. Accounts: Google Play (one-off fee, identity checks take days), Apple Developer Program (yearly). Paid apps publish the seller's address, so consider a company account.
2. Create the app record in each console.
3. Production build: Android `.aab`, iOS `.ipa` signed for the App Store.
4. Upload with `eas submit` (or Play Console, Transporter, Xcode).
5. Metadata: privacy and data-tracking declarations, description, keywords, countries, pricing.
6. Screenshots at the required sizes; Android feature graphic.
7. Testing tracks: TestFlight internal (no review) and external (short review); Play internal, closed, open. New personal Play accounts need 12 opted-in testers for 14 days before production.
8. Review: give demo credentials, specific permission usage strings, and notes for hidden features. Crash on launch is the classic rejection.

## Libraries worth knowing

Skia, Vision Camera, NativeWind, Tamagui, react-native-bootsplash, Ignite as a boilerplate, React Native Directory to vet packages.
