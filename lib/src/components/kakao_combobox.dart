import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../internal/kakao_anchored_panel.dart';
import '../internal/kakao_field.dart';
import '../internal/kakao_option_list.dart';
import '../settings/kakao_combobox_settings.g.dart';
import '../theme/kakao_theme.dart';

/// `<kakao-combobox size>`.
enum KakaoComboboxSize { sm, md, lg }

/// `<kakao-combobox autocomplete>`.
enum KakaoComboboxAutocomplete {
  /// Typing filters the list (the default).
  list,

  /// Typing filters the list and completes the first match in the field,
  /// the added part selected, so typing on replaces it and Backspace
  /// removes it.
  both,

  /// The list is not filtered.
  none,
}

/// An entry of `list-data`: a [KakaoComboboxOption] or a [KakaoComboboxGroup].
@immutable
sealed class KakaoComboboxEntry {
  const KakaoComboboxEntry();
}

/// A suggestion (`{ value, label?, disabled? }`, or a plain string: the value).
class KakaoComboboxOption extends KakaoComboboxEntry {
  const KakaoComboboxOption(this.value, {String? label, this.disabled = false}) : label = label ?? value;

  final String value;

  /// Shown in the list, and in the field once picked; default: [value].
  final String label;

  /// Shown in the muted colour, cannot be picked, skipped by the keys.
  final bool disabled;
}

/// Suggestions under a heading (`{ label, options }`, `<optgroup label>`).
/// [disabled] disables all of them.
class KakaoComboboxGroup extends KakaoComboboxEntry {
  const KakaoComboboxGroup(this.label, this.options, {this.disabled = false});

  final String label;
  final List<KakaoComboboxOption> options;
  final bool disabled;
}

/// `combobox-change` (with `input` and `change`): the user changed the value.
@immutable
class KakaoComboboxChange {
  const KakaoComboboxChange._(this.value, this.label, this.option, this.previous);

  /// The option's value, or the free text; "" when cleared.
  final String value;

  /// The text in the field.
  final String label;

  /// The picked option; null for free text.
  final KakaoComboboxOption? option;

  /// The value before.
  final String previous;
}

/// Opens and closes a [KakaoCombobox]'s list (`open()`, `close()`, `isOpen`).
class KakaoComboboxController extends KakaoAnchoredPanelController {}

// combobox.js values outside the settings block.
const _smSize = (
  height: 36.0,
  paddingX: 10.0,
  font: 14.0,
); // --kakao-combobox-sm-height / -sm-padding-x; .field 0.875rem
const _lgSize = (height: 52.0, paddingX: 14.0, font: 16.0); // --kakao-combobox-lg-height / -lg-padding-x; .field 1rem
const _toggleGap = .6; // .toggle padding-left: calc(var(--_padding-x) * 0.6)
const _chevronTurn = Duration(milliseconds: 200); // .toggle svg transition: transform 200ms
const _labelSize = 13.12; // .label font-size: 0.82rem
const _messageSize = 12.48; // .hint, .error font-size: 0.78rem
const _pageStep = 8; // PAGE_STEP
const _rowPadding = EdgeInsets.symmetric(vertical: 6.4, horizontal: 9.6); // .row padding: 0.4rem 0.6rem
const _rowGap = 8.8; // .row gap: 0.55rem
const _rowLineHeight = 1.3; // .row line-height: 1.3
const _checkSize = 1.1; // .check width: 1.1em
const _plusStroke = 2.6; // .check svg stroke-width: 2.6
const _selectedWeight = 600.0; // .row[aria-selected="true"] font-weight: 600
const _headingSize = 12.48; // .group-label font-size: 0.78rem
const _headingWeight = 600.0; // .group-label font-weight: 600
const _headingPadding = EdgeInsets.fromLTRB(9.6, 8.8, 9.6, 4); // .group-label padding: 0.55rem 0.6rem 0.25rem
const _emptyPadding = EdgeInsets.symmetric(vertical: 12, horizontal: 9.6); // .empty padding: 0.75rem 0.6rem
const _emptyFont = .9; // .empty font-size: 0.9em
const _entrySlide = 4.0; // @keyframes kakao-combobox-in: translateY(-4px), 4px when opened above
const _statusDelay = Duration(milliseconds: 400); // _announce: setTimeout(…, 400)
const _selectionAlpha = .25; // the text selection: the focus colour, light

