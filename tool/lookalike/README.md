# Look-alike check

Screenshots each web demo element listed in `cases.json` and the showcase
fixture of the same id (`example/lib/lookalike/fixtures.dart`), at the same
width, theme and contrast, and diffs them. It runs locally, not in Actions.

```sh
cd tool/lookalike
npm install
npx playwright install chromium
node lookalike.mjs                       # light and dark
node lookalike.mjs --contrast            # also more-contrast mode
node lookalike.mjs --themes beige,amoled --only card-primary,card-danger
node lookalike.mjs --no-build            # reuse example/build/web
```

It needs a kakao-components checkout next to this repo (or `--web <path>`)
and `flutter` on the PATH. The result is `build/lookalike/report.html`, worst
pair first: web, Flutter and diff side by side, with both sizes and the
height or width difference.

## How a pair is taken

1. The web demo page opens with the theme saved where `theme-switch.js`
   reads it, the case's element is found by its Playwright selector, and the
   screenshot is its box plus `margin`.
2. The background is the commonest colour on that screenshot's edge.
3. The showcase's web build opens with `?lookalike=<id>`: only that fixture,
   at the web element's width, on that background (`LookalikeApp`). It
   reports its box through `window.lookalikeBox`, and the screenshot is taken
   with the same margin.
4. Both images are padded to the same size and compared with pixelmatch.

Text never matches pixel for pixel (browser text vs. Flutter's own); what to
look at is the size difference, spacing, colours, radii and shadows.

## Adding a component

Add a case to `cases.json` (the demo page and a selector for one example)
and a fixture of the same id with the same content. `example/test/
lookalike_test.dart` fails when one has no partner.
