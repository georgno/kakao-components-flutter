# kakao-components-flutter

Flutter mirror of kakao-components (web). Widgets must look and move the same
as their web twin: take sizes, colours, radii, shadows and timing from the web
component's `@kakao-settings` block and say which setting a literal comes from.

- One widget per web component, named `Kakao<Name>`, in `lib/src/components/`.
- Colours only from `KakaoTheme.of(context).colors` (the `--kakao-color-*` roles),
  never hard-coded, so every theme and the more-contrast mode work.
- Values come from the generated settings (`lib/src/settings/*.g.dart`, `kakao_colors.g.dart`,
  `kakao_tokens.g.dart`), made by `dart run tool/generate.dart` from `tool/tokens.json` (the web
  repo's export). Never edit generated files or copy a value by hand; a literal is only for what the
  web keeps outside its settings block (page CSS, script constants), with a comment naming the source.
- Never use uppercase styling, and no thick accent stripe on one side of a box
  ("fingernail" borders). Use a tint, a full thin border, weight or colour.
- Every widget gets a section in the showcase (`example/lib/main.dart`) and tests.
- What to port next, and the known gaps: `ROADMAP.md`.
- Before committing: `flutter analyze && flutter test` in the root and in `example/`.
