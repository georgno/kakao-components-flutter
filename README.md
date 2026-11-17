# kakao_components (Flutter)

Flutter twins of [kakao-components](https://github.com/georgno/kakao-components):
the same tokens, themes, look and motion as the web components, for Android,
iOS, web and desktop.

## Status

| Part | State |
|---|---|
| Themes (light, beige, umber, dark, amoled, catppuccin, forest + more-contrast) | done, generated |
| Shared tokens (space, radius, font, motion) | done, by hand until `tokens.json` lands |
| `KakaoButton` | variants, sizes, icon, icon-only, loading, disabled |
| Other components | planned |

Colours come from `lib/src/theme/kakao_colors.g.dart`, written by
`node tool/import-colors.mjs ../kakao-components`. That interim script is
replaced by a generator reading `tokens.json` once kakao-components ships
`tools/export-tokens.js` (OpenSpec change `token-export` there).

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
