import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../internal/kakao_anchored_panel.dart';
import '../internal/kakao_chip.dart';
import '../internal/kakao_field.dart';
import '../internal/kakao_option_list.dart';
import '../settings/kakao_chip_settings.g.dart';
import '../settings/kakao_tag_input_settings.g.dart';
import '../theme/kakao_theme.dart';

/// `<kakao-tag-input size>`.
enum KakaoTagInputSize { sm, md, lg }

// tag-input.js values outside the settings block.
const _smSize = (
  height: 36.0,
  paddingX: 10.0,
  paddingY: 3.0,
  font: 14.0,
); // --kakao-tag-input-sm-height / -sm-padding-x / -sm-padding-y; .field 0.875rem
const _lgSize = (
  height: 52.0,
  paddingX: 14.0,
  paddingY: 7.0,
  font: 16.0,
); // --kakao-tag-input-lg-height / -lg-padding-x / -lg-padding-y; .field 1rem
const _labelSize = 13.12; // .label font-size: 0.82rem
const _messageSize = 12.48; // .hint, .error font-size: 0.78rem
const _flash = Duration(milliseconds: 900); // FLASH_MS
const _statusDelay = Duration(milliseconds: 50); // _announce: setTimeout(…, 50)
const _newScale = .85; // @keyframes kakao-tag-input-in: scale(0.85)
const _entrySlide = 4.0; // @keyframes kakao-tag-input-panel-in: translateY(-4px), 4px above
const _rowPadding = EdgeInsets.symmetric(vertical: 6.4, horizontal: 9.6); // .row padding: 0.4rem 0.6rem
const _rowLineHeight = 1.3; // .row line-height: 1.3
const _selectionAlpha = .25; // the text selection: the focus colour, light

