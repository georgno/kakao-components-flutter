# Roadmap

Ported: button (with its menu form and segmented group), tooltip, card, dialog, progress,
popover, menu, select, combobox, multi-dropdown, command-palette (plus theme-switch settings for the cross-fade). The order below follows
shared building blocks: build a block once, then the components that use it follow quickly.

The web components never share code ("components never reach into each
other"). Here, shared building blocks are internal (`lib/src/internal/`); each
public widget still takes every value from its own web component's settings
block, so two widgets built on the same block can differ where the web ones do.

## 0. Look-alike check (done)

`tool/lookalike` (see its README): Playwright screenshots of web demo
elements next to showcase fixtures at the same width, theme and contrast,
diffed into `build/lookalike/report.html`. Runs locally, not in Actions.
Every component after this gets cases in `tool/lookalike/cases.json` and a
pass of it. Cases so far: button (with the dropdown closed and opened, and the segment), card, progress,
popover and menu (opened first), select (closed, opened, disabled and error), combobox
(closed with a value, opened while filtering — the case types after its `open` click —,
disabled and error), multi-dropdown (closed with every part set, its month list opened,
disabled), command-palette (opened with all commands, opened while filtering by "fi", and the
empty state).

## 1. Anchored panel and option list (done)

- Internal: an anchored panel (done: `lib/src/internal/kakao_anchored_panel.dart`,
  `KakaoAnchoredPanel`; position next to an anchor or a point, flip rules of
  popover.js and menu.js / select.js, start / centre / end alignment, height
  capped by the room, keep-side, anchor width, entry motion, outside tap,
  Escape, focus return) and an option list (done:
  `lib/src/internal/kakao_option_list.dart`, `KakaoOptionList`; rows, check mark,
  keyboard and pointer highlight, type-ahead, groups, separators).
- Then: `popover` (done), `menu` (done), the button's menu mode (with its chevron) and
  segmented group (done), `select` (done), `combobox` (done), `multi-dropdown` (done),
  `command-palette` (done).
- What step 2 can reuse: `lib/src/internal/kakao_field.dart` (`KakaoField` for label / hint /
  error / disabled, `KakaoFieldBox` + `KakaoRing` for the bordered box and focus outline,
  `KakaoFieldText` for the bare one-line text field with gestures, placeholder, tap region
  group and `selectAllOnFocus`, `KakaoChevronPainter`, `kakaoFold`); the anchored panel for
  the date and time pickers and the colour picker; the option list (with `labelSpans` for
  marked matches) for tag-input suggestions. `KakaoCombobox` is the model for a text field
  that handles its own keys, `KakaoSelect` for a field that opens a panel, and
  `KakaoCommandPalette` for a modal on the root navigator with its own route (scrim, entry
  motion, no exit motion).

## 2. Fields

- Internal: field chrome (label, border, focus ring, help and error text,
  heights 36 / 44 / 52 like the button). Done for select and combobox in
  `lib/src/internal/kakao_field.dart`: `KakaoField` (label, hint / error, disabled opacity),
  `KakaoFieldBox` / `KakaoRing` (bordered box, outline), `KakaoFieldText` (a bare one-line
  text field: pointer gestures, placeholder, tap region group, unfocus on a tap outside),
  `KakaoChevronPainter`, `kakaoFold`. The text input family builds on them.
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

- Button menu: the menu is not capped to the room or clamped on the web (it may run off
  the screen), here it stays 8 px inside; the flip threshold is room < height + 14 px (offset +
  margin), button.js uses + 16; type-ahead uses the option list's rule (one letter typed again
  walks on), button.js searches the doubled letters; a pointer down outside returns focus to
  the button (button.js leaves it); the menu's text uses the demo page's line height 1.5.
- Button segment: exclusivity is the owner's (as the web demo's script); no Left / Right
  roving between items (the web has none either); a labelled item keeps its size's side
  padding where the web CSS fixes 38 px; Material icons stand in for the demo's Font Awesome
  align icons.
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