/// Flutter twin of `<kakao-combobox>`: a text field with suggestions.
/// Typing filters a list below the field, and the user either picks a
/// suggestion or keeps their own text as the value (an editable combobox
/// with list autocomplete, as in the ARIA APG).
///
/// The field, as combobox.js draws it from the `--kakao-combobox-*`
/// settings (the text input's field with the select's chevron): [label]
/// above (a tap on it focuses the field and opens the list), [hint] below,
/// or [error] instead (danger border and outline, invalid in semantics); the
/// [placeholder] in the muted colour while empty. Sizes 36 / 44 / 52 px.
/// The border takes the focus colour while the list is open or the field
/// has focus; focus adds the 2 px outline, 2 px away (an input matches
/// `:focus-visible` whenever it is focused). The chevron turns over while
/// open; a tap on it opens or closes the list and leaves focus in the field.
/// [disabled] dims everything to `disabled-opacity`. The field fills the
/// width it gets.
///
/// The list is the select's panel: below the field, `panel-offset` away, as
/// wide as the field (at least `panel-min-width`), at most `panel-height`
/// and the room on its side tall; above when there is no room below and
/// more above (chosen when it opens, so typing doesn't flip it); fades in
/// from 4 px back over `duration`, closes at once, appears at once with
/// reduced motion. Rows show a check mark (and weight 600) on the current
/// value's option; groups without matches hide; [emptyText] shows when
/// nothing matches.
///
/// Typing opens the list and filters it (case and accents ignored,
/// anywhere in the label; not at all with [KakaoComboboxAutocomplete.none]).
/// While the text is not empty and names no option, a first row "Use
/// “text”" ([createLabel]) keeps it as the value; [noCreate] hides that row
/// but still keeps free text; [strict] hides it and puts text that names no
/// option back to the last value when committed.
///
/// Keys in the field (ARIA APG editable combobox): Down opens and moves
/// down (starting on the current value), Up moves up, Alt+Down opens,
/// Alt+Up closes, Page Up / Page Down jump 8 rows (the moves stop at both
/// ends); Enter picks the highlighted row, or commits the text when none is;
/// Escape closes the list (dropping an inline completion), and on a closed
/// list clears the field; Tab commits the text and moves on; Home / End and
/// Left / Right stay with the caret. A pointer over a row highlights it, a
/// tap picks it. Focus stays in the field throughout.
///
/// Committing (Enter, Tab, leaving the field): text that equals an option's
/// label (case and accents ignored) picks that option; other text is both
/// value and text ([strict]: reverted); an empty field clears the value.
/// Typing alone changes nothing until it is committed.
///
/// [value] is the value the field starts with (an option's value shows its
/// label, other text shows itself); it keeps the user's changes from then on
/// and takes a new [value] from its owner, without reporting it.
class KakaoCombobox extends StatefulWidget {
  const KakaoCombobox({
    super.key,
    required this.options,
    this.value = '',
    this.onChanged,
    this.onCreate,
    this.onTextChanged,
    this.label,
    this.semanticLabel,
    this.hint,
    this.error,
    this.placeholder,
    this.autocomplete = KakaoComboboxAutocomplete.list,
    this.createLabel,
    this.noCreate = false,
    this.strict = false,
    this.emptyText,
    this.maxLength,
    this.size = KakaoComboboxSize.md,
    this.disabled = false,
    this.controller,
    this.onOpenChanged,
    this.focusNode,
    this.panelKey,
  });

  /// `list-data`: suggestions and groups.
  final List<KakaoComboboxEntry> options;

  /// `value`: the option's value, or free text.
  final String value;

  /// `combobox-change`.
  final ValueChanged<KakaoComboboxChange>? onChanged;

  /// `combobox-create`: a committed free-text value that is not in the list,
  /// so the owner can store it.
  final ValueChanged<String>? onCreate;

  /// The field's own `input` while typing: the text right now.
  final ValueChanged<String>? onTextChanged;

  /// `label`: shown above the field.
  final String? label;

  /// `aria-label`: the accessible name when there is no [label].
  final String? semanticLabel;

  /// `hint`: below the field, hidden while there is an [error].
  final String? hint;

  /// `error`: below the field, danger border, invalid.
  final String? error;

  /// `placeholder`.
  final String? placeholder;

  /// `autocomplete`.
  final KakaoComboboxAutocomplete autocomplete;

  /// `create-label`: the free-text row, `{text}` is the typed text; default
  /// [texts]`.create`.
  final String? createLabel;

  /// `no-create`.
  final bool noCreate;

