# Changelog

## Unreleased

- Themes, shared tokens and component settings generated from kakao-components'
  `tokens.json` (`tool/generate.dart`), tested against it in every theme and contrast mode.
- Shadows now as soft as on the web (CSS blur converted to Flutter's blur radius).
- `KakaoCard`: header, body, footer; glow from the first footer button; glides to a new height.
- `KakaoDialog` / `showKakaoDialog`: scrim and panel motion, title, scrolling body, footer
  positions, full width, corner nesting rule, Escape and outside tap (or no-dismiss).
- `KakaoProgress`: segments, fill timing, the pop rule, indeterminate sweep, tones, sizes.

- Themes generated from kakao-components v0.9.0 (7 themes, more-contrast colours).
- Shared tokens, Inter Tight variable font.
- `KakaoButton`.
- Showcase app with an in-app updater fed by the rolling `debug` release.