/// tag-input.js `tidy`: inner white space as one space, trimmed.
String _tidy(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

/// One character class of [chars] (tag-input.js `escapeRe` in `[…]`).
RegExp _anyOf(String chars, [String extra = '']) {
  final escaped = chars.replaceAllMapped(RegExp(r'[.*+?^${}()|[\]\\-]'), (m) => '\\${m[0]}');
  return RegExp('[$escaped$extra]');
}

/// Reaches a [KakaoTagInput] from outside (the web element's API): calls
/// through it never report events.
class KakaoTagInputController {
  _KakaoTagInputState? _state;

  /// `values`: the tags.
  List<String> get values => _state?._values ?? const [];
  set values(List<String> v) => _state?._replace(v);

  /// `text`: what is typed in the field right now.
  String get text => _state?._text.text ?? '';

  /// `add(text)`: adds a tag as if typed; false when it was empty, a
  /// duplicate or over `maxTags`.
  bool add(String text) => _state?._apiAdd(text) ?? false;

  /// `remove(text)`: removes the first tag equal to [text] (case and accents
  /// ignored); true when one was removed.
  bool remove(String text) => _state?._apiRemove(text) ?? false;

  /// `clear()`: removes every tag.
  void clear() => _state?._replace(const []);
}

/// Flutter twin of `<kakao-tag-input>`: a field for a list of short free-text
/// values (tags, keywords, recipients).
///
/// The typed text becomes a tag on Enter or one of [delimiters] (a comma by
/// default); the tags sit in the field as chips (drawn from the chip's own
/// `--kakao-chip-*` settings), wrap to more lines, and the text field takes
/// the room left on the last line (at least `text-min-width`, else a line of
/// its own). Pasting "a, b, c" (or lines) adds three.
///
/// The field, as tag-input.js draws it from the `--kakao-tag-input-*`
/// settings: the text input's field ([label] above, a tap on it focuses the
/// text; [hint] below or [error] instead with the danger border; heights 36 /
/// 44 / 52 px by [size], growing by lines; the border fades to the focus
/// colour while the text has focus or the suggestions are open, focus adds
/// the 2 px outline). [placeholder] shows while there are no tags.
/// [disabled] dims everything and allows no editing (no remove buttons);
/// [readOnly] shows the tags without remove buttons and a read-only text.
///
/// Rules: tags are tidied (white space), empty ones dropped; [maxTags] refuses
/// more (announced); without [allowDuplicates] a tag already there (case and
/// accents ignored) is refused, its chip flashes in the danger tone for
/// 900 ms and the text stays in the field. [onTagAdd] / [onTagRemove] see a
/// tag before the user adds or removes it and return false to refuse it (the
/// cancelable `tag-add` / `tag-remove`); [onChanged] reports the tags after
/// each user action (once for a paste that adds several).
///
/// [suggestions]: while the user types, those that match (case and accents
/// ignored, anywhere in the text) and are not tags yet open below the field
/// on the combobox's panel; Down opens them, Down / Up move (wrapping), Enter
/// or a tap picks one, Escape closes. Any other text works too.
///
/// Keys in the text: Enter or a delimiter adds the text; Backspace in an
/// empty field (or with the caret at the start) and Left at the start select
/// the last tag; Tab adds the text and moves on; leaving the field adds it
/// too. On a selected tag (it turns ink, its ✕ gets the focus outline): Left /
/// Right go to the previous / next tag (Right from the last returns to the
/// text), Home / End to the first tag / the text, Backspace removes it and
/// selects the one before, Delete the one after, Enter or Space on the ✕
/// removes it, Escape or typing returns to the text. Tab does not stop on the
/// tags. A tap on a tag selects it, on its ✕ removes it.
///
/// [values] are the tags the field starts with; it keeps the user's changes
/// from then on and takes new [values] from its owner (a different list),
/// without reporting them.
class KakaoTagInput extends StatefulWidget {
  const KakaoTagInput({
    super.key,
    this.values = const [],
    this.onChanged,
    this.onTagAdd,
    this.onTagRemove,
    this.onTextChanged,
    this.label,
    this.semanticLabel,
    this.hint,
    this.error,
    this.placeholder,
    this.delimiters = ',',
    this.maxTags,
    this.allowDuplicates = false,
    this.suggestions = const [],
    this.size = KakaoTagInputSize.md,
    this.disabled = false,
    this.readOnly = false,
    this.controller,
    this.focusNode,
    this.panelKey,
  });

  /// `value` / `values`: the tags to start with.
  final List<String> values;

  /// `change`: the tags after the user added or removed some.
  final ValueChanged<List<String>>? onChanged;

  /// `tag-add`: before a tag the user entered is added; false refuses it (the
  /// text stays in the field).
  final bool Function(String value)? onTagAdd;

  /// `tag-remove`: before the user removes a tag; false keeps it.
  final bool Function(String value)? onTagRemove;

  /// The text field's own `input` while typing: the text right now.
  final ValueChanged<String>? onTextChanged;

  /// `label`: shown above the field.
  final String? label;

  /// `aria-label`: the accessible name when there is no [label].
  final String? semanticLabel;

  /// `hint`: below the field, hidden while there is an [error].
  final String? hint;

  /// `error`: below the field, danger border, invalid.
  final String? error;

  /// `placeholder`: shown while there are no tags.
  final String? placeholder;

  /// `delimiters`: characters that end a tag while typing, each on its own
  /// ("" for none; Enter always ends a tag). Pasted text is split on these
  /// and on line breaks and tabs.
  final String delimiters;

  /// `max-tags`: null or less than 1 for no limit.
  final int? maxTags;

  /// `allow-duplicates`.
  final bool allowDuplicates;

  /// `list-data` / `suggestions`.
  final List<String> suggestions;
  final KakaoTagInputSize size;

  /// `disabled`: dimmed, no editing, not focusable.
  final bool disabled;

  /// `readonly`: tags shown, not changed.
  final bool readOnly;

  /// `add()`, `remove()`, `clear()`, `values`, `text`.
  final KakaoTagInputController? controller;

  /// The text field's focus (`focus()`, `blur()`).
  final FocusNode? focusNode;

  /// Put on the open suggestions panel (tests, screenshots).
  final Key? panelKey;

  /// `KakaoTagInput.texts`: tag-input.js's built-in English texts.
  static ({
    String name,
    String Function(int max) limit,
    String Function(String tag) duplicate,
    String Function(String tag) added,
    String Function(int n) addedMany,
    String Function(String tag) removed,
  })
  texts = (
    name: 'Tags',
    limit: (max) => 'No more than $max tags.',
    duplicate: (tag) => '“$tag” is already added.',
    added: (tag) => 'Added $tag.',
    addedMany: (n) => 'Added $n tags.',
    removed: (tag) => 'Removed $tag.',
  );

  /// tag-input.js `_parse`: "a, b" or a JSON array ('["Smith, J.", "Doe"]')
  /// to a list of tags.
  static List<String> parse(String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) return [];
    if (text.startsWith('[')) {
      try {
        final list = jsonDecode(text);
        if (list is List) return [for (final s in list) _tidy('$s')].where((s) => s.isNotEmpty).toList();
      } on FormatException {
        // fall through to the comma list
      }
    }
    return text.split(',').map(_tidy).where((s) => s.isNotEmpty).toList();
  }

  /// tag-input.js `value`: comma-joined, or a JSON array when a tag holds a
  /// comma.
  static String join(List<String> values) => values.any((t) => t.contains(',')) ? jsonEncode(values) : values.join(',');

  @override
  State<KakaoTagInput> createState() => _KakaoTagInputState();
}

/// A tag and its chip's state.
class _Tag {
  _Tag(this.id, this.text, {this.isNew = false})
    : focus = FocusNode(debugLabel: 'KakaoTagInput tag', skipTraversal: true);

  final int id;
  final String text;
  final FocusNode focus;

  /// Added by the user just now: it grows in (`.is-new`).
  bool isNew;

  /// A refused duplicate: the danger tone for a moment.
  Timer? flash;
}

