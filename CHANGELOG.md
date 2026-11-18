# Changelog

## Unreleased

- Themes, shared tokens and component settings generated from kakao-components'
  `tokens.json` (`tool/generate.dart`), tested against it in every theme and contrast mode.
- Shadows now as soft as on the web (CSS blur converted to Flutter's blur radius).
- `KakaoCard`: header, body, footer; glow from the first footer button; glides to a new height.
- `KakaoDialog` / `showKakaoDialog`: scrim and panel motion, title, scrolling body, footer
  positions, full width, Escape and outside tap (or no-dismiss). The corner nesting rule is
  measured after layout, as on the web, so it works for wrapped buttons too.
- `KakaoProgress`: segments, fill timing, the pop rule, indeterminate sweep, tones, sizes.
- `KakaoPopover`: click, hover and manual triggers; four placements with flip and keep-on-screen;
  arrow; header with close button; slotted content or label / value rows with roving focus;
  fade in, close at once; outside tap and Escape (focus back to the anchor); disabled.
- Internal anchored panel (`lib/src/internal/kakao_anchored_panel.dart`) for popover, menu,
  select and the pickers: placement, flip rules, height capped by the room, entry motion,
  dismissal and focus return. Look-alike check: cases can open their element first (`open`).
- `KakaoMenu`: trigger (`for`), context menu (`context-for`: secondary click, long press,
  Shift+F10 / Menu key), `openAt`, and inline; groups with headings, separators, icons,
  shortcut hints, danger tone, checkbox and radio items (`keepOpen`), submenus (hover after
  140 ms, Right / Left, Escape closes the submenu first); four placements with flip toward
  more room and height capped by the room; cancelable `onSelect`; disabled.
- Internal option list (`lib/src/internal/kakao_option_list.dart`) for menu, the button's menu
  mode, select, combobox, multi-dropdown and command palette: rows with check mark or icon,
  one highlight for keys and pointer (arrows wrap, Home / End, type-ahead, Enter), disabled
  rows, groups with headings, separators. The anchored panel takes `anchorInsets` and a shared
  `tapRegionGroup` (submenus).
- `KakaoButton` menu form (`list-data`): `menu`, `selected`, `showSelected`, `noChevron`,
  `onSelect` (value, label, previous, position), `onMenuChanged`, `onMenuHover` (mouse only),
  `KakaoButtonMenuController`; chevron that turns over; icon-only dropdowns as a pill (round
  with `noChevron`); the menu from the button's own `--kakao-button-menu-*` settings on the
  anchored panel and option list: opens on the checked item (last with Up), keys, type-ahead,
  disabled items, flips above without room, lines up with the right edge, enters with fade,
  slide and 97 % scale. A theme picker is `onMenuHover` + `onSelect` setting the theme.
- `KakaoButtonSegment` (`.kakao-button-segment`): toggle buttons in one tray, pressed item on
  `segment-pressed-bg`, variant hover colours, the settling shadow when an item becomes pressed.
- Anchored panel motion takes an entry `scale` (from the corner at the anchor); the option
  list controller takes its own type-ahead reset.
- `KakaoSelect`: options and groups (`KakaoSelectOption`, `KakaoSelectGroup`), single or
  `multiple`; the field look (label, hint, error with danger border and invalid semantics,
  placeholder, sizes 36 / 44 / 52, disabled, focus border and outline, chevron that turns
  over), "+N" for more values; the panel on the anchored panel (below, as wide as the field or
  `panel-min-width`, flips toward more room once on open, capped by `panel-height` and the
  room) with a focused search that filters (case and accents ignored), groups that hide
  without matches, "No matches", a polite match count; check mark and weight 600 on the
  selected option, a checkbox per row and a tri-state "Select all (N matches)" row in a
  multiple select; keys as select.js (a letter on the field opens with it in the search,
  Delete clears, arrows and Page Up / Down clamp, Enter picks, Alt+Up / Escape / Tab close);
  `onChanged` (values, previous), `onOpenChanged`, `KakaoSelectController`. The option list
  style takes a `checkBuilder` for the checkbox lead.
- `KakaoCombobox`: a text field with suggestions (`KakaoComboboxOption`, `KakaoComboboxGroup`):
  typing opens and filters the select's panel (case and accents ignored, groups hide, "No
  matches", a polite count); free text with a first "Use “text”" row (`createLabel`,
  `noCreate`), `strict` (unlisted text reverts), inline completion (`autocomplete: both`, the
  added part selected; `none` does not filter); keys as combobox.js (Down / Up / Page keys
  clamp, Alt+Down / Alt+Up, Enter picks or commits, Escape closes then clears, Tab commits),
  focus stays in the field, leaving it commits; check mark on the current value; `maxLength`;
  `onChanged` (value, label, option, previous), `onCreate`, `onTextChanged`, `onOpenChanged`,
  `KakaoComboboxController`. The field chrome moved out of select into
  `lib/src/internal/kakao_field.dart` (`KakaoField`, `KakaoFieldBox`, `KakaoRing`,
  `KakaoChevronPainter`, `kakaoFold`) with a new `KakaoFieldText` (a bare one-line text field
  with pointer gestures and a placeholder). Look-alike cases can `type` after opening.