  /// `strict`.
  final bool strict;

  /// `empty-text`; default [texts]`.empty`.
  final String? emptyText;

  /// `maxlength`: limits typing.
  final int? maxLength;
  final KakaoComboboxSize size;

  /// `disabled`: dimmed, not focusable, does not open.
  final bool disabled;

  /// Opens and closes the list from outside.
  final KakaoComboboxController? controller;

  /// `combobox-open` (true) and `combobox-close` (false).
  final ValueChanged<bool>? onOpenChanged;

  /// The field's focus (`focus()`, `blur()`).
  final FocusNode? focusNode;

  /// Put on the open panel (tests, screenshots).
  final Key? panelKey;

  /// `KakaoCombobox.texts`: combobox.js's built-in English texts.
  static ({String empty, String name, String create, String Function(int n) matches}) texts = (
    empty: 'No matches',
    name: 'Combobox',
    create: 'Use “{text}”',
    matches: (n) => '$n ${n == 1 ? 'suggestion' : 'suggestions'}',
  );

  @override
  State<KakaoCombobox> createState() => _KakaoComboboxState();
}

/// A suggestion flattened out of the entries (combobox.js `_items`).
class _Item {
  const _Item(this.option, this.disabled, this.key);
  final KakaoComboboxOption option;
  final bool disabled;

  /// The folded label, for matching.
  final String key;

  String get value => option.value;
  String get label => option.label;
}

List<_Item> _flatten(List<KakaoComboboxEntry> entries) => [
  for (final e in entries)
    ...switch (e) {
      final KakaoComboboxOption o => [_Item(o, o.disabled, kakaoFold(o.label))],
      final KakaoComboboxGroup g => [for (final o in g.options) _Item(o, o.disabled || g.disabled, kakaoFold(o.label))],
    },
];

/// The shown rows: option list entries and, per row, its item.
typedef _Shown = ({List<KakaoOptionEntry> entries, List<int> rows});

