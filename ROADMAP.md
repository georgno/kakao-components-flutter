# Roadmap

Ported: button, tooltip, card, dialog, progress, popover, menu (plus theme-switch
settings for the cross-fade). The order below follows shared building blocks: build a block
once, then the components that use it follow quickly.

The web components never share code ("components never reach into each
other"). Here, shared building blocks are internal (`lib/src/internal/`); each
public widget still takes every value from its own web component's settings
block, so two widgets built on the same block can differ where the web ones do.

## 0. Look-alike check (done)

`tool/lookalike` (see its README): Playwright screenshots of web demo
elements next to showcase fixtures at the same width, theme and contrast,
diffed into `build/lookalike/report.html`. Runs locally, not in Actions.
Every component after this gets cases in `tool/lookalike/cases.json` and a
pass of it. Cases so far: button, card, progress, popover and menu (opened first).

## 1. Anchored panel and option list

- Internal: an anchored panel (done: `lib/src/internal/kakao_anchored_panel.dart`,
  `KakaoAnchoredPanel`; position next to an anchor or a point, flip rules of
  popover.js and menu.js / select.js, start / centre / end alignment, height
  capped by the room, keep-side, anchor width, entry motion, outside tap,
  Escape, focus return) and an option list (done:
  `lib/src/internal/kakao_option_list.dart`, `KakaoOptionList`; rows, check mark,
  keyboard and pointer highlight, type-ahead, groups, separators).
- Then: `popover` (done), `menu` (done), the button's menu mode (with its chevron) and
  segmented group, `select`, `combobox`, `multi-dropdown`, `command-palette`.

## 2. Fields

- Internal: field chrome (label, border, focus ring, help and error text,
  heights 36 / 44 / 52 like the button).
- Then: `text-input`, `textarea`, `password-input`, `number-input`,
  `date-input` and `time-input` (date picker on the anchored panel),
  `tag-input`, `code-input`, `color-code`, `color-picker`, `file-upload`.

## 3. Toggles and ranges

`checkbox`, `radio-group`, `switch-group`, `step-switch`, `chip`, `chip-list`,
`slider`, `range-slider`, `rating`.

## 4. Feedback and small parts

`alert`, `toast`, `badge`, `avatar`, `spinner`, `skeleton`, `empty-state`,
`error-summary`, `meter`, `animated-number`, `kbd`, `copy-button`.

## 5. Structure and navigation

`tabs`, `accordion`, `aside-sheet` (a bottom sheet on phones), `aside-menu`,
`header-bar`, `breadcrumb`, `pagination`, `toc`, `list`, `table`,
`tree-view`, `description-list`, `settings-group`, `grid-view`, `image`,
`theme-switch`, `error-page`.

## Known gaps in ported widgets

- Button: segmented group, menu mode (step 1).
- Tooltip: left / right placement, staying open while the pointer is on the
  label, showing at once after another label, Escape to hide.
- Card: `theme-glow`; its resize also animates width changes (the web card
  only animates height).
- Dialog: `contained` mode.
- Progress: the percentage is always English-style ("40%"), not formatted for the locale.
- Popover: the anchor is built by `anchorBuilder` and wires `toggle` itself
  (no `for` id); no `setData` busy state; the hover popover has no tooltip
  semantics role (Flutter has none yet), it is a live region; Escape from a
  hover popover does not reopen it when focus returns (the web one can);
  the ✕ is drawn in a fallback font on both sides, so it differs slightly;
  the panel is placed in left-to-right terms (no RTL mirroring of
  start / end yet). In the look-alike web build the ✕ can show a focus ring
  after the page itself takes focus (Flutter web moves focus on view focus).

- Popover: its label / value rows keep their own roving focus and are not on the option
  list (hover and focus are separate there, and Left / Right move too).
- Menu: no `href` link items (navigate in `onSelect`); shortcuts are plain text, not
  `<kakao-kbd>` keycaps (kbd is not ported; the web demo loads it, so the look-alike panels
  are narrower); Material icons stand in for menu.js's named glyphs; the trigger's text is
  not its default accessible name (`label`, else "Menu"); a submenu with no room on either
  side is pushed inside the screen over its parent instead of opening under its item; a
  submenu (and a point menu) slides in from its own side, not always from 4 px above; a
  menu opened at a point follows scrolling instead of closing; focus moving elsewhere by
  script or a window blur does not close it; `aria-haspopup` has no Flutter equivalent.

- Text: Flutter rounds every line box to whole pixels (14 px at 1.4 is
  20 px tall, not 19.6), so text with a fractional line height runs up to
  half a pixel taller per line than on the web (progress labels: 34.5 px
  per bar instead of 34). No text style turns it off.
- Button: the label sits about 1 px higher than on the web (look-alike
  check, every size); `line-height: normal` instead of `height: 1` did not
  fix it.

## Seen on the web side

- Progress: at 30 % of 4 segments the web draws a sliver of fill at the start
  of the empty third segment (look-alike check, `progress-tones`, Danger).

## Later

- `tokens.json` compact format (formatVersion 2).
- Browser fixtures in kakao-components re-recorded in Firefox.
- iOS builds.