class _KakaoTagInputState extends State<KakaoTagInput> {
  final _panel = KakaoAnchoredPanelController();
  final _list = KakaoOptionListController();
  final _text = TextEditingController();
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode(debugLabel: 'KakaoTagInput'));

  /// The tap region group of the field and its panel.
  final _group = Object();

  final _tags = <_Tag>[];
  var _nextId = 0;
  List<String> _matches = const [];
  bool _open = false;
  bool _focused = false;

  /// The selected tag came by keys (its ✕ shows the focus outline).
  bool _chipByKey = false;

  /// The last edit inserted several characters with a delimiter (a paste):
  /// every part becomes a tag, the last one too.
  bool _pasted = false;

  /// The list was just closed by an Escape the text is about to see.
  bool _escapeClosed = false;
  String _status = '';
  Timer? _statusTimer;

  List<String> get _values => [for (final t in _tags) t.text];
  bool get _editable => !widget.disabled && !widget.readOnly;
  int get _max => (widget.maxTags ?? 0) > 0 ? widget.maxTags! : 1 << 30;
  bool get _reduceMotion => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  List<String> get _suggestions => [
    for (final s in widget.suggestions)
      if (_tidy(s).isNotEmpty) _tidy(s),
  ];

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
    _setTags(widget.values);
    _panel.addListener(_openChanged);
    _focus.addListener(_focusChanged);
  }

  @override
  void didUpdateWidget(KakaoTagInput old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      if (old.controller?._state == this) old.controller!._state = null;
      widget.controller?._state = this;
    }
    final focusBefore = old.focusNode ?? _ownFocus;
    if (focusBefore != _focus) {
      focusBefore?.removeListener(_focusChanged);
      _focus.addListener(_focusChanged);
    }
    if (!listEquals(old.values, widget.values)) _setTags(widget.values);
    if ((widget.disabled && !old.disabled) || (widget.readOnly && !old.readOnly)) _panel.close();
    if (_open && !identical(old.suggestions, widget.suggestions)) _filter();
  }

  @override
  void dispose() {
    if (widget.controller?._state == this) widget.controller!._state = null;
    _statusTimer?.cancel();
    _panel.removeListener(_openChanged);
    (widget.focusNode ?? _ownFocus)?.removeListener(_focusChanged);
    for (final t in _tags) {
      t.flash?.cancel();
      t.focus.dispose();
    }
    _panel.dispose();
    _list.dispose();
    _text.dispose();
    _ownFocus?.dispose();
    super.dispose();
  }

  /* ---------------------------- Tags ---------------------------- */

  int _indexOf(String text) {
    final k = kakaoFold(text);
    return _tags.indexWhere((t) => kakaoFold(t.text) == k);
  }

  /// tag-input.js `_refusal`: 'limit', 'duplicate', or null.
  String? _refusal(String text) {
    if (_tags.length >= _max) return 'limit';
    if (!widget.allowDuplicates && _indexOf(text) > -1) return 'duplicate';
    return null;
  }

  void _drop(_Tag t) {
    t.flash?.cancel();
    // Its chip leaves the tree in the next frame; the node goes after it.
    WidgetsBinding.instance.addPostFrameCallback((_) => t.focus.dispose());
  }

  /// tag-input.js `_setTags`: every tag replaced, no events.
  void _setTags(List<String> list) {
    _tags.forEach(_drop);
    _tags.clear();
    for (final raw in list) {
      final tag = _tidy(raw);
      if (tag.isEmpty || _tags.length >= _max) continue;
      if (!widget.allowDuplicates && _indexOf(tag) > -1) continue;
      _tags.add(_Tag(_nextId++, tag));
    }
  }

  void _replace(List<String> list) {
    if (!mounted) return;
    setState(() => _setTags(list));
  }

  bool _apiAdd(String text) {
    final t = _tidy(text);
    if (!mounted || t.isEmpty || _refusal(t) != null) return false;
    setState(() => _tags.add(_Tag(_nextId++, t)));
    return true;
  }

  bool _apiRemove(String text) {
    final i = _indexOf(_tidy(text));
    if (!mounted || i < 0) return false;
    setState(() => _drop(_tags.removeAt(i)));
    return true;
  }

  void _announce(String text) {
    _statusTimer?.cancel();
    setState(() => _status = '');
    _statusTimer = Timer(_statusDelay, () {
      if (mounted) setState(() => _status = text);
    });
  }

  void _flashTag(int i) {
    if (i < 0) return;
    final t = _tags[i];
    t.flash?.cancel();
    setState(() {
      t.flash = Timer(_flash, () {
        if (mounted) setState(() => t.flash = null);
      });
    });
  }

  /// tag-input.js `_userAdd`: tags the user entered, [KakaoTagInput.onTagAdd]
  /// for each, one change at the end. Returns the texts refused or cancelled.
  List<String> _userAdd(Iterable<String> texts) {
    final kept = <String>[];
    var added = 0;
    for (final text in texts.map(_tidy).where((s) => s.isNotEmpty)) {
      final why = _refusal(text);
      if (why == 'limit') {
        _announce(KakaoTagInput.texts.limit(_max));
        kept.add(text);
        continue;
      }
      if (why == 'duplicate') {
        _flashTag(_indexOf(text));
        _announce(KakaoTagInput.texts.duplicate(text));
        kept.add(text);
        continue;
      }
      if (widget.onTagAdd?.call(text) == false) {
        kept.add(text);
        continue;
      }
      setState(() => _tags.add(_Tag(_nextId++, text, isNew: !_reduceMotion)));
      added++;
      _announce(added == 1 ? KakaoTagInput.texts.added(text) : KakaoTagInput.texts.addedMany(added));
    }
    if (added > 0) widget.onChanged?.call(_values);
    return kept;
  }

  /// tag-input.js `_userRemove`: removes tag [i] for the user and moves focus
  /// on: to the tag before ([previous]: Backspace) or after (Delete, the ✕).
  void _userRemove(int i, {required bool previous, bool click = false, bool keyboard = true}) {
    if (!_editable || i < 0 || i >= _tags.length) return;
    final tag = _tags[i];
    if (widget.onTagRemove?.call(tag.text) == false) return;
    final hadFocus = tag.focus.hasFocus;
    setState(() => _drop(_tags.removeAt(i)));
    _announce(KakaoTagInput.texts.removed(tag.text));
    widget.onChanged?.call(_values);
    if (!hadFocus && !click) return;
    var next = previous ? i - 1 : i;
    if (previous && next < 0) next = 0;
    if (next >= 0 && next < _tags.length) {
      _focusChip(next, keyboard: keyboard);
    } else {
      _toInput();
    }
  }

  void _focusChip(int i, {bool keyboard = true}) {
    if (i < 0 || i >= _tags.length) return;
    setState(() => _chipByKey = keyboard);
    _tags[i].focus.requestFocus();
  }

  void _toInput() => _focus.requestFocus();

  /// tag-input.js `_commitText`: the typed text as a tag; true when added.
  bool _commitText() {
    final text = _text.text;
    if (_tidy(text).isEmpty) {
      _setText('');
      return false;
    }
    final kept = _userAdd([text]);
    _setText(kept.isNotEmpty ? text : '');
    if (_open) _filter();
    return kept.isEmpty;
  }

  void _setText(String text) {
    if (_text.text == text) return;
    _text.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  /* ---------------------------- Suggestions ---------------------------- */

  bool get _hasSuggestions => _suggestions.isNotEmpty;

  /// tag-input.js `_filter`: the matching suggestions that are not tags yet;
  /// closes when none.
  void _filter() {
    final q = kakaoFold(_tidy(_text.text));
    final dupes = !widget.allowDuplicates;
    final matches = [
      for (final s in _suggestions)
        if ((q.isEmpty || kakaoFold(s).contains(q)) && !(dupes && _indexOf(s) > -1)) s,
    ];
    setState(() => _matches = matches);
    _list.highlight(null);
    if (matches.isEmpty) _panel.close();
  }

  void _openList() {
    if (_panel.isOpen || !_editable || !_hasSuggestions) return;
    _filter();
    if (_matches.isEmpty) return;
    _panel.open();
  }

  void _openChanged() {
    final open = _panel.isOpen;
    if (!mounted || open == _open) return;
    setState(() => _open = open);
    _list.highlight(null);
  }

  void _pick(int i) {
    if (i < 0 || i >= _matches.length) return;
    final kept = _userAdd([_matches[i]]);
    if (kept.isEmpty) _setText('');
    _panel.close();
  }

  /* ---------------------------- Interaction ---------------------------- */

  void _focusChanged() {
    if (!mounted) return;
    final focused = _focus.hasFocus;
    if (focused != _focused) setState(() => _focused = focused);
  }

  /// Focus left the text and the tags (tag-input.js `focusout`): close, and
  /// add the typed text.
  void _withinChanged(bool within) {
    if (within || !mounted) return;
    _panel.close();
    if (_editable && _tidy(_text.text).isNotEmpty) _commitText();
  }

  /// Notes an edit that inserts several characters holding a delimiter, as
  /// a paste does (`insertFromPaste`).
  TextEditingValue _watchPaste(TextEditingValue old, TextEditingValue next) {
    final s = old.selection;
    final base = s.isValid ? old.text.replaceRange(s.start, s.end, '') : old.text;
    final inserted = next.text.length - base.length;
    if (inserted > 1 && widget.delimiters.isNotEmpty) {
      final at = s.isValid ? s.start : old.text.length;
      final end = (at + inserted).clamp(at, next.text.length);
      _pasted = _anyOf(widget.delimiters).hasMatch(next.text.substring(at.clamp(0, next.text.length), end));
    } else {
      _pasted = false;
    }
    return next;
  }

  /// tag-input.js `_onInput`.
  void _onInput(String _) {
    if (!_editable) return;
    final pasted = _pasted;
    _pasted = false;
    final delims = widget.delimiters;
    if (delims.isNotEmpty) {
      final value = _text.text;
      final re = _anyOf(delims);
      if (re.hasMatch(value)) {
        final parts = value.split(re);
        final rest = pasted ? '' : parts.removeLast();
        final kept = _userAdd(parts);
        _setText(kept.isNotEmpty ? kept.first : rest);
      }
    }
    if (_hasSuggestions) {
      if (_tidy(_text.text).isNotEmpty) {
        if (_panel.isOpen) {
          _filter();
        } else {
          _openList();
        }
      } else {
        _panel.close();
      }
    }
    widget.onTextChanged?.call(_text.text);
  }

  /// tag-input.js `_onPaste`: a paste holding delimiters, line breaks or tabs
  /// adds every part; other text is pasted as it is.
  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (!mounted || text.isEmpty || !_editable) return;
    final v = _text.value;
    final s = v.selection.isValid ? v.selection : TextSelection.collapsed(offset: v.text.length);
    final before = v.text.substring(0, s.start);
    final after = v.text.substring(s.end);
    final re = _anyOf(widget.delimiters, r'\n\r\t');
    if (!re.hasMatch(text)) {
      final next = '$before$text$after';
      _text.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: before.length + text.length),
      );
      _onInput(next);
      return;
    }
    final kept = _userAdd('$before$text$after'.split(re));
    _setText(kept.join(', '));
    _panel.close();
  }

  bool get _caretAtStart {
    final s = _text.selection;
    return !s.isValid || (s.start == 0 && s.end == 0);
  }

  /// tag-input.js `_onInputKey`.
  KeyEventResult _onInputKey(FocusNode node, KeyEvent e) {
    if (widget.disabled || (e is! KeyDownEvent && e is! KeyRepeatEvent)) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final keys = HardwareKeyboard.instance;
    if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) {
      final composing = _text.value.composing;
      if (!_editable || (composing.isValid && !composing.isCollapsed)) return KeyEventResult.ignored;
      final row = _panel.isOpen ? _list.highlighted : null;
      if (row != null) {
        if (e is KeyDownEvent) _pick(row);
      } else if (_tidy(_text.text).isNotEmpty) {
        if (e is KeyDownEvent) {
          _commitText();
          _panel.close();
        }
      } else {
        return KeyEventResult.ignored;
      }
    } else if (k == LogicalKeyboardKey.backspace) {
      if (!_caretAtStart || _tags.isEmpty || e is! KeyDownEvent) return KeyEventResult.ignored;
      _panel.close();
      _focusChip(_tags.length - 1);
    } else if (k == LogicalKeyboardKey.arrowLeft) {
      if (!_caretAtStart || _tags.isEmpty) return KeyEventResult.ignored;
      _panel.close();
      _focusChip(_tags.length - 1);
    } else if (k == LogicalKeyboardKey.arrowDown) {
      if (!_hasSuggestions || !_editable) return KeyEventResult.ignored;
      if (!_panel.isOpen) {
        _openList();
      } else {
        _list.move(1);
      }
    } else if (k == LogicalKeyboardKey.arrowUp) {
      if (!_panel.isOpen) return KeyEventResult.ignored;
      _list.move(-1);
    } else if (k == LogicalKeyboardKey.escape) {
      // An open list closes on Escape itself (the anchored panel sees keys
      // first, see onDismiss); that Escape stops here. Else it goes on.
      if (!_escapeClosed && !_panel.isOpen) return KeyEventResult.ignored;
      if (e is KeyDownEvent) _escapeClosed = false;
    } else if (k == LogicalKeyboardKey.tab) {
      // Add before focus moves on; the focus loss then finds nothing to do.
      _panel.close();
      if (_editable && _tidy(_text.text).isNotEmpty) _commitText();
      return KeyEventResult.ignored;
    } else if (k == LogicalKeyboardKey.keyV && (keys.isControlPressed || keys.isMetaPressed) && !keys.isAltPressed) {
      // The single-line field would drop the line breaks before a formatter
      // sees them: the paste is read here.
      if (!_editable || e is! KeyDownEvent) return KeyEventResult.ignored;
      _paste();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  /// tag-input.js `_onChipKey`, on the tag at [i].
  KeyEventResult _onChipKey(int i, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final last = _tags.length - 1;
    if (k == LogicalKeyboardKey.arrowLeft) {
      if (i > 0) _focusChip(i - 1);
    } else if (k == LogicalKeyboardKey.arrowRight) {
      if (i < last) {
        _focusChip(i + 1);
      } else {
        _toInput();
      }
    } else if (k == LogicalKeyboardKey.home) {
      _focusChip(0);
    } else if (k == LogicalKeyboardKey.end || k == LogicalKeyboardKey.escape) {
      _toInput();
    } else if (k == LogicalKeyboardKey.backspace) {
      if (e is KeyDownEvent) _userRemove(i, previous: true);
    } else if (k == LogicalKeyboardKey.delete) {
      _userRemove(i, previous: false);
    } else if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter || k == LogicalKeyboardKey.space) {
      // Enter or Space on the ✕ (a button): as a click on it.
      if (!_editable) return KeyEventResult.ignored;
      if (e is KeyDownEvent) _userRemove(i, previous: false, click: true);
    } else {
      // Typing a character goes back to the text field and types there.
      final keys = HardwareKeyboard.instance;
      final c = e.character;
      if (c == null ||
          c.length != 1 ||
          c == ' ' ||
          c.codeUnitAt(0) < 0x20 ||
          keys.isControlPressed ||
          keys.isMetaPressed ||
          keys.isAltPressed ||
          !_editable) {
        return KeyEventResult.ignored;
      }
      _toInput();
      final v = _text.value;
      final s = v.selection.isValid ? v.selection : TextSelection.collapsed(offset: v.text.length);
      final next = v.text.replaceRange(s.start, s.end, c);
      _text.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: s.start + 1),
      );
      _onInput(next);
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    final st = KakaoTagInputSettings.of(theme.colors);
    final chip = KakaoChipSettings.of(theme.colors);
    final (height, paddingX, paddingY, fontSize) = switch (widget.size) {
      KakaoTagInputSize.sm => (_smSize.height, _smSize.paddingX, _smSize.paddingY, _smSize.font),
      KakaoTagInputSize.md => (st.height, st.paddingX, st.paddingY, st.font.size),
      KakaoTagInputSize.lg => (_lgSize.height, _lgSize.paddingX, _lgSize.paddingY, _lgSize.font),
    };
    // --_line: one line of the field; --_inset: the start padding that
    // centres a chip in it.
    final line = height - 2 - 2 * paddingY;
    final inset = paddingY > (height - 2 - chip.height) / 2 ? paddingY : (height - 2 - chip.height) / 2;
    final reduce = _reduceMotion;
    final error = widget.error?.isNotEmpty ?? false ? widget.error : null;
    final hint = widget.hint?.isNotEmpty ?? false ? widget.hint : null;
    final disabled = widget.disabled;
    final name = (widget.label?.isNotEmpty ?? false)
        ? widget.label!
        : (widget.semanticLabel?.isNotEmpty ?? false)
        ? widget.semanticLabel!
        : (widget.placeholder?.isNotEmpty ?? false)
        ? widget.placeholder!
        : KakaoTagInput.texts.name;
    final hasTags = _tags.isNotEmpty;

    Widget input = KakaoFieldText(
      controller: _text,
      focusNode: _focus,
      style: theme.text(size: fontSize, color: st.text, height: st.font.lineHeight),
      placeholder: hasTags ? null : widget.placeholder,
      placeholderColor: st.muted,
      cursorColor: st.text,
      selectionColor: st.focus.withValues(alpha: _selectionAlpha),
      enabled: !disabled,
      readOnly: widget.readOnly,
      inputFormatters: [_PasteWatch(_watchPaste)],
      onChanged: _onInput,
      groupId: _group,
      selectAllOnFocus: false,
    );
    input = Semantics(
      label: name,
      hint: error ?? hint,
      expanded: _hasSuggestions ? _open : null,
      enabled: !disabled,
      readOnly: widget.readOnly,
      validationResult: error != null ? SemanticsValidationResult.invalid : SemanticsValidationResult.none,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        includeSemantics: false,
        onKeyEvent: _onInputKey,
        child: Padding(
          // Without tags the text starts where the text input's does.
          padding: EdgeInsetsDirectional.only(start: hasTags ? 0 : (paddingX - inset).clamp(0, paddingX)),
          child: input,
        ),
      ),
    );

    final chips = [for (var i = 0; i < _tags.length; i++) _chip(i, st, chip, reduce)];

    final flow = _TagFlow(
      gap: st.gap,
      rowGap: st.rowGap,
      textMinWidth: st.textMinWidth,
      line: line,
      children: [...chips, input],
    );

    final box = KakaoFieldBox(
      height: height,
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
      child: Stack(
        children: [
          // A tap on the empty part of the field goes to the text.
          Positioned.fill(
            child: GestureDetector(behavior: HitTestBehavior.opaque, onTapDown: disabled ? null : (_) => _toInput()),
          ),
          Padding(padding: EdgeInsetsDirectional.fromSTEB(inset, paddingY, paddingX, paddingY), child: flow),
        ],
      ),
    );

    final field = KakaoAnchoredPanel(
      controller: _panel,
      enabled: _editable,
      // As combobox.js _place: below, panel-offset away, from the field's
      // start (its end without room, else pushed 8 px inside); above when
      // there is no room below and more above, chosen on open; as wide as
      // the field or panel-min-width; capped by max(120, room).
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
      returnFocus: false,
      tapRegionGroup: _group,
      onDismiss: (why) {
        if (why == KakaoPanelDismiss.escape) _escapeClosed = true;
      },
      panelBuilder: (context, side) => _suggestionPanel(context, st, name),
      child: TapRegion(
        groupId: _group,
        child: MouseRegion(
          cursor: disabled ? SystemMouseCursors.forbidden : SystemMouseCursors.text,
          child: Focus(
            canRequestFocus: false,
            skipTraversal: true,
            includeSemantics: false,
            onFocusChange: _withinChanged,
            child: ExcludeFocus(excluding: disabled, child: box),
          ),
        ),
      ),
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
      onLabelTap: disabled ? null : _toInput,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          field,
          // The polite status: added, removed and refused tags.
          Semantics(liveRegion: true, label: _status, child: const SizedBox.shrink()),
        ],
      ),
    );
  }

  /// A tag's chip: selected (focused) it turns ink (`selected-bg`,
  /// `selected-text`); a refused duplicate flashes in the danger tone; a new
  /// one grows in from 85 % while it fades in.
  Widget _chip(int i, KakaoTagInputSettings st, KakaoChipSettings chip, bool reduce) {
    final t = _tags[i];
    final selected = t.focus.hasFocus;
    Widget w = KakaoChipView(
      label: t.text,
      settings: chip,
      tone: t.flash != null ? KakaoChipTone.danger : KakaoChipTone.neutral,
      fill: selected ? st.selectedBg : null,
      text: selected ? st.selectedText : null,
      onRemove: _editable ? () => _userRemove(_tags.indexOf(t), previous: false, click: true, keyboard: false) : null,
      removeRing: selected && _chipByKey && _editable,
    );
    w = Focus(
      focusNode: t.focus,
      canRequestFocus: !widget.disabled,
      onFocusChange: (_) => setState(() {}),
      onKeyEvent: (_, e) => _onChipKey(_tags.indexOf(t), e),
      child: Semantics(
        container: true,
        label: t.text,
        selected: selected,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          // A tap on the tag selects it (the chip takes focus).
          onTapDown: widget.disabled ? null : (_) => _focusChip(_tags.indexOf(t), keyboard: false),
          child: w,
        ),
      ),
    );
    // Always wrapped (an old tag starts at 1), so the chip keeps its state.
    w = TweenAnimationBuilder<double>(
      tween: Tween(begin: t.isNew && !reduce ? 0 : 1, end: 1),
      duration: reduce ? Duration.zero : st.duration,
      curve: st.ease,
      onEnd: () => t.isNew = false,
      builder: (context, v, child) => v >= 1
          ? child!
          : Opacity(
              opacity: v.clamp(0, 1),
              child: Transform.scale(scale: _newScale + (1 - _newScale) * v, child: child),
            ),
      child: w,
    );
    return KeyedSubtree(key: ValueKey(t.id), child: w);
  }

  /// The open suggestions (`.panel`): the combobox's panel and rows.
  Widget _suggestionPanel(BuildContext context, KakaoTagInputSettings st, String name) {
    final theme = KakaoTheme.of(context);
    final size = st.font.size;
    final text = theme.text(size: size, color: st.text, height: _rowLineHeight);
    final style = KakaoOptionListStyle(
      text: text,
      rowMinHeight: st.optionHeight,
      rowPadding: _rowPadding,
      rowRadius: st.optionRadius,
      gap: 0,
      trailingGap: 0,
      leadSize: 0,
      highlight: st.hoverBg,
      check: st.text,
      icon: st.muted,
      heading: text,
      headingPadding: EdgeInsets.zero,
      separator: st.border,
      separatorMargin: 0,
      padding: EdgeInsets.zero,
      duration: st.duration,
      curve: st.ease,
      disabledColor: st.muted,
    );
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
          child: KakaoOptionList(
            entries: [for (final s in _matches) KakaoOption(label: s)],
            style: style,
            controller: _list,
            onActivate: (i) {
              _pick(i);
              _toInput();
            },
            semanticsRole: SemanticsRole.list,
            semanticsLabel: name,
          ),
        ),
      ),
    );
  }
}