class _KakaoComboboxState extends State<KakaoCombobox> {
  KakaoComboboxController? _own;
  KakaoComboboxController get _ctl => widget.controller ?? (_own ??= KakaoComboboxController());
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode(debugLabel: 'KakaoCombobox'));
  final _text = TextEditingController();
  final _list = KakaoOptionListController();

  /// The tap region group of the field and its panel: a tap in the panel
  /// does not end the editing.
  final _group = Object();

  late List<_Item> _items = _flatten(widget.options);

  /// The committed value and its text (combobox.js `_value`, `_label`).
  String _value = '';
  String _label = '';

  /// The text was typed since the last commit.
  bool _typed = false;
  bool _open = false;
  bool _focused = false;

  /// What the list is filtered by (folded), and the whole text (trimmed),
  /// taken at each input as combobox.js `_filter` does.
  String _q = '';
  String _whole = '';

  /// The "Use" row is the active row (combobox.js `_active === 'create'`).
  bool _createActive = false;

  /// The item the last input completed to (`autocomplete="both"`).
  int? _completed;

  /// The list was just closed by an Escape the field is about to see.
  bool _escapeClosed = false;
  String _status = '';
  Timer? _statusTimer;

  bool get _reduceMotion => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void initState() {
    super.initState();
    _setCommitted(widget.value);
    _ctl.addListener(_openChanged);
    _focus.addListener(_focusChanged);
    _list.addListener(_listChanged);
  }

  @override
  void didUpdateWidget(KakaoCombobox old) {
    super.didUpdateWidget(old);
    final before = old.controller ?? _own;
    if (before != _ctl) {
      before?.removeListener(_openChanged);
      _ctl.addListener(_openChanged);
    }
    final focusBefore = old.focusNode ?? _ownFocus;
    if (focusBefore != _focus) {
      focusBefore?.removeListener(_focusChanged);
      _focus.addListener(_focusChanged);
    }
    final optionsChanged = !identical(old.options, widget.options);
    if (optionsChanged) _items = _flatten(widget.options);
    if (old.value != widget.value) {
      _setCommitted(widget.value);
    } else if (optionsChanged && !_typed) {
      _setCommitted(_value);
    }
    if (_open &&
        (optionsChanged ||
            old.autocomplete != widget.autocomplete ||
            old.strict != widget.strict ||
            old.noCreate != widget.noCreate)) {
      _refilter();
      _createActive = false;
      _list.highlight(null);
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    (widget.controller ?? _own)?.removeListener(_openChanged);
    (widget.focusNode ?? _ownFocus)?.removeListener(_focusChanged);
    _list.removeListener(_listChanged);
    _own?.dispose();
    _ownFocus?.dispose();
    _text.dispose();
    _list.dispose();
    super.dispose();
  }

  /* ---------------------------- Value ---------------------------- */

  /// The option for a value (and, for free text equal to a value, its label).
  _Item? _optionFor(String value, [String? label]) {
    if (value.isEmpty) return null;
    for (final it in _items) {
      if (it.value == value && (label == null || it.label == label)) return it;
    }
    return null;
  }

  _Item? get _current => _optionFor(_value, _label);

  /// The enabled option whose label equals [text], case and accents ignored.
  _Item? _exact(String text) {
    final k = kakaoFold(text.trim());
    if (k.isEmpty) return null;
    for (final it in _items) {
      if (!it.disabled && it.key == k) return it;
    }
    return null;
  }

  void _showText(String text) => _text.value = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );

  /// combobox.js `_setCommitted`: the value and its text, without events.
  void _setCommitted(String value) {
    _value = value;
    _label = _optionFor(value)?.label ?? value;
    _showText(_label);
    _typed = false;
  }

  /// combobox.js `_commitText`: Enter, Tab, leaving the field.
  void _commitText({bool forceFree = false}) {
    final text = _text.text.trim();
    if (text.isEmpty) return _change('', '', null);
    final it = forceFree ? null : _exact(text);
    if (it != null) return _change(it.value, it.label, it);
    if (widget.strict) {
      setState(() {
        _showText(_label); // back to the last value
        _typed = false;
      });
      return;
    }
    _change(text, text, null);
  }

  void _pick(int item) {
    final it = _items[item];
    if (!it.disabled) _change(it.value, it.label, it);
  }

  /// combobox.js `_change`: reports only a real change of value or text.
  void _change(String value, String label, _Item? option) {
    final previous = _value;
    final same = value == _value && label == _label;
    setState(() {
      _value = value;
      _label = label;
      _showText(label);
      _typed = false;
    });
    if (same) return;
    widget.onChanged?.call(KakaoComboboxChange._(value, label, option?.option, previous));
    if (option == null && value.isNotEmpty && value != previous) widget.onCreate?.call(value);
  }

  /* ---------------------------- Filter and active row ---------------------------- */

  /// combobox.js `_query`: the typed part, not an inline completion.
  String _query() {
    final v = _text.value;
    final s = v.selection;
    if (widget.autocomplete == KakaoComboboxAutocomplete.both &&
        s.isValid &&
        s.end == v.text.length &&
        s.start < s.end) {
      return v.text.substring(0, s.start);
    }
    return v.text;
  }

  void _refilter() {
    _q = _typed && widget.autocomplete != KakaoComboboxAutocomplete.none ? kakaoFold(_query().trim()) : '';
    _whole = _text.text.trim();
  }

  bool get _createShown => _typed && _whole.isNotEmpty && _exact(_whole) == null && !widget.strict && !widget.noCreate;

  _Shown _shown() {
    final q = _q;
    final rows = <int>[];
    final entries = <KakaoOptionEntry>[];
    final current = _current;
    KakaoOption option(int i) {
      rows.add(i);
      final it = _items[i];
      return KakaoOption(label: it.label, disabled: it.disabled, checked: identical(it, current));
    }

    var i = 0;
    for (final e in widget.options) {
      switch (e) {
        case KakaoComboboxOption():
          if (q.isEmpty || _items[i].key.contains(q)) entries.add(option(i));
          i++;
        case KakaoComboboxGroup():
          final options = <KakaoOption>[];
          for (var n = 0; n < e.options.length; n++, i++) {
            if (q.isEmpty || _items[i].key.contains(q)) options.add(option(i));
          }
          if (options.isNotEmpty) entries.add(KakaoOptionGroup(options, label: e.label));
      }
    }
    return (entries: entries, rows: rows);
  }

  /// The keys the arrows reach, in order: -1 for the "Use" row, else rows.
  List<int> _nav() {
    final rows = _shown().rows;
    return [
      if (_createShown) -1,
      for (var r = 0; r < rows.length; r++)
        if (!_items[rows[r]].disabled) r,
    ];
  }

  void _activate(int? key, {bool keyboard = true}) {
    if (key == -1) {
      setState(() => _createActive = true);
      _list.highlight(null);
    } else {
      if (_createActive) setState(() => _createActive = false);
      _list.highlight(key, keyboard: keyboard);
    }
  }

  /// combobox.js `_move`: clamped at both ends.
  void _move(int delta) {
    final nav = _nav();
    if (nav.isEmpty) return;
    final current = _createActive ? -1 : _list.highlighted;
    var i = current == null ? -1 : nav.indexOf(current);
    if (i == -1) i = delta > 0 ? -1 : nav.length;
    _activate(nav[(i + delta).clamp(0, nav.length - 1)]);
  }

  /// Highlights [item]'s row, when it is shown and enabled; scrolls it in.
  bool _activateItem(int item) {
    final row = _shown().rows.indexOf(item);
    if (row < 0 || _items[item].disabled) return false;
    _activate(row);
    return true;
  }

  /// After the panel has built its rows (the option list knows them then).
  void _later(VoidCallback f) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _ctl.isOpen) f();
    });
  }

  void _announce(String text) {
    _statusTimer?.cancel();
    _statusTimer = Timer(_statusDelay, () {
      if (mounted) setState(() => _status = text);
    });
  }

  void _listChanged() {
    if (_list.highlighted != null && _createActive) setState(() => _createActive = false);
  }

  /* ---------------------------- Open / close ---------------------------- */

  void _openChanged() {
    final open = _ctl.isOpen;
    if (!mounted || open == _open) return;
    if (open && widget.disabled) return; // the panel closes it again
    setState(() {
      _open = open;
      _createActive = false;
      if (open) {
        _status = '';
        _refilter();
      }
    });
    _list.highlight(null);
    if (open) {
      // combobox.js _open: untyped, show where the current value sits;
      // highlighted only when the list is not filtered.
      _later(() {
        final current = _current;
        if (_typed || current == null) return;
        if (_activateItem(_items.indexOf(current)) && widget.autocomplete != KakaoComboboxAutocomplete.none) {
          _list.highlight(null);
        }
      });
    } else {
      _statusTimer?.cancel();
    }
    widget.onOpenChanged?.call(open);
  }

  void _openList() {
    if (!widget.disabled && !_ctl.isOpen) _ctl.open();
  }

  void _toggle() {
    if (widget.disabled) return;
    if (_ctl.isOpen) {
      _ctl.close();
    } else {
      _openList();
    }
    if (!_focus.hasFocus) _focus.requestFocus();
  }

  /* ---------------------------- Interaction ---------------------------- */

  void _focusChanged() {
    if (!mounted) return;
    final focused = _focus.hasFocus;
    if (focused == _focused) return;
    setState(() => _focused = focused);
    if (focused) return;
    // combobox.js focusout: leaving the field commits the typed text.
    _ctl.close();
    if (_typed || _text.text != _label) _commitText();
  }

  /// combobox.js `_onInput`'s inline completion, as a formatter: it sees the
  /// edit, so only insertions complete (Backspace removes the completion).
  TextEditingValue _complete(TextEditingValue old, TextEditingValue next) {
    _completed = null;
    if (widget.autocomplete != KakaoComboboxAutocomplete.both) return next;
    if (next.composing.isValid && !next.composing.isCollapsed) return next;
    final s = old.selection;
    final base = s.isValid ? old.text.replaceRange(s.start, s.end, '') : old.text;
    final typed = next.text;
    final caret = next.selection;
    if (typed.length <= base.length || !caret.isCollapsed || caret.end != typed.length) return next;
    final k = kakaoFold(typed);
    if (k.isEmpty) return next;
    for (var i = 0; i < _items.length; i++) {
      final it = _items[i];
      if (!it.disabled &&
          it.key.startsWith(k) &&
          it.label.length >= typed.length &&
          kakaoFold(it.label.substring(0, typed.length)) == k) {
        _completed = i;
        final text = typed + it.label.substring(typed.length);
        return TextEditingValue(
          text: text,
          selection: TextSelection(baseOffset: typed.length, extentOffset: text.length),
        );
      }
    }
    return next;
  }

  /// combobox.js `_onInput`.
  void _onInput(String text) {
    final completed = _completed;
    _completed = null;
    setState(() {
      _typed = true;
      _createActive = false;
      _refilter();
    });
    _list.highlight(null);
    _openList();
    if (completed != null) _later(() => _activateItem(completed));
    final shown = _shown().rows.length;
    _announce(
      _q.isEmpty
          ? ''
          : shown > 0
          ? KakaoCombobox.texts.matches(shown)
          : widget.emptyText ?? KakaoCombobox.texts.empty,
    );
    widget.onTextChanged?.call(text);
  }

  /// A tap on a row of the list.
  void _pickRow(int row) {
    final rows = _shown().rows;
    if (row < 0 || row >= rows.length) return;
    _ctl.close();
    _pick(rows[row]);
    _focus.requestFocus();
  }

  void _pickCreate() {
    _ctl.close();
    _commitText(forceFree: true);
    _focus.requestFocus();
  }

  /// combobox.js `_onKey`, on the field.
  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (widget.disabled || (e is! KeyDownEvent && e is! KeyRepeatEvent)) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final alt = HardwareKeyboard.instance.isAltPressed;
    final open = _ctl.isOpen;
    if (k == LogicalKeyboardKey.arrowDown) {
      if (!open) {
        _openList();
        if (!alt) {
          // Start on the current value when it is shown, else on the first row.
          _later(() {
            final current = _current;
            if (_typed || current == null || !_activateItem(_items.indexOf(current))) _move(1);
          });
        }
      } else if (!alt) {
        _move(1);
      }
    } else if (k == LogicalKeyboardKey.arrowUp) {
      if (alt) {
        _ctl.close();
      } else if (!open) {
        _openList();
        _later(() => _move(-1));
      } else {
        _move(-1);
      }
    } else if (k == LogicalKeyboardKey.pageDown || k == LogicalKeyboardKey.pageUp) {
      if (!open) return KeyEventResult.ignored;
      _move(k == LogicalKeyboardKey.pageDown ? _pageStep : -_pageStep);
    } else if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) {
      if (e is! KeyDownEvent) return KeyEventResult.handled;
      final create = open && _createActive;
      final row = open ? _list.highlighted : null;
      final rows = _shown().rows;
      _ctl.close();
      if (create) {
        _commitText(forceFree: true);
      } else if (row != null && row < rows.length) {
        _pick(rows[row]);
      } else {
        _commitText();
      }
    } else if (k == LogicalKeyboardKey.escape) {
      // An open list closes on Escape itself (the anchored panel sees keys
      // before focus does), see onDismiss; that Escape must not also clear.
      // A closed list: clear the field.
      if (_escapeClosed || open) {
        if (e is KeyDownEvent) _escapeClosed = false;
        return KeyEventResult.handled;
      }
      if (_text.text.isEmpty || e is! KeyDownEvent) return KeyEventResult.ignored;
      setState(() => _showText(''));
      _commitText();
    } else if (k == LogicalKeyboardKey.tab) {
      // Commit before focus moves on; the focus loss then finds nothing to do.
      _ctl.close();
      if (_typed || _text.text != _label) _commitText();
      return KeyEventResult.ignored;
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    final st = KakaoComboboxSettings.of(theme.colors);
    final (height, paddingX, fontSize) = switch (widget.size) {
      KakaoComboboxSize.sm => (_smSize.height, _smSize.paddingX, _smSize.font),
      KakaoComboboxSize.md => (st.height, st.paddingX, st.font.size),
      KakaoComboboxSize.lg => (_lgSize.height, _lgSize.paddingX, _lgSize.font),
    };
    final reduce = _reduceMotion;
    final error = widget.error?.isNotEmpty ?? false ? widget.error : null;
    final hint = widget.hint?.isNotEmpty ?? false ? widget.hint : null;
    final name = widget.label ?? widget.semanticLabel ?? KakaoCombobox.texts.name;
    final disabled = widget.disabled;

    Widget input = KakaoFieldText(
      controller: _text,
      focusNode: _focus,
      style: theme.text(size: fontSize, color: st.text, height: st.font.lineHeight),
      placeholder: widget.placeholder,
      placeholderColor: st.muted,
      cursorColor: st.text,
      selectionColor: st.focus.withValues(alpha: _selectionAlpha),
      enabled: !disabled,
      inputFormatters: [
        if (widget.maxLength case final max?) LengthLimitingTextInputFormatter(max),
        _Completion(_complete),
      ],
      onChanged: _onInput,
      onTap: _openList,
      groupId: _group,
    );
    // A text field, expanded while the list is open (Flutter has no
    // working combobox role yet).
    input = Semantics(
      label: name,
      hint: error ?? hint,
      expanded: _open,
      enabled: !disabled,
      validationResult: error != null ? SemanticsValidationResult.invalid : SemanticsValidationResult.none,
      child: ExcludeFocus(
        excluding: disabled,
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          includeSemantics: false,
          onKeyEvent: _onKey,
          child: input,
        ),
      ),
    );

    // .toggle: a pointer-only button (aria-hidden, tabindex -1) reaching
    // the field's right edge; the chevron sits padding-x from it.
    final toggle = ExcludeSemantics(
      child: MouseRegion(
        cursor: disabled ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: disabled ? null : _toggle,
          child: Container(
            height: height - 2,
            padding: EdgeInsets.only(left: paddingX * _toggleGap, right: paddingX),
            alignment: Alignment.center,
            child: AnimatedRotation(
              turns: _open ? .5 : 0,
              duration: reduce ? Duration.zero : _chevronTurn,
              curve: st.ease,
              child: CustomPaint(
                size: Size.square(st.chevronSize.of(fontSize)),
                painter: KakaoChevronPainter(st.muted),
              ),
            ),
          ),
        ),
      ),
    );

    final box = KakaoFieldBox(
      height: height,
      // The side padding is on the input and the toggle (the toggle's hit
      // area reaches the edge).
      paddingX: 0,
      radius: st.radius,
      background: st.bg,
      // :host([error]) wins over focus and open.
      border: error != null
          ? st.danger
          : _open || _focused
          ? st.focus
          : st.border,
      ring: _focused && !disabled ? (error != null ? st.danger : st.focus) : null,
      ringWidth: st.focusWidth,
      ringOffset: st.focusOffset,
      duration: reduce ? Duration.zero : st.duration,
      curve: st.ease,
      child: Row(
        children: [
          SizedBox(width: paddingX),
          Expanded(child: input),
          toggle,
        ],
      ),
    );

    final field = KakaoAnchoredPanel(
      controller: _ctl,
      enabled: !disabled,
      // combobox.js _place (as select.js): below, panel-offset away, from the
      // field's left edge (its right edge without room, else pushed 8 px
      // inside); above when there is no room below and more above, chosen on
      // open; as wide as the field or panel-min-width; capped by max(120, room).
      placement: KakaoPanelPlacement(
        side: KakaoPanelSide.bottom,
        align: KakaoPanelAlign.start,
        offset: st.panelOffset,
        flip: KakaoPanelFlip.towardMoreRoom,
        capToRoom: true,
        keepSide: true,
        matchAnchorWidth: true,
        minWidth: st.panelMinWidth,
      ),
      motion: KakaoPanelMotion(duration: st.duration, curve: st.ease, slide: _entrySlide),
      // Focus never leaves the field.
      returnFocus: false,
      tapRegionGroup: _group,
      onDismiss: (why) {
        if (why != KakaoPanelDismiss.escape) return;
        _escapeClosed = true;
        // An inline completion goes away with the list.
        final q = _query();
        if (q != _text.text) setState(() => _showText(q));
      },
      panelBuilder: (context, side) => _panel(context, st, name),
      child: box,
    );

    return KakaoField(
      label: widget.label,
      message: error ?? hint,
      messageColor: error != null ? st.danger : st.muted,
      labelStyle: theme.text(size: _labelSize, weight: st.labelWeight, color: st.text, height: st.font.lineHeight),
      messageStyle: theme.text(size: _messageSize, height: st.font.lineHeight),
      labelGap: st.labelGap,
      messageGap: st.messageGap,
      disabledOpacity: disabled ? st.disabledOpacity : null,
      // <label for>: focuses the input and clicks it, which opens the list.
      onLabelTap: disabled
          ? null
          : () {
              _focus.requestFocus();
              _openList();
            },
      child: field,
    );
  }

  /// The open panel (`.panel`): the "Use" row, the suggestions on the shared
  /// option list, the empty text and the polite status.
  Widget _panel(BuildContext context, KakaoComboboxSettings st, String name) {
    final theme = KakaoTheme.of(context);
    final size = st.font.size;
    final text = theme.text(size: size, color: st.text, height: _rowLineHeight);
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final style = KakaoOptionListStyle(
      text: text,
      rowMinHeight: st.optionHeight,
      rowPadding: _rowPadding,
      rowRadius: st.optionRadius,
      gap: _rowGap,
      trailingGap: 0,
      leadSize: _checkSize * size,
      highlight: st.hoverBg,
      check: st.check,
      icon: st.muted,
      heading: theme.text(size: _headingSize, weight: _headingWeight, color: st.muted, height: st.font.lineHeight),
      headingPadding: _headingPadding,
      separator: st.line,
      separatorMargin: 0,
      padding: EdgeInsets.zero,
      duration: st.duration,
      curve: st.ease,
      checkedWeight: _selectedWeight,
      disabledColor: st.muted,
    );
    final shown = _shown();
    final create = _createShown;

    return ConstrainedBox(
      key: widget.panelKey,
      // max-height: min(panel-height, room); the room is the anchored panel's.
      constraints: BoxConstraints(maxHeight: st.panelHeight),
      child: Container(
        padding: EdgeInsets.all(st.panelPadding),
        decoration: BoxDecoration(
          color: st.panelBg,
          borderRadius: BorderRadius.circular(st.panelRadius),
          boxShadow: st.panelShadow,
        ),
        child: DefaultTextStyle(
          style: theme.text(size: size, color: st.text, height: st.font.lineHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (create)
                _CreateRow(
                  label: (widget.createLabel ?? KakaoCombobox.texts.create).split('{text}').join(_whole),
                  alone: shown.rows.isEmpty,
                  active: _createActive,
                  settings: st,
                  text: text,
                  lead: _checkSize * size,
                  duration: reduce ? Duration.zero : st.duration,
                  onHover: () {
                    if (!_createActive) _activate(-1, keyboard: false);
                  },
                  onTap: _pickCreate,
                ),
              Flexible(
                child: KakaoOptionList(
                  entries: shown.entries,
                  style: style,
                  controller: _list,
                  onActivate: _pickRow,
                  semanticsRole: SemanticsRole.list,
                  semanticsLabel: name,
                ),
              ),
              if (shown.rows.isEmpty && !create)
                Padding(
                  padding: _emptyPadding,
                  child: Text(
                    widget.emptyText ?? KakaoCombobox.texts.empty,
                    textAlign: TextAlign.center,
                    style: theme.text(size: size * _emptyFont, color: st.muted, height: st.font.lineHeight),
                  ),
                ),
              Semantics(liveRegion: true, label: _status, child: const SizedBox.shrink()),
            ],
          ),
        ),
      ),
    );
  }
}

