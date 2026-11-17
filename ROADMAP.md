# Roadmap

Ported: button, tooltip, card, dialog, progress (plus theme-switch settings for
the cross-fade). The order below follows shared building blocks: build a block
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
pass of it. Cases so far: button, card, progress.

## 1. Anchored panel and option list

- Internal: an anchored panel (position next to an anchor, flip when there is
  no room, open and close motion) and an option list (rows, check mark,
  keyboard and pointer highlight, groups).
- Then: `popover`, `menu`, the button's menu mode (with its chevron) and
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