class _PasteWatch extends TextInputFormatter {
  const _PasteWatch(this.watch);
  final TextEditingValue Function(TextEditingValue old, TextEditingValue next) watch;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) => watch(oldValue, newValue);
}

/// The field's content (tag-input.js `.field`: `display: flex; flex-wrap:
/// wrap; align-items: center`, `column-gap` [gap], `row-gap` [rowGap]): the
/// chips in order, wrapping, none wider than the field, and last the text
/// field, [line] high, taking the room left on the last line when that is at
/// least [textMinWidth] (`flex: 1 1 text-min-width; min-width: …`), else a
/// line of its own. Each line is as high as its highest child; children are
/// centred in it.
class _TagFlow extends MultiChildRenderObjectWidget {
  const _TagFlow({
    required this.gap,
    required this.rowGap,
    required this.textMinWidth,
    required this.line,
    required super.children,
  });

  final double gap;
  final double rowGap;
  final double textMinWidth;
  final double line;

  @override
  _RenderTagFlow createRenderObject(BuildContext context) =>
      _RenderTagFlow(gap, rowGap, textMinWidth, line, Directionality.of(context));

  @override
  void updateRenderObject(BuildContext context, _RenderTagFlow renderObject) {
    renderObject
      ..gap = gap
      ..rowGap = rowGap
      ..textMinWidth = textMinWidth
      ..line = line
      ..textDirection = Directionality.of(context);
  }
}

