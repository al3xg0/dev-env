---
name: react-native-fundamentals
description: Building React Native apps with Expo, from Kadi Kraman's React Native v3 course (Frontend Masters). Use when starting a new React Native or Expo project, writing screens and components, styling with StyleSheet and flexbox, setting up Expo Router (stack, tabs, modals, nested navigators, header buttons), rendering lists with FlatList or ScrollView, handling TextInput, persisting state with AsyncStorage, adding LayoutAnimation, haptics or local notifications, or working with dates and timers. Also trigger on "text strings must be rendered within a <Text> component", "PluginError: Failed to resolve plugin for module expo-router", "my notification fires immediately", "padding cuts off the end of my ScrollView", or "should I use npm install or expo install". For development builds, EAS, config plugins, fonts, splash, deep links and store release, use react-native-production. For architecture and operating an app at scale, use react-native-at-scale.
---

# React Native fundamentals with Expo

Source: Kadi Kraman, React Native v3 (https://kadikraman.github.io/react-native-v3-course/). Course stack: Expo SDK 54, React Native 0.81, React 19.1, expo-router 6, TypeScript 5.9. Versions move fast: check the current Expo SDK before pinning anything, and let `npx expo install` choose versions.

## Defaults

- Start with Expo (the framework Meta recommends for new apps), TypeScript and Expo Router.
- Expo Go is for learning and prototyping only: it ships a fixed set of native modules. Anything real moves to a development build (see react-native-production).
- Install every dependency with `npx expo install <pkg>` (dev deps: `npx expo install -- --save-dev <pkgs>`). It uses your package manager but picks the SDK-compatible version.
- After changing `app.json`, Babel, the entry point or plugins: `npx expo start --reset-cache`.

## Project setup

```sh
npx create-expo-app my-app --template   # pick "blank (TypeScript)" to learn; the default template already has Router, alias and more
cd my-app
npx expo start                           # Metro; scan the QR (Android: in Expo Go, iOS: Camera app)
npx expo start --tunnel                  # phone cannot reach the machine (different network, firewall)
```

Phone and computer must share a network unless tunnelling.

### Lint and format

```sh
npx expo lint                            # first run scaffolds eslint-config-expo (flat config on SDK 53+)
npx expo install -- --save-dev prettier eslint-config-prettier eslint-plugin-prettier eslint-plugin-react-native
```

```js
// eslint.config.js
const { defineConfig } = require("eslint/config");
const expoConfig = require("eslint-config-expo/flat");
const prettier = require("eslint-plugin-prettier/recommended");
const rn = require("eslint-plugin-react-native");

module.exports = defineConfig([
  expoConfig,
  prettier,
  { plugins: { "react-native": rn }, rules: { "react-native/no-unused-styles": "error" } },
  { ignores: ["dist/*"] },
]);
```

`no-unused-styles` catches dead StyleSheet entries after refactors.

## Core components: what differs from the web

- `View` is the `div`. All text must sit inside `<Text>`; a bare string elsewhere crashes.
- `Button` cannot be styled. Use `Pressable` (style as a function of `{ pressed }`) or `TouchableOpacity` (fades on press).
- No `<form>`: each input is handled individually. `onSubmitEditing` on `TextInput` is the closest thing to submit.
- Views do not scroll: use `ScrollView` or `FlatList`.
- `Alert.alert(title, message, buttons)` for native confirm dialogs; button `style: "destructive" | "cancel"`.
- Small icon buttons get `hitSlop={20}` so they are easy to hit.

```tsx
Alert.alert(`Delete ${name}?`, "It will be gone for good", [
  { text: "Yes", onPress: onDelete, style: "destructive" },
  { text: "Cancel", style: "cancel" },
]);
```

## Styling

- CSS property names in camelCase as JS objects. No units (density-independent points), no cascade, no global styles, no CSS animations.
- Flexbox with different defaults: everything is flex, `flexDirection` defaults to `column`, `flexShrink` to `0`, `alignContent` to `flex-start`, and `flex` takes one number.
- One `StyleSheet.create` at the bottom of each file. Colours and tokens in a shared `theme.ts`.
- Compose with arrays; `undefined` entries are allowed, which keeps conditionals clean:

```tsx
<Pressable onPress={onToggle} style={[styles.item, done ? styles.itemDone : undefined]}>
  <Text style={[styles.text, done ? styles.textDone : undefined]}>{name}</Text>
</Pressable>
```

- `fontVariant: ["tabular-nums"]` stops ticking numbers jittering.
- Components live outside `app/` (for example `components/ShoppingListItem.tsx`), with typed props and a named export.

## Icons

`npx expo install @expo/vector-icons`, browse at https://icons.expo.fyi, import one family at a time (`import AntDesign from "@expo/vector-icons/AntDesign"`) to keep the bundle small.

## Expo Router

Built on React Navigation, so its docs apply to screen options, hooks and styling props.

### Adding it to a blank app

```sh
npx expo install expo-router react-native-safe-area-context react-native-screens expo-linking expo-constants expo-status-bar
```

1. `package.json`: `"main": "expo-router/entry"`.
2. `app.json`: `"scheme": "my-app"` (required, Router has deep linking built in) and `"plugins": ["expo-router"]`.
3. Move `App.tsx` to `app/index.tsx`, add `app/_layout.tsx`.
4. `npx expo start --reset-cache`.

`PluginError: Failed to resolve plugin for module "expo-router"` means a missing dependency or a Metro that was not restarted with `--reset-cache`.

### Conventions

- Every file under `app/` is a route, so components, utils and theme live outside it.
- `app/index.tsx` is `/`, `app/home.tsx` is `/home`, `app/products/[productId].tsx` is `/products/123`.
- `_layout.tsx` (one per folder) decides how sibling routes are presented. Screens need declaring only to customise them.
- `(group)` folders are left out of the URL.
- Navigate with `<Link href="/counter">`, `useRouter().navigate("/idea")`, or header and tab buttons.
- Keep platform conventions (push and modal animations differ on iOS and Android by design).

### Stack, modal, tabs

```tsx
// app/_layout.tsx
<Stack>
  <Stack.Screen name="index" options={{ title: "Shopping list" }} />
  <Stack.Screen name="add" options={{ presentation: "modal" }} />
</Stack>
```

- A modal must be declared at or above the navigator it covers; a screen inside a tab navigator cannot be a modal over the tabs.
- Tabs: swap `Stack` for `Tabs`, set `tabBarActiveTintColor` once in `screenOptions`, and use the `color` and `size` passed to `tabBarIcon` so active tinting works:

```tsx
<Tabs.Screen
  name="index"
  options={{ title: "List", tabBarIcon: ({ color, size }) => <Feather name="list" size={size} color={color} /> }}
/>
```

### Nested navigators (a stack inside a tab)

- Regular screen `counter.tsx`: move it to `counter/index.tsx`, add `counter/_layout.tsx` with a `Stack`, add `counter/history.tsx`.
- An `index` screen: use a group, `(home)/index.tsx` plus `(home)/_layout.tsx`.
- Each navigator brings a header; hide the outer one with `headerShown: false`.
- Header buttons: `Link` with `asChild` hands navigation to the pressable child:

```tsx
headerRight: () => (
  <Link href="/counter/history" asChild>
    <Pressable hitSlop={20}><MaterialIcons name="history" size={32} color={theme.colorGrey} /></Pressable>
  </Link>
),
```

## Inputs and lists

```tsx
<TextInput
  value={value}
  onChangeText={setValue}
  placeholder="E.g. Coffee"
  onSubmitEditing={handleSubmit}
  returnKeyType="done"
  keyboardType="default"   // "number-pad", "phone-pad", ...
/>
```

- `ScrollView`: padding goes in `contentContainerStyle`, not `style`, or the end of the content is clipped. `stickyHeaderIndices={[0]}` pins the first child (give it a background).
- Use `FlatList` for anything mapped from an array or any full-screen list: it virtualises, and gives `ListHeaderComponent`, `ListEmptyComponent`, pull-to-refresh and scroll-to-index. `keyExtractor` is optional when items have `key` or `id`.
- Store timestamps (`completedAtTimestamp: Date.now()`) rather than booleans: ordering falls out of subtraction.
- Sort a copy, never state itself: `[...list].sort(...)`.

## Persistence with AsyncStorage

`npx expo install @react-native-async-storage/async-storage`. Unencrypted key-value store, like `localStorage`: never put tokens or secrets in it.

```ts
export async function getFromStorage<T>(key: string): Promise<T | null> {
  try {
    const data = await AsyncStorage.getItem(key);
    return data ? JSON.parse(data) : null;
  } catch {
    return null;
  }
}

export async function saveToStorage(key: string, data: unknown) {
  try {
    await AsyncStorage.setItem(key, JSON.stringify(data));
  } catch {}
}
```

Load once in `useEffect`, and save on every mutation, deletes included; a mutation that only updates state comes back after a restart. Beyond a screen or two, use a state library with an AsyncStorage persistence adapter (see react-native-production).

## Feel: LayoutAnimation and haptics

```ts
LayoutAnimation.configureNext(LayoutAnimation.Presets.easeInEaseOut);
setList(next);   // the next layout change animates
```

```ts
import * as Haptics from "expo-haptics";
Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);            // destructive or toggle actions
Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success); // completion
```

Use haptics sparingly, on meaningful actions, and guard with `Platform.OS !== "web"` if you ship web. Anything richer than LayoutAnimation means Reanimated.

## Local notifications

`npx expo install expo-notifications expo-device`. Local notifications work in Expo Go; remote push needs a server and a device token.

```ts
export async function registerForNotifications() {
  if (Platform.OS === "android") {
    // Android 13+ shows the permission prompt only once a channel exists
    await Notifications.setNotificationChannelAsync("default", {
      name: "default",
      importance: Notifications.AndroidImportance.DEFAULT,
    });
  }
  if (!Device.isDevice) return null; // simulators and emulators
  const { status: existing } = await Notifications.getPermissionsAsync();
  if (existing === "granted") return existing;
  const { status } = await Notifications.requestPermissionsAsync();
  return status;
}

const id = await Notifications.scheduleNotificationAsync({
  content: { title: "Car wash overdue!" },
  trigger: { type: Notifications.SchedulableTriggerInputTypes.TIME_INTERVAL, seconds },
});
```

- SDK 53+: a trigger without `type` fires immediately.
- The permission prompt shows once; after a denial the user must go to Settings.
- Persist the notification id and `cancelScheduledNotificationAsync(id)` before rescheduling.
- A foregrounded app does not show the banner unless you set `Notifications.setNotificationHandler`; background the app to test.

## Dates and timers

`npx expo install date-fns`. Model durations in milliseconds, poll with `setInterval` in an effect and always clear it:

```ts
useEffect(() => {
  const id = setInterval(() => {
    const isOverdue = isBefore(dueAt, Date.now());
    setStatus({
      isOverdue,
      distance: intervalToDuration(isOverdue ? { start: dueAt, end: Date.now() } : { start: Date.now(), end: dueAt }),
    });
  }, 1000);
  return () => clearInterval(id);
}, [dueAt]);
```

Duration fields can be `undefined`: render with `?? 0`.

## Checklist when writing a screen

- Text inside `<Text>`; `Pressable` rather than `Button`; `hitSlop` on small targets.
- `FlatList` for lists, padding in `contentContainerStyle`, an empty state.
- Styles in one `StyleSheet.create`, colours from `theme.ts`, no unused styles.
- Only route files in `app/`; one header per visible stack.
- State mutations are immutable and persisted; destructive actions confirmed with `Alert`.
- Platform differences checked on both an iOS simulator and an Android emulator.