class _Completion extends TextInputFormatter {
  const _Completion(this.complete);
  final TextEditingValue Function(TextEditingValue old, TextEditingValue next) complete;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      complete(oldValue, newValue);
}

/// `.row.create`: "Use “text”" with a plus in the check column, first in
/// the list (sticky on the web) with a line below it; [alone] (no
/// suggestions under it): no line, all corners round.
class _CreateRow extends StatelessWidget {
  const _CreateRow({
    required this.label,
    required this.alone,
    required this.active,
    required this.settings,
    required this.text,
    required this.lead,
    required this.duration,
    required this.onHover,
    required this.onTap,
  });

  final String label;
  final bool alone;
  final bool active;
  final KakaoComboboxSettings settings;
  final TextStyle text;
  final double lead;
  final Duration duration;
  final VoidCallback onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final st = settings;
    final r = Radius.circular(st.optionRadius);
    return Semantics(
      container: true,
      button: true,
      selected: active,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onHover: (_) => onHover(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            // margin-bottom: 1px, under the line.
            padding: EdgeInsets.only(bottom: alone ? 0 : 1),
            child: AnimatedContainer(
              duration: duration,
              curve: st.ease,
              constraints: BoxConstraints(minHeight: st.optionHeight),
              padding: _rowPadding,
              alignment: AlignmentDirectional.centerStart,
              decoration: BoxDecoration(
                color: active ? st.hoverBg : st.panelBg,
                borderRadius: alone ? BorderRadius.all(r) : BorderRadius.only(topLeft: r, topRight: r),
                // box-shadow: 0 1px 0 var(--_line).
                boxShadow: alone ? null : [BoxShadow(color: st.line, offset: const Offset(0, 1))],
              ),
              child: Row(
                children: [
                  CustomPaint(size: Size.square(lead), painter: _PlusPainter(st.muted)),
                  const SizedBox(width: _rowGap),
                  Expanded(child: Text(label, style: text)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// combobox.js PLUS: `M12 5v14M5 12h14` in a 24 box, stroke 2.6, round.
class _PlusPainter extends CustomPainter {
  const _PlusPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _plusStroke * k
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawLine(Offset(12 * k, 5 * k), Offset(12 * k, 19 * k), paint);
    canvas.drawLine(Offset(5 * k, 12 * k), Offset(19 * k, 12 * k), paint);
  }

  @override
  bool shouldRepaint(_PlusPainter old) => old.color != color;
}