- Themes generated from kakao-components v0.9.0 (7 themes, more-contrast colours).
- Shared tokens, Inter Tight variable font.
- `KakaoButton`.
- Showcase app with an in-app updater fed by the rolling `debug` release.
- `KakaoMultiDropdown` (`<kakao-multi-dropdown>`): several dropdowns joined into one input group
  holding one value; the date preset (`KakaoMultiDropdown.date`: dd.mm.yyyy, impossible days
  disabled, a clamped day comes back) and custom segments with a separator; "Unknown" parts
  (`allowUnknown`, per segment `unknown`), shown as "–"; boxes as wide as their widest label,
  short placeholders when cramped, ellipsis when tight; shared borders, raised open / focused
  box with the focus outline; centred current value on open; keys (step, open, move between
  boxes, type-ahead that moves on, Delete) and pointer (hover highlight); controller with
  `value`, `parts`, `setPart`, `clear`, `open`. It is not a multiple select: no checkboxes,
  search or "Select all". Option list: `KakaoOption.textStyle` and `selected`,
  `KakaoOptionList.initial` (highlighted from the start and centred).
- `KakaoCommandPalette` (`<kakao-command-palette>`): a modal search over the app's actions
  (`KakaoCommand`: label, id, value, group, keywords, shortcut, icon, disabled), opened with a
  hotkey (`Mod+K` by default, any combination, "none"; a key without Ctrl / Meta / Alt is
  ignored while a text field has focus) or `KakaoCommandPaletteController.open(query)`; on the
  root navigator over the scrim, fading in while it drops 6 px and grows from 99 %, closing at
  once; focus in the field, given back on close; a full-width sheet at the top below 640 px.
  Search as command-palette.js (case and accents ignored, every word on the label as a piece
  or as letters in order from a word start, or on a keyword), matched letters marked, groups
  ordered by their best match, an empty text, a polite count; `recent` commands first under
  "Recent"; keys (arrows wrap, Home / End, Page Up / Down eight on, disabled skipped, Enter
  runs, Tab stays, Escape closes), pointer hover and tap; key hints row (not on touch);
  `inline` mode; `onSelect` after closing, `onOpen`, `onClose`. Option list: `labelSpans`,
  `groupGap`, `revealStart`; `KakaoFieldText.selectAllOnFocus`.
- `KakaoTextInput` (`<kakao-text-input>`): a one-line field with label, hint, error (danger border
  and outline, invalid in semantics), placeholder, a leading `icon` in the muted colour, a
  `clearable` round ✕ button (empties, focuses, reports `onChanged`, `onCommitted`,
  `onCleared`), sizes 36 / 44 / 52, `type` (password dots, the keyboard for email, url, tel,
  number, search), `maxLength`, `autofillHints`, `disabled`, `readOnly`; `onChanged` on every
  edit and `onCommitted` on blur or Enter when the text changed; `value` from the owner or a
  `controller`; the border fades in 150 ms, at once with reduced motion. Field chrome:
  `KakaoFieldText` takes `readOnly`, `keyboardType`, `obscureText`, `autofillHints`,
  `textInputAction`, `onSubmitted` and several lines (`maxLines`, `minLines`);
  `KakaoChangeTracker`, `KakaoFieldButton`. Settings generated for text-input, also checked
  against tokens.json.
