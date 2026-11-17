# kakao_components (Flutter)

Flutter twins of [kakao-components](https://github.com/georgno/kakao-components):
the same tokens, themes, look and motion as the web components, for Android,
iOS, web and desktop.

## Status

| Part | State |
|---|---|
| Themes (light, beige, umber, dark, amoled, catppuccin, forest + more-contrast) | generated |
| Shared tokens (space, radius, font size, motion) | generated |
| `KakaoButton`, `KakaoTooltip`, `KakaoCard`, `KakaoDialog`, `KakaoProgress` | done, settings generated |
| Other components | planned |

## Design values come from the web

kakao-components exports every design value to `tokens.json`
(`tools/export-tokens.js` there). This repo keeps a pinned copy in
`tool/tokens.json` (where it came from: `tool/tokens.source`) and generates
the Dart from it:

    dart run tool/generate.dart

That writes the themes (`kakao_colors.g.dart`), the shared tokens
(`kakao_tokens.g.dart`) and one settings class per ported component
(`lib/src/settings/`), built from each setting's chain of references so
settings follow the theme live. `test/generated_test.dart` checks every
generated setting against `tokens.json` in every theme and contrast mode.

To take a new web release: copy its `tokens.json` to `tool/`, update
`tool/tokens.source`, run the generator and the tests. To port a component:
add it to `ported` in `tool/generate.dart`, generate, then write the widget
on its settings class.

## Use

```dart
KakaoTheme(
  data: KakaoThemeData.dark,
  child: KakaoButton(label: 'Save', onPressed: save),
)
```

## Showcase app

`example/` is the showcase: every component in every theme. Run it with
`cd example && flutter run`.

The CI build of it updates itself. Every push to the default branch builds
an APK and puts it on the rolling
[`debug` pre-release](https://github.com/georgno/kakao-components-flutter/releases/tag/debug).
The APK is built for arm64, which covers current phones (not x86 emulators).
To start, download `kakao-showcase.apk` from that page on your phone, allow
the install, and you're set. After that, the app checks for a newer build
whenever it opens. It offers the update, downloads it and hands it to
Android's installer. The first time, Android asks you to allow installs from
the app. "Check for updates" at the bottom of the showcase checks on demand.

The repo must be public for the updater to read the release without a login.
Builds are signed with a public development key
(`example/android/app/showcase-dev.jks`), so any build installs over the
last. This key is for the showcase only, never for a store release.

## Licence

Inter Tight: SIL Open Font License 1.1 (`fonts/OFL.txt`).