- Select: no form participation (`name`, `required`, reset, state restore, validity): the
  owner keeps the value and sets `error`; no child `<option>` source (options are data); the
  selected option is scrolled into view at the edge of the list, not centred; a pointer over a
  disabled option clears the highlight (select.js keeps it); focus that leaves to nowhere (a
  window blur) does not close the panel; the match count is a live region, not a status role,
  and Flutter has no listbox / option roles (a list of selectable rows); no `data-*` mirroring;
  the label and hint sit about 1 px higher (line box rounding, see Text). In a Flutter web
  view that has never had focus, focusing the search first focuses the view, which moves
  focus to the first focusable widget and closes the panel: the look-alike fixture focuses
  the field before opening (a click does the same in a real page).
- Combobox: no form participation (`name`, `required`, `pattern`, `minlength`, reset, state
  restore, validity): the owner keeps the value and sets `error`; `maxLength` only limits
  typing; no child `<option>` source and no `selected` option default; no combobox role in
  semantics (Flutter's `SemanticsRole.comboBox` is not usable yet): the field is a text field
  that reports expanded, the list a list; no `aria-activedescendant` (the highlighted row is
  not announced); the current value is scrolled into view at the edge of the list on open,
  not centred; a pointer over a disabled option clears the highlight; the field's text
  selection colour is the focus colour at 25 % (the browser's own on the web); the label and
  hint sit about 1 px higher (line box rounding, see Text); no `data-*` mirroring. As on the
  web, an inline completion keeps the typed letters' case ("ba" completes to "banana").
- Text: Flutter rounds every line box to whole pixels (14 px at 1.4 is
  20 px tall, not 19.6), so text with a fractional line height runs up to
  half a pixel taller per line than on the web (progress labels: 34.5 px
  per bar instead of 34). No text style turns it off.
- Button: the label sits about 1 px higher than on the web (look-alike
  check, every size); `line-height: normal` instead of `height: 1` did not
  fix it.

- Command palette: shortcuts and key hints are plain text ("Mod+N", "↑ ↓", "↵", "Esc"), the
  web fallback without `<kakao-kbd>`; the demo loads kbd, so its keycaps (Ctrl + N) make the
  web hint row about 5 px taller (look-alike check); no `href` / `target` commands (navigate in
  `onSelect`, which cannot be cancelled); icons are widgets, not SVG markup; no `list-data`
  JSON, `open` attribute or `commands` getter (the owner passes `commands` and uses the
  controller); no combobox / listbox / option roles or `aria-activedescendant` (the field is a
  text field reporting expanded, the list a list of buttons, the active row is not announced);
  a pointer over a disabled row clears the highlight; the hotkey listens through
  `HardwareKeyboard` while the widget is mounted (a key another handler already used still
  toggles it); the system back gesture closes it as a route (the web has none); scroll lock is
  the modal route's barrier; recent ids live as long as the widget's state; `pointer: coarse`
  is the platform (Android, iOS, Fuchsia), as in the menu.

## Seen on the web side

- Progress: at 30 % of 4 segments the web draws a sliver of fill at the start
  of the empty third segment (look-alike check, `progress-tones`, Danger).

## Later

- `tokens.json` compact format (formatVersion 2).
- Browser fixtures in kakao-components re-recorded in Firefox.
- iOS builds.
- Multi dropdown: no form participation (`name`, `required`, reset, validity): the owner keeps
  the value; no `setData` (the owner passes new `segments`); events are callbacks; no listbox /
  option roles or `aria-activedescendant` (the boxes are buttons named "<segment>, <value>",
  the list a list with selected rows); the list stays 8 px inside the screen (the web one is
  plain `position: absolute` and may run off it); a pointer over a disabled option clears the
  highlight; a keyboard move scrolls the row to the list's edge, not 4 px past it; the cramped
  check compares the shrunk box with its long placeholder (the web measures the rendered
  span), and a box never shrinks below its padding and chevron (the group can then be wider
  than its room); boxes are sized from Flutter's text metrics, so they can differ by a
  fraction of a pixel; focus that leaves to nowhere (a window blur) does not close the list.