class _FlowParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderTagFlow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _FlowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _FlowParentData> {
  _RenderTagFlow(this._gap, this._rowGap, this._textMinWidth, this._line, this._textDirection);

  double _gap;
  set gap(double v) {
    if (v == _gap) return;
    _gap = v;
    markNeedsLayout();
  }

  double _rowGap;
  set rowGap(double v) {
    if (v == _rowGap) return;
    _rowGap = v;
    markNeedsLayout();
  }

  double _textMinWidth;
  set textMinWidth(double v) {
    if (v == _textMinWidth) return;
    _textMinWidth = v;
    markNeedsLayout();
  }

  double _line;
  set line(double v) {
    if (v == _line) return;
    _line = v;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection v) {
    if (v == _textDirection) return;
    _textDirection = v;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _FlowParentData) child.parentData = _FlowParentData();
  }

  /// Lays the children out in [width] (sizing them with [sizeOf]); returns
  /// the height and, per child, its offset.
  (double, List<Offset>) _arrange(double width, Size Function(RenderBox child, BoxConstraints c) sizeOf) {
    final kids = <RenderBox>[];
    var c = firstChild;
    while (c != null) {
      kids.add(c);
      c = childAfter(c);
    }
    final sizes = <Size>[];
    final xs = <double>[];
    final lineOf = <int>[];
    final lineHeights = <double>[];
    var x = 0.0;
    var lineHeight = 0.0;
    var inLine = 0;
    void newLine() {
      lineHeights.add(lineHeight);
      x = 0;
      lineHeight = 0;
      inLine = 0;
    }

    for (var i = 0; i < kids.length; i++) {
      final text = i == kids.length - 1;
      final Size size;
      if (text) {
        final room = width - x - (inLine > 0 ? _gap : 0);
        if (inLine > 0 && room < _textMinWidth) newLine();
        final w = inLine > 0 ? room : width;
        size = sizeOf(kids[i], BoxConstraints.tightFor(width: w < 0 ? 0 : w, height: _line));
      } else {
        size = sizeOf(kids[i], BoxConstraints(maxWidth: width));
        if (inLine > 0 && x + _gap + size.width > width) newLine();
      }
      if (inLine > 0) x += _gap;
      xs.add(x);
      sizes.add(size);
      lineOf.add(lineHeights.length);
      x += size.width;
      if (size.height > lineHeight) lineHeight = size.height;
      inLine++;
    }
    lineHeights.add(lineHeight);
    final tops = <double>[];
    var y = 0.0;
    for (final h in lineHeights) {
      tops.add(y);
      y += h + _rowGap;
    }
    final height = y - _rowGap;
    final rtl = _textDirection == TextDirection.rtl;
    final offsets = [
      for (var i = 0; i < kids.length; i++)
        Offset(
          rtl ? width - xs[i] - sizes[i].width : xs[i],
          tops[lineOf[i]] + (lineHeights[lineOf[i]] - sizes[i].height) / 2,
        ),
    ];
    return (height < 0 ? 0 : height, offsets);
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final (height, offsets) = _arrange(width, (child, c) {
      child.layout(c, parentUsesSize: true);
      return child.size;
    });
    var c = firstChild;
    var i = 0;
    while (c != null) {
      (c.parentData! as _FlowParentData).offset = offsets[i++];
      c = childAfter(c);
    }
    size = constraints.constrain(Size(width, height));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final (height, _) = _arrange(width, (child, c) => child.getDryLayout(c));
    return constraints.constrain(Size(width, height));
  }

  @override
  double computeMinIntrinsicWidth(double height) => _textMinWidth;

  @override
  double computeMaxIntrinsicWidth(double height) {
    var w = 0.0;
    var c = firstChild;
    while (c != null) {
      final next = childAfter(c);
      w += next == null ? _textMinWidth : c.getMaxIntrinsicWidth(double.infinity) + _gap;
      c = next;
    }
    return w;
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      width.isFinite ? _arrange(width, (child, c) => child.getDryLayout(c)).$1 : _line;

  @override
  double computeMaxIntrinsicHeight(double width) => computeMinIntrinsicHeight(width);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);
}
