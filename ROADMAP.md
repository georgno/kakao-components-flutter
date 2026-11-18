# Roadmap

Ported: button (with its menu form and segmented group), tooltip, card, dialog, progress,
popover, menu, select, combobox, multi-dropdown, command-palette, text-input, textarea,
password-input, number-input, date-input, time-input, tag-input, code-input (plus theme-switch settings for the cross-fade
and chip settings for the tags). The order below follows
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
empty state), text-input (label and hint, search with icon and clear button, error, sizes,
disabled and read only), textarea (label, counter, auto-growing, error, sizes), password-input (basic, hint and error, sizes,
disabled / read only / no toggle, default requirements, own requirements), number-input (default,
sm, the touch layout grouped right and left, split, plus only, disabled), date-input (date,
time, datetime-local, month, week, the today tag, sizes, disabled / read only / error; the
picker is the browser's own on the web, so it has no pair), time-input (time, step 900, seconds, over
midnight, the now tag, sizes, disabled / read only / error), tag-input (keywords, wrapping tags, the
suggestions opened while typing "e", sizes, disabled / read-only / error), code-input (basic, grouped,
PIN, alphanumeric with separator, error, sizes, disabled / read only).

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
  For text-input (done) `KakaoFieldText` took `readOnly`, `keyboardType`, `obscureText`,
  `autofillHints`, `textInputAction`, `onSubmitted` and `maxLines` / `minLines` (several lines:
  multiline keyboard, Enter is a new line, placeholder at the top: for `textarea`); new are
  `KakaoChangeTracker` (the input's `change`: on blur or Enter, only when the text differs from
  the text at focus) and `KakaoFieldButton` (a small round pointer-only button inside the box,
  hover colour, own tap region group: the clear button; the password toggle and number steppers
  can use it or follow it). `KakaoTextInput` is the model for the family: `value` or a
  `controller`, `onChanged` (input) / `onCommitted` (change), the `sm` / `lg` literals, the icon
  slot (`IconTheme` in the muted colour), the 150 ms `ease` border fade.
  For textarea (done) `KakaoField` took a `counter` (beside the message at the end, alone at the
  start: the `.below` flex row); `KakaoTextarea` puts its own padding inside a `KakaoFieldBox`
  with `paddingX: 0` (the textarea's padding scrolls with it on the web) and is the model for a
  field that grows with its content.
  For password-input (done) `KakaoField` took `messageMinWidth`: the `counter` slot then keeps to
  the end, beside the message while the message keeps that width, else on its own line under it
  (password-input.js `.messages`, the Caps Lock warning). `KakaoRing` now always builds its Stack
  (passthrough constraints), so what is inside a field box keeps its state when the outline comes
  and goes (focus moving from the input to a button in the box rebuilt it before).
  `KakaoPasswordInput` puts its own side padding in the row (`paddingX: 0` on the box) to end
  with a focusable button inside the box (its private `_Toggle`: radius, hover fill, own outline,
  in the field's tap region group); number-input's steppers can follow it. It is also the model
  for a field with content under its messages (the strength bar and requirement list, outside
  `KakaoField`, with the disabled opacity over all).
  For number-input (done) nothing new in `kakao_field.dart`: its steppers are aria-hidden and
  pointer only (no focus, no outline), so they are private to `KakaoNumberInput` and not built
  on password-input's `_Toggle`; it uses `KakaoFieldBox` with `paddingX: 0` and its own padding
  (the generated `input-padding`), the steppers in a Stack over the input, in the field's tap
  region group so a press keeps focus. The generator now emits `EdgeInsets` for `*padding`
  settings that hold 1-4 lengths (CSS shorthand order); textarea and multi-dropdown read theirs
  from the settings now.
  For date-input (done) three new internal blocks, which time-input can take as they are:
  `kakao_date_values.dart` (`KakaoDateKind`, `KakaoDateFields`, ISO parse / write, ISO weeks,
  `kakaoTodayValues` / `kakaoInRange` from date-input.js, `KakaoDateFormat.forLocale`: the field's
  part order, separators, 12 / 24 hours and placeholders, `kakaoPartStep` for minutes and
  seconds); `kakao_segment_field.dart` (`KakaoSegmentField`: the browser's segmented field,
  owner-held parts, `onCommit` at the native `change` point, Alt+Down / F4 / a touch tap open the
  picker); `kakao_date_picker.dart` (`KakaoDatePicker` with `KakaoPickerStyle`: month calendar,
  year of months, time columns; `kind: time` is the time picker alone). `KakaoDateInput` is the
  model: the picker's chrome from the select's panel settings (the web has none: the browser
  draws its picker), the today tag in `KakaoField`'s `counter` slot with `messageMinWidth: 0`.
  For time-input (done) the date blocks as they were, plus `kakao_date_parts.dart`
  (`KakaoPickerIcon`: the redrawn picker indicator with the calendar / clock glyph, a tab stop;
  `KakaoTodayTag`: the today / now tag as a button, disabled with a reason), moved out of
  date-input; `kakaoTimeSeconds` in the values; the picker's time columns take an `enabled` rule
  and dim / skip rows outside `min` / `max` (time, over midnight, and datetime-local on the
  bound's day). `KakaoTimeInput` is `KakaoDateInput` fixed to time with its own settings block.
  For code-input (done) nothing new in `kakao_field.dart`: `KakaoField`, `KakaoChangeTracker`
  and `KakaoFieldBox` (one per drawn box, `paddingX: 0`, its `ring` on the current box) as they
  are. It is the model for a field drawn over a hidden real one: a bare transparent
  `EditableText` under the drawn row (not `KakaoFieldText`: its caret, placeholder and selection
  gestures would show), a `TextInputFormatter` that sees every user edit (old and new value) and
  rewrites it, the controller's selection kept on the current part, a `Focus` above it for the
  keys it moves by itself, and the row in a `TapRegion` of the field's group so a tap on it keeps
  the editing going.
- Then: `text-input` (done), `textarea` (done), `password-input` (done), `number-input` (done),
  `date-input` (done), `time-input` (done),
  `tag-input` (done), `code-input` (done), `color-code`, `color-picker`, `file-upload`.

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

- Text input: no form participation (`name`, `required`, `pattern`, `minlength`, `min` /
  `max` / `step`, reset, validity and its browser messages): the owner checks the value and
  sets `error`; `maxLength` only limits typing; `type` only picks the keyboard (password: dots),
  so email / url / number are not validated and number gets no spinner; no `icon` attribute
  shortcut (an icon font class): the icon is a widget; no `data-*` mirroring; the clear button
  shows on a disabled or read-only field but does nothing there (on the web it still clears);
  no Escape-clears of the browser's `type="search"`; the error is not a live `alert` region;
  the ✕ is drawn in a fallback font, so it is larger and thinner than the web's (look-alike
  check, as in the popover); the field's text selection colour is the focus colour at 25 %;
  the label and hint sit about 1 px higher, so a field with a label is 1 px shorter (line box
  rounding, see Text; look-alike check); a size change also animates the height (the web
  only fades the border and background).
- Textarea: no form participation (`name`, `required`, `minlength`, reset, validity and its
  browser messages): the owner checks the value and sets `error`; `maxLength` only limits typing
  (and counts as the counter does, UTF-16 units, while typing is limited by characters); the
  height follows Chromium's `field-sizing: content` (content or `min-height`, `rows` set aside):
  `rows` here is a least height, as in a browser without it; `resize` has no `both` /
  `horizontal` (the textarea fills the field's width, so on the web they only add a grip);
  the grip is drawn after Chromium's (look-alike check: close, not exact) and shows on
  touch platforms too, but does nothing on a disabled field; the textarea's padding does not
  scroll with the text (it clips at the padding); no scrollbar while it scrolls; a tap below
  the text puts the caret at the end, not under the pointer; no `data-*` mirroring; the error is
  not a live `alert` region; the field's text selection colour is the focus colour at 25 %; the
  label and message lines round up, so a field with a label and a message is 1 px taller
  (139.4 → 140, look-alike check; see Text).

- Password input: no form participation (`name`, `required`, `minlength` / `maxlength` validity,
  reset, state restore, `validity` / `checkValidity`): the owner checks; `required-strength` gives
  `KakaoPasswordRequirements.strengthMessage` (from `onRequirementsChanged` or
  `KakaoPasswordInput.evaluate`) for the owner to show as `error` or to block its form, and Enter
  calls `onSubmitted` instead of submitting a form; `maxLength` only limits typing; no `list-data`
  JSON: requirements are `KakaoPasswordRequirement` objects (`.pattern` uses Dart's `RegExp`, which
  follows JavaScript's; the `v` flag counts as `u`); `password-input-requirements` is not reported
  for the first build (the web fires it on connect); Caps Lock is read from
  `HardwareKeyboard.lockModesEnabled` on keys and pointer downs in the field (a soft keyboard has
  none, so it never shows there); the toggle reports `toggled` in semantics (Flutter has no
  pressed state); the announcements are a live region, so the same words twice in a row are not
  announced again (the web empties it first), and their wording is English in code (`texts` has
  the names); the error is not a live `alert` region; no `forced-colors` rules; no `data-*`
  mirroring; mobile platforms show the last typed character for a moment (Flutter's
  `obscureText`); the field's text selection colour is the focus colour at 25 %; labelled fields
  are 1 px shorter (line box rounding, see Text; look-alike check: 0.1-0.5 %, the error case 1.9 %
  from that 1 px shift).

- Number input: no form participation (`name`, `required`, validity, reset); arrow keys step
  with the steppers' rule (value + step, clamped, rounded to the step's decimals, input and
  change at once) instead of the browser's `stepUp` (which snaps to the step base `min` and
  treats an empty field differently); no wheel stepping over the focused input itself (only
  over the steppers, as number-input.js does); typed text is only filtered to the characters
  Chromium lets in, an invalid text reports null (the web's `""`); `readOnly` also stops the
  steppers (number-input.js only checks `disabled`); while a stepper is held, leaving it with
  the mouse stops the repeat per button in the touch layout (the web listens on the strip, so a
  joined pair keeps repeating across both); the field reports increase / decrease actions in
  semantics (the web's spinbutton role), the steppers stay hidden as on the web; `font-size:
  inherit` reads the surrounding `DefaultTextStyle` (the look-alike fixtures set the demo
  page's 16 px); the ▲ / ▼ glyphs come from a fallback font; `pointer: coarse` is the platform
  (Android, iOS, Fuchsia), as in the menu, and does not follow a pointer change at runtime; the
  field's text selection colour is the focus colour at 25 %; no `data-*` mirroring. Look-alike
  check: 0.0-0.1 % different in light and dark, same heights (38, 35, 44).

- Date input: the web keeps the browser's own field and picker; here both are drawn: the field
  after Chromium's (parts, keys, placeholders), the picker in the library's look (the select's
  panel chrome, ink for the pick), not Chromium's popup: its layout (36 px cells, a year of
  months one year at a time, time columns seven rows high, Clear and Today at the foot) is ours;
  the picker's words are English (`KakaoDateInput.texts`) apart from the month names of the
  field's format and the today label; the field's format comes from a built-in table of locales
  (others get ISO order and 24 hours; month names only in English: other languages show the month
  as a number; "Week" / "Woche" / "Semaine" / "Semana"), not from ICU; the today label is known for
  en, de, fr, es, it (else English); no form participation (`name`, `required`, validity and its
  messages, reset, state restore): the owner checks and sets `error`; no Firefox / Safari text
  fallback (YYYY-MM) and no millisecond part (a value's milliseconds are dropped); the time
  columns dim rows outside `min` / `max` but not rows off `step` (a minute column only lists
  step values where the step divides the hour); typing goes through hardware keys only (no
  soft keyboard: on touch platforms a tap opens the picker, as Chrome on Android opens its
  dialog); a part counts digits as Chromium does, so each year digit reports a value (0002, 0020,
  0202, 2026); the field is one node in semantics (its name, value and hint), not a spin button per
  part; the disabled today tag's reason is a semantics hint, not a `title` tooltip, and the tag's
  tap target is the drawn 20 px tag (the web widens it to 24 px); no `forced-colors` rules; no
  `data-*` mirroring; the focused part is filled with the focus colour at 25 % (the browser's
  `Highlight`); labelled fields are 1 px shorter (line box rounding, see Text; look-alike check:
  0.1-0.4 %, the states case 1.4 % from that shift).

- Time input: the same field and picker as date-input's time type (see Date input: the field
  drawn after Chromium's, the picker ours, a built-in locale table, hardware keys only, one
  semantics node, no `forced-colors`, no `data-*`, the focus colour at 25 % for the focused
  part); no Firefox clock button or its `moz-nudge` (the setting is generated but unused) and no
  ISO text fallback (`HH:MM` with a pattern) for a browser without a time field; no form
  participation (`name`, `required`, validity and its messages, reset, state restore): the owner
  checks and sets `error`; no `locale` following a `lang` change elsewhere (it follows
  `Localizations`); `valueAsNumber` returns null for the web's NaN, and the field drops a
  value's milliseconds; the now label is known for en, de, fr, es, it (else English); the
  disabled tag's reason is a semantics hint, not a `title` tooltip, and its tap target is the
  drawn 20 px tag (the web widens it to 24 px); time columns grey out rows outside `min` / `max`
  where Chromium's picker (which the web uses) shows its own list; labelled fields are 1 px
  shorter (line box rounding, see Text; look-alike check: 0.2-0.7 %, states 1.3-1.4 % from
  that shift and the 2 px it adds over three fields).

- Tag input: no form participation (`name`, `required`, reset, state restore, validity and its
  messages): the owner checks the tags and sets `error`; `value` / `list-data` attributes are
  lists here (`KakaoTagInput.parse` / `join` read and write the web's string form); events are
  callbacks (`onTagAdd` / `onTagRemove` return false to cancel); the tags are not a list of list
  items in semantics (each chip is a node named after its tag, selected while it has focus, with
  its "Remove <tag>" button), and the text is a text field that reports expanded while
  suggestions are open (no combobox role, no `aria-activedescendant`); the status is a live
  region with English words (`KakaoTagInput.texts`); Ctrl / Cmd+V reads the clipboard itself
  (lines and tabs split as on the web), but a paste from the context menu or a soft keyboard
  goes through the one-line field, which drops line breaks first (only the delimiters split it),
  and any edit that inserts several characters holding a delimiter counts as a paste (every part
  becomes a tag); a character typed on a selected tag is inserted by the widget (hardware keys,
  no IME composition); the ✕ outline shows on a tag selected by keys, not on one selected by a
  tap or after a tap on a ✕ (Chromium's `:focus-visible` guess); Escape on a selected tag stops
  there (the web lets it bubble); a disabled field's tags cannot take focus; the ✕ tap target is
  the chip's height by 21 px (the web widens it to 24 × 24); a pointer of any kind highlights a
  suggestion (the web: the mouse only); the chip is the internal `KakaoChipView` (chip is not
  ported: no swatch, icon, meta, link or action); no `forced-colors` rules; no `data-*`
  mirroring; the text selection colour is the focus colour at 25 %; labelled fields are 1 px
  shorter (line box rounding, see Text; look-alike check: 0.1-0.5 %, the open panel 1.7-1.9 %
  from text, the states case 1.0 % from that shift over three fields).

- Code input: no form participation (`name`, `required`, validity with its tooShort /
  valueMissing messages, reset, state restore, `form`): the owner checks the code and sets `error`
  (`onCompleted` / `onSubmitted` stand for the demo's `requestSubmit`); no `:state(complete)`
  (the owner compares the length); `value` / `length` / `clear()` / `focus()` are the
  controller, `length` and the focus node; a focus from outside (Tab, the focus node) lands on the
  first empty box as `focus()` does (Chrome's select-all on Tab puts the web one on the first
  box); a user insert of more than one character counts as a paste (a whole code replaces the
  value), so an IME committing several characters at once does too; no long-press paste menu on
  touch platforms (the hidden field has no selection gestures or toolbar; paste goes through the
  keyboard's clipboard suggestion or Ctrl / Cmd+V); no drop of dragged text; a tap places the box
  on release (the web focuses on press); the drawn boxes ignore a drag across them (no mouse
  selection: select all with Ctrl / Cmd+A tints the boxes); `pattern` uses Dart's `RegExp`
  (JavaScript's rules, the `u` flag); the count read with the field ("6 digits") is English
  (`KakaoCodeInput.texts`) and joined to the hint and error as one semantics hint; the error is not
  a live `alert` region; the caret blinks on a timer (Flutter's own caret stays hidden); no
  `forced-colors` rules; no `data-*` mirroring; labelled fields are 1 px shorter (line box
  rounding, see Text; look-alike check: 0.0-0.4 %, the error case 1.5 % from that shift).

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
