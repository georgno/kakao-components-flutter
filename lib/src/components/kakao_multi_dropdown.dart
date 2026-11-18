import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../internal/kakao_anchored_panel.dart';
import '../internal/kakao_option_list.dart';
import '../settings/kakao_multi_dropdown_settings.g.dart';
import '../theme/kakao_theme.dart';

/// An option of a [KakaoMultiDropdownSegment] (`{ value, label?, hint?,
/// disabled? }`, or a plain string: the value).
@immutable
class KakaoMultiDropdownOption {
  const KakaoMultiDropdownOption(this.value, {String? label, this.hint = '', this.disabled = false})
    : label = label ?? value;

  /// The part of the joined value.
  final String value;

  /// Shown in the box and the list; default: [value].
  final String label;

  /// Muted, at the end of the row in the list (a month's number).
  final String hint;

  /// Muted and struck through, cannot be picked, skipped by the keys.
  final bool disabled;
}

/// A segment's "Unknown" choice (`unknown: { value, label, display }`).
@immutable
class KakaoMultiDropdownUnknown {
  const KakaoMultiDropdownUnknown({this.value, this.label, this.display});

  /// The stored code; default: the segment's [KakaoMultiDropdownSegment.unknownValue], else "?".
  final String? value;

  /// In the list and for screen readers; default [KakaoMultiDropdown.texts]`.unknown`.
  final String? label;

  /// What the closed box shows; default "–".
  final String? display;
}

/// A segment (`list-data` entry: `{ name, label?, placeholder?,
/// shortPlaceholder?, options, unknown?, separator? }`).
@immutable
class KakaoMultiDropdownSegment {
  const KakaoMultiDropdownSegment({
    required this.name,
    this.label,
    this.placeholder,
    this.shortPlaceholder,
    required this.options,
    this.allowUnknown,
    this.unknown,
    this.unknownValue,
    this.separator,
  });

  /// The key in [KakaoMultiDropdownChange.parts].
  final String name;

  /// Its name for screen readers (and the short placeholder); default [name].
  final String? label;

  /// The text of the empty box; default the dropdown's placeholder.
  final String? placeholder;

  /// Shown instead when the group has no room for the placeholders; default
  /// [placeholder] when set, else [label].
  final String? shortPlaceholder;
  final List<KakaoMultiDropdownOption> options;

  /// `unknown: true` / `false`: offer "Unknown" here whatever
  /// [KakaoMultiDropdown.allowUnknown] says; null follows it.
  final bool? allowUnknown;

  /// `unknown: { … }`: the texts of this segment's "Unknown" (and offers it,
  /// unless [allowUnknown] is false).
  final KakaoMultiDropdownUnknown? unknown;

  /// The stored code of "Unknown" (`unknownValue`; the date preset uses "00" and "0000").
  final String? unknownValue;

  /// The text after this segment in the joined value; default the dropdown's.
  final String? separator;
}

/// `dropdown-change`: a segment changed (also when a day was clamped).
@immutable
class KakaoMultiDropdownChange {
  const KakaoMultiDropdownChange._(this.value, this.parts, this.unknown);

  /// The joined value, "" while a part is missing.
  final String value;

  /// Every segment's value, null where it is not set.
  final Map<String, String?> parts;

  /// The segments set to "Unknown".
  final List<String> unknown;

  /// Every segment has a value.
  bool get complete => value.isNotEmpty;
}

/// Reads and changes a [KakaoMultiDropdown] from outside (multi-dropdown.js's
/// public API). Calls before the dropdown is built do nothing.
class KakaoMultiDropdownController {
  _KakaoMultiDropdownState? _state;

  /// `value`: the joined value, "" while incomplete. Setting it fires no
  /// change (as setting the attribute).
  String get value => _state?._joined() ?? '';
  set value(String v) => _state?._setValue(v);

  /// `getParts()`.
  Map<String, String?> get parts => _state?._parts() ?? const {};

  /// `setPart(name, value)`: like a pick (reports the change).
  void setPart(String name, String? value) => _state?._setPart(name, value);

  /// `clear()`: every segment unset (reports the change).
  void clear() => _state?._clear();

  /// `focus()`: the first segment.
  void focus() => _state?._focusFirst();

  /// Opens a segment's list.
  void open(String segment) => _state?._openSeg(segment);
  void close() => _state?._close();

  /// The open segment's name, or null.
  String? get openSegment => _state?._open;
}

// multi-dropdown.js values outside the settings block.
const _labelWeight = 600.0; // .label font-weight: 600
const _bgFade = Duration(milliseconds: 120); // .trigger transition: background-color 120ms ease
const _borderFade = Duration(milliseconds: 150); // .trigger transition: border-color 150ms ease
const _chevronTurn = Duration(milliseconds: 180); // .trigger svg transition: transform 180ms ease
const _chevronStroke = 2.0; // .trigger svg stroke-width: 2
const _popupMinWidth = 128.0; // .popup min-width: max(100%, 8rem)
const _popIn = Duration(milliseconds: 140); // .popup animation: kakao-md-pop 140ms ease-out
const _popSlide = 4.0; // @keyframes kakao-md-pop: translateY(-4px)
const _popScale = .98; // @keyframes kakao-md-pop: scale(0.98)
const _optionGap = 16.0; // .option gap: 1rem
const _optionFade = Duration(milliseconds: 120); // .option transition: background-color 120ms ease
const _selectedWeight = 600.0; // .option[aria-selected="true"] font-weight: 600
const _hintSize = .85; // .option .hint font-size: 0.85em
const _unknownGap = 2.4; // .option.is-unknown margin-bottom: 0.15rem
const _typeAheadReset = Duration(milliseconds: 900); // TYPEAHEAD_MS
const _pageStep = 8; // PageUp / PageDown: _moveActive(list, ±8)
const _unknownDisplay = '–'; // unknown.display default
const _unknownCode = '?'; // unknown value default for custom segments

/// Flutter twin of `<kakao-multi-dropdown>`: several dropdowns joined into
/// one input group that holds a single value, such as a date "dd.mm.yyyy"
/// (Day | Month | Year, [KakaoMultiDropdown.date]) or a product variant
/// "Size / Colour" ([segments]). Segments can offer an "Unknown" choice, so a
/// partly known date such as 00.00.1990 ("sometime in 1990") is a value.
///
/// It is not a multiple select: each box picks one value from its own list
/// (no checkboxes, search or "Select all").
///
/// The group, as multi-dropdown.js draws it from the
/// `--kakao-multi-dropdown-*` settings: the [label] above (weight 600; a tap
/// on it focuses the first box), then one box per segment, edge to edge with
/// shared 1 px borders and only the group's outer corners rounded. Each box
/// shows its value (a month by name, "–" for Unknown, the placeholder while
/// empty, both muted) and a chevron that turns over while its list is open.
/// Each box is as wide as its widest label (while it is empty, its
/// placeholder counts too), so it keeps its size when the value changes;
/// when the group has no room, every empty box shows its short placeholder
/// (DD / MM / YYYY), and boxes still too wide shrink and end in "…". A box
/// under the pointer takes `hover-bg`; the open box an accent border; the
/// keyboard-focused one a focus border and the 2 px outline, 2 px away,
/// drawn over its neighbours. [disabled] dims the whole group to
/// `disabled-opacity`.
///
/// A list: below its box, `popup-offset` away, at least as wide as the box
/// and 8rem, at most `popup-height` tall (it scrolls), opened with the
/// current value centred and highlighted. "Unknown" comes first, in italics
/// with a line under it; the selected option is in the accent colour and
/// weight 600; disabled ones (impossible days) are muted and struck
/// through. It fades and grows in over 140 ms and closes at once.
///
/// Keys on a closed box: Up / Down step the value, Enter, Space and Alt+Down
/// open the list, Left / Right go to the previous / next box, typing picks
/// the match (a complete entry moves on to the next box: "15" on the day),
/// Delete / Backspace clear it. In an open list: Up / Down / Home / End /
/// Page Up / Page Down move, Enter or Space pick, typing jumps, Escape or
/// Tab close. A pointer down outside closes it.
///
/// [value] is the joined value the group starts with; it keeps the user's
/// picks from then on and takes a new [value] from its owner without
/// reporting it.
class KakaoMultiDropdown extends StatefulWidget {
  /// Custom segments (`list-data`), joined with [separator] (default " ").
  const KakaoMultiDropdown({
    super.key,
    required List<KakaoMultiDropdownSegment> this.segments,
    this.value,
    this.separator,
    this.placeholder,
    this.allowUnknown,
    this.label,
    this.disabled = false,
    this.onChanged,
    this.onOpenChanged,
    this.controller,
    this.panelKey,
  }) : minYear = 1900,
       maxYear = null;

  /// `type="date"`: Day, Month and Year joined with [separator] (default
  /// ".") into dd.mm.yyyy, years from [maxYear] (default this year) down to
  /// [minYear]. Unknown parts are zeros ("00", "0000"). Days the chosen month
  /// and year don't have are disabled; a day that no longer fits moves to
  /// the month's last day and comes back when it fits again.
  const KakaoMultiDropdown.date({
    super.key,
    this.value,
    this.separator,
    this.placeholder,
    this.allowUnknown,
    this.minYear = 1900,
    this.maxYear,
    this.label,
    this.disabled = false,
    this.onChanged,
    this.onOpenChanged,
    this.controller,
    this.panelKey,
  }) : segments = null;

  /// The segments; null: the date preset.
  final List<KakaoMultiDropdownSegment>? segments;

  /// `value`: the joined value ("00.00.1990").
  final String? value;

  /// `separator`: the text between the parts of the joined value (not drawn).
  final String? separator;

  /// `placeholder`: the text of empty boxes; default [texts]`.placeholder`.
  final String? placeholder;

  /// `allow-unknown`: null none; empty every segment; else the segments
  /// named (`{'day', 'month'}`).
  final Set<String>? allowUnknown;

  /// `min-year` / `max-year` of the date preset.
  final int minYear;
  final int? maxYear;

  /// `label`; default [texts]`.label`.
  final String? label;

  /// `disabled`: dimmed, not focusable, does not open.
  final bool disabled;

  /// `dropdown-change`.
  final ValueChanged<KakaoMultiDropdownChange>? onChanged;

  /// `dropdown-open` (true) and `dropdown-close` (false), with the segment's name.
  final void Function(String segment, bool open)? onOpenChanged;
  final KakaoMultiDropdownController? controller;

  /// Put on the open list (tests, screenshots).
  final Key? panelKey;

  /// multi-dropdown.js's built-in English texts.
  static ({
    String label,
    String placeholder,
    String unknown,
    String notSet,
    String day,
    String month,
    String year,
    List<String> months,
  })
  texts = (
    label: 'Value',
    placeholder: 'Please select',
    unknown: 'Unknown',
    notSet: 'not set',
    day: 'Day',
    month: 'Month',
    year: 'Year',
    months: const [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ],
  );

  @override
  State<KakaoMultiDropdown> createState() => _KakaoMultiDropdownState();
}

/// A list row (multi-dropdown.js `_listFor`).
typedef _Row = ({String value, String label, String hint, bool disabled, bool unknown});

/// A segment, normalised (multi-dropdown.js `_buildSegments`).
class _Seg {
  _Seg({
    required this.name,
    required this.label,
    required this.placeholder,
    required this.short,
    required this.options,
    required this.unknown,
    required this.separator,
  });

  final String name;
  final String label;
  final String placeholder;
  final String short;
  final List<KakaoMultiDropdownOption> options;
  final ({String value, String label, String display})? unknown;
  final String separator;

  late final List<String> all = [?unknown?.value, for (final o in options) o.value];

  final focus = FocusNode();
  final panel = KakaoAnchoredPanelController();
}

String _pad(int n, int len) => '$n'.padLeft(len, '0');
bool _isLeap(int y) => (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;
int _daysIn(int month, int? year) {
  if (month == 2) return year == null || _isLeap(year) ? 29 : 28;
  return const [4, 6, 9, 11].contains(month) ? 30 : 31;
}

final _digits = RegExp(r'^\d+$');

class _KakaoMultiDropdownState extends State<KakaoMultiDropdown> {
  List<_Seg> _segs = const [];
  Map<String, String?> _values = {};
  int? _wantedDay;
  String? _open;
  String? _hover;
  String? _focusVisible;
  final _list = KakaoOptionListController(typeAheadReset: _typeAheadReset);
  String _typed = '';
  Timer? _typedTimer;

  bool get _isDate => widget.segments == null;
  bool get _off => widget.disabled;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
    _build();
    _applyValue(widget.value);
  }

  @override
  void didUpdateWidget(KakaoMultiDropdown old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      if (old.controller?._state == this) old.controller!._state = null;
      widget.controller?._state = this;
    }
    final rebuild =
        !identical(old.segments, widget.segments) ||
        old.separator != widget.separator ||
        old.placeholder != widget.placeholder ||
        !setEquals(old.allowUnknown, widget.allowUnknown) ||
        old.minYear != widget.minYear ||
        old.maxYear != widget.maxYear;
    if (rebuild) {
      _closeQuietly();
      _build();
    }
    if (old.value != widget.value) {
      _applyValue(widget.value);
    } else if (rebuild) {
      _clampDay();
    }
    if (widget.disabled && _open != null) WidgetsBinding.instance.addPostFrameCallback((_) => _close());
  }

  @override
  void dispose() {
    if (widget.controller?._state == this) widget.controller!._state = null;
    _typedTimer?.cancel();
    for (final s in _segs) {
      _dispose(s);
    }
    _list.dispose();
    super.dispose();
  }

  void _dispose(_Seg s) {
    s.panel.removeListener(_panelChanged);
    s.focus.removeListener(_focusChanged);
    // After the frame: the old boxes may still be in the tree this frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      s.panel.dispose();
      s.focus.dispose();
    });
  }

  // ---------------------------------------------------------------- segments

  bool _wantsUnknown(String name, bool? own, KakaoMultiDropdownUnknown? texts) {
    if (own == false) return false;
    if (own == true || texts != null) return true;
    final set = widget.allowUnknown;
    return set != null && (set.isEmpty || set.contains(name));
  }

  List<KakaoMultiDropdownSegment> _dateSegments() {
    final t = KakaoMultiDropdown.texts;
    final now = DateTime.now().year;
    final lo = math.min(widget.minYear, widget.maxYear ?? now);
    final hi = math.max(widget.minYear, widget.maxYear ?? now);
    return [
      KakaoMultiDropdownSegment(
        name: 'day',
        label: t.day,
        shortPlaceholder: 'DD',
        unknownValue: '00',
        options: [for (var d = 1; d <= 31; d++) KakaoMultiDropdownOption(_pad(d, 2))],
      ),
      KakaoMultiDropdownSegment(
        name: 'month',
        label: t.month,
        shortPlaceholder: 'MM',
        unknownValue: '00',
        // Shown by name in the box; the number is the hint in the list and the stored value.
        options: [
          for (var m = 1; m <= 12; m++) KakaoMultiDropdownOption(_pad(m, 2), label: t.months[m - 1], hint: _pad(m, 2)),
        ],
      ),
      KakaoMultiDropdownSegment(
        name: 'year',
        label: t.year,
        shortPlaceholder: 'YYYY',
        unknownValue: '0000',
        options: [for (var y = hi; y >= lo; y--) KakaoMultiDropdownOption('$y')],
      ),
    ];
  }

  void _build() {
    for (final s in _segs) {
      _dispose(s);
    }
    final raw = widget.segments ?? _dateSegments();
    final defaultSep = widget.separator ?? (_isDate ? '.' : ' ');
    final ph = widget.placeholder;
    final defaultPlaceholder = ph != null && ph.trim().isNotEmpty ? ph : KakaoMultiDropdown.texts.placeholder;
    _segs = [
      for (var i = 0; i < raw.length; i++)
        () {
          final s = raw[i];
          final label = s.label ?? s.name;
          final placeholder = s.placeholder ?? defaultPlaceholder;
          final u = s.unknown;
          return _Seg(
            name: s.name,
            label: label,
            placeholder: placeholder,
            short: s.shortPlaceholder ?? (s.placeholder != null ? placeholder : label),
            options: s.options,
            unknown: _wantsUnknown(s.name, s.allowUnknown, u)
                ? (
                    value: u?.value ?? s.unknownValue ?? _unknownCode,
                    label: u?.label ?? KakaoMultiDropdown.texts.unknown,
                    display: u?.display ?? _unknownDisplay,
                  )
                : null,
            separator: i < raw.length - 1 ? (s.separator ?? defaultSep) : '',
          );
        }(),
    ];
    for (final s in _segs) {
      s.panel.addListener(_panelChanged);
      s.focus.addListener(_focusChanged);
    }
    // Keep values that still exist, drop the rest.
    _values = {
      for (final s in _segs)
        s.name: switch (_values[s.name]) {
          final v? when s.all.contains(v) => v,
          _ => null,
        },
    };
  }

  _Seg? _seg(String? name) {
    for (final s in _segs) {
      if (s.name == name) return s;
    }
    return null;
  }

  /// Options as shown in a list: Unknown first, then the others (impossible days disabled).
  List<_Row> _listFor(_Seg seg) {
    final maxDay = seg.name == 'day' && _isDate ? _maxDay() : null;
    return [
      if (seg.unknown case final u?) (value: u.value, label: u.label, hint: '', disabled: false, unknown: true),
      for (final o in seg.options)
        (
          value: o.value,
          label: o.label,
          hint: o.hint,
          disabled: o.disabled || (maxDay != null && (int.tryParse(o.value) ?? 0) > maxDay),
          unknown: false,
        ),
    ];
  }

  /// The last valid day for the chosen month and year; 31 while either is unset or unknown.
  int _maxDay() {
    final m = int.tryParse(_values['month'] ?? '') ?? 0;
    final y = int.tryParse(_values['year'] ?? '') ?? 0;
    if (m == 0) return 31;
    return _daysIn(m, y == 0 ? null : y);
  }

  // ------------------------------------------------------------------- value

  String _joined() {
    if (_segs.isEmpty) return '';
    final out = StringBuffer();
    for (final s in _segs) {
      final v = _values[s.name];
      if (v == null) return '';
      out
        ..write(v)
        ..write(s.separator);
    }
    return out.toString();
  }

  Map<String, String?> _parts() => {for (final s in _segs) s.name: _values[s.name]};

  /// Parses a joined value into the segments, separator by separator.
  void _applyValue(String? raw) {
    _values = {for (final s in _segs) s.name: null};
    _wantedDay = null;
    if (raw == null || raw.isEmpty) return;
    var rest = raw;
    for (final s in _segs) {
      var part = rest;
      if (s.separator.isNotEmpty) {
        final i = rest.indexOf(s.separator);
        part = i == -1 ? rest : rest.substring(0, i);
        rest = i == -1 ? '' : rest.substring(i + s.separator.length);
      } else {
        rest = '';
      }
      if (s.all.contains(part)) _values[s.name] = part;
    }
    _rememberDay();
    _clampDay();
  }

  /// Dates: the day the user picked, or the month's last day if it is
  /// shorter; works from [_wantedDay] so a short month on the way never loses it.
  void _clampDay() {
    final wanted = _wantedDay;
    if (!_isDate || wanted == null) return;
    _values['day'] = _pad(math.min(wanted, _maxDay()), 2);
  }

  void _rememberDay() {
    if (!_isDate) return;
    final d = int.tryParse(_values['day'] ?? '') ?? 0;
    _wantedDay = d > 0 ? d : null;
  }

  void _choose(_Seg seg, String? value) {
    if (value != null && !seg.all.contains(value)) return;
    if (_values[seg.name] == value) return;
    setState(() {
      _values[seg.name] = value;
      if (seg.name == 'day') _rememberDay();
      _clampDay();
    });
    final parts = _parts();
    widget.onChanged?.call(
      KakaoMultiDropdownChange._(_joined(), Map.unmodifiable(parts), [
        for (final s in _segs)
          if (s.unknown != null && parts[s.name] == s.unknown!.value) s.name,
      ]),
    );
  }

  void _setValue(String v) => setState(() => _applyValue(v));

  void _setPart(String name, String? value) {
    final s = _seg(name);
    if (s != null) _choose(s, value);
  }

  void _clear() {
    setState(() {
      for (final s in _segs) {
        _values[s.name] = null;
      }
    });
    widget.onChanged?.call(KakaoMultiDropdownChange._('', Map.unmodifiable(_parts()), const []));
  }

  void _focusFirst() {
    if (_segs.isNotEmpty && !_off) _segs.first.focus.requestFocus();
  }

  // ------------------------------------------------------------ open / close

  void _openSeg(String name) {
    if (_off) return;
    final seg = _seg(name);
    if (seg == null) return;
    if (_open != null && _open != name) _close();
    if (_open == name) return;
    _list.highlight(null);
    setState(() => _open = name);
    seg.panel.open();
    widget.onOpenChanged?.call(name, true);
  }

  void _close() {
    final seg = _seg(_open);
    if (seg == null) return;
    _closeQuietly();
    widget.onOpenChanged?.call(seg.name, false);
  }

  void _closeQuietly() {
    final seg = _seg(_open);
    if (seg == null) return;
    if (mounted) setState(() => _open = null);
    seg.panel.close();
  }

  /// A panel closed itself (outside tap, Escape).
  void _panelChanged() {
    final seg = _seg(_open);
    if (seg != null && !seg.panel.isOpen) _close();
  }

  /// Focus left the open box (Tab, a click elsewhere): it closes.
  void _focusChanged() {
    final seg = _seg(_open);
    if (seg != null && !seg.focus.hasFocus) _close();
  }

  /// Picks from the open list, closes it, and keeps focus on the box.
  void _pick(_Seg seg, String value) {
    _close();
    _choose(seg, value);
    seg.focus.requestFocus();
  }

  void _tap(_Seg seg) {
    if (_off) return;
    seg.focus.requestFocus();
    _open == seg.name ? _close() : _openSeg(seg.name);
  }

  // ------------------------------------------------------------------- keys

  KeyEventResult _onKey(_Seg seg, KeyEvent e) {
    if (_off || (e is! KeyDownEvent && e is! KeyRepeatEvent)) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final keys = HardwareKeyboard.instance;
    final list = _listFor(seg);
    final open = _open == seg.name;
    final enter = k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter;

    if (open) {
      if (k == LogicalKeyboardKey.arrowDown) {
        _moveActive(list, 1);
      } else if (k == LogicalKeyboardKey.arrowUp) {
        _moveActive(list, -1);
      } else if (k == LogicalKeyboardKey.pageDown) {
        _moveActive(list, _pageStep);
      } else if (k == LogicalKeyboardKey.pageUp) {
        _moveActive(list, -_pageStep);
      } else if (k == LogicalKeyboardKey.home) {
        _moveActive(list, 1, from: -1);
      } else if (k == LogicalKeyboardKey.end) {
        _moveActive(list, -1, from: list.length);
      } else if (enter || k == LogicalKeyboardKey.space) {
        if (e is KeyDownEvent) {
          final i = _list.highlighted;
          if (i != null && i < list.length && !list[i].disabled) _pick(seg, list[i].value);
        }
      } else if (k == LogicalKeyboardKey.escape || k == LogicalKeyboardKey.tab) {
        // Escape: the panel closes itself; Tab: focus moves on and the list closes.
        return KeyEventResult.ignored;
      } else {
        return _typeKey(seg, list, e, open: true);
      }
      return KeyEventResult.handled;
    }

    if (k == LogicalKeyboardKey.arrowDown) {
      keys.isAltPressed ? _openSeg(seg.name) : _step(seg, list, 1);
    } else if (k == LogicalKeyboardKey.arrowUp) {
      _step(seg, list, -1);
    } else if (enter || k == LogicalKeyboardKey.space) {
      if (e is KeyDownEvent) _openSeg(seg.name);
    } else if (k == LogicalKeyboardKey.arrowRight) {
      _focusSibling(seg, 1);
    } else if (k == LogicalKeyboardKey.arrowLeft) {
      _focusSibling(seg, -1);
    } else if (k == LogicalKeyboardKey.delete || k == LogicalKeyboardKey.backspace) {
      _choose(seg, null);
    } else {
      return _typeKey(seg, list, e, open: false);
    }
    return KeyEventResult.handled;
  }

  KeyEventResult _typeKey(_Seg seg, List<_Row> list, KeyEvent e, {required bool open}) {
    final keys = HardwareKeyboard.instance;
    final c = e.character;
    if (c == null || c.runes.length != 1 || c.runes.first < 0x20 || c.runes.first == 0x7f) {
      return KeyEventResult.ignored;
    }
    if (keys.isControlPressed || keys.isMetaPressed || keys.isAltPressed) return KeyEventResult.ignored;
    _typeahead(seg, list, c, open: open);
    return KeyEventResult.handled;
  }

  /// multi-dropdown.js `_moveActive`: [dir] enabled rows on, clamped at the ends.
  void _moveActive(List<_Row> list, int dir, {int? from}) {
    if (list.isEmpty) return;
    var i = from ?? _list.highlighted ?? -1;
    final step = dir.sign;
    var remaining = dir.abs();
    var target = from == null ? i : -1;
    while (remaining > 0) {
      i += step;
      if (i < 0 || i >= list.length) break;
      if (!list[i].disabled) {
        target = i;
        remaining--;
      }
    }
    if (target >= 0) _list.highlight(target, keyboard: true);
  }

  /// Up / Down on a closed box: the previous / next enabled value.
  void _step(_Seg seg, List<_Row> list, int dir) {
    var i = list.indexWhere((o) => o.value == _values[seg.name]);
    if (i == -1) i = dir > 0 ? (seg.unknown != null ? 0 : -1) : list.length;
    for (var n = 0; n < list.length; n++) {
      i += dir;
      if (i < 0 || i >= list.length) return;
      if (!list[i].disabled) break;
    }
    if (i >= 0 && i < list.length) _choose(seg, list[i].value);
  }

  void _focusSibling(_Seg seg, int dir) {
    final i = _segs.indexOf(seg) + dir;
    if (i >= 0 && i < _segs.length) _segs[i].focus.requestFocus();
  }

  /// multi-dropdown.js `_typeahead`: matches values and labels (numbers by
  /// value, "3" finds "03"); on a closed box a match is taken, and with
  /// nothing longer left to match focus moves to the next box.
  void _typeahead(_Seg seg, List<_Row> list, String key, {required bool open}) {
    _typedTimer?.cancel();
    _typedTimer = Timer(_typeAheadReset, () => _typed = '');
    _typed += key;
    final typed = _typed.toLowerCase();
    final numeric = _digits.hasMatch(typed);
    String num(String s) => '${int.parse(s)}';

    final candidates = [
      for (final o in list)
        if (!o.disabled &&
            (o.value.toLowerCase().startsWith(typed) ||
                o.label.toLowerCase().startsWith(typed) ||
                (numeric && _digits.hasMatch(o.value) && num(o.value).startsWith(num(typed)) && !o.unknown)))
          o,
    ];
    if (candidates.isEmpty) {
      _typed = key; // start over with just this key next time
      return;
    }
    // An exact value wins ("00" = Unknown, "3" = "03"); else a real value over Unknown.
    final exact = candidates.where(
      (o) => o.value.toLowerCase() == typed || (numeric && int.tryParse(o.value) == int.parse(typed) && !o.unknown),
    );
    final real = candidates.where((o) => !o.unknown);
    final pick = exact.isNotEmpty ? exact.first : (real.isNotEmpty ? real.first : candidates.first);

    if (open) {
      _list.highlight(list.indexOf(pick), keyboard: true);
      return;
    }
    _choose(seg, pick.value);
    // Done with this box when nothing longer could still match.
    final longer = candidates.where(
      (o) =>
          o != pick &&
          (o.value.toLowerCase().startsWith(typed) ||
              (numeric && _digits.hasMatch(o.value) && num(o.value).startsWith(num(typed)))),
    );
    if (longer.isEmpty || typed.length >= pick.value.length) {
      _typed = '';
      _focusSibling(seg, 1);
    }
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    final st = KakaoMultiDropdownSettings.of(theme.colors);
    final size = st.font.size;
    final text = theme.text(size: size, color: st.text, height: st.font.lineHeight, tabular: true);
    final label = widget.label ?? KakaoMultiDropdown.texts.label;
    final scaler = MediaQuery.textScalerOf(context);
    final chevron = st.chevronSize.of(size);
    // Everything in a box but its text: padding, chevron and gap, border.
    final chrome = st.padding.horizontal + st.chevronGap + chevron + 2;

    double measure(String s) {
      final p = TextPainter(
        text: TextSpan(text: s, style: text),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final w = p.width;
      p.dispose();
      return w;
    }

    // The widest label a box can show (multi-dropdown.js's `.sizer` copies),
    // and its long placeholder while empty.
    final widest = [
      for (final s in _segs)
        [s.short, for (final o in s.options) o.label, ?s.unknown?.display].map(measure).fold(0.0, math.max),
    ];
    final longs = [for (final s in _segs) _values[s.name] == null ? measure(s.placeholder) : null];

    Widget group = LayoutBuilder(
      builder: (context, constraints) {
        final room = constraints.maxWidth;
        final n = _segs.length;

        /// The box widths, shrunk as flex-shrink does (by their widths) to fit.
        /// A box keeps at least its chrome (the text goes first); the group
        /// may then be wider than the room.
        List<double> fit(List<double> natural) {
          final total = natural.fold(0.0, (a, b) => a + b);
          final free = room - (total - math.max(0, n - 1));
          if (free >= 0 || total == 0) return natural;
          return [for (final w in natural) math.max(chrome, w + free * w / total)];
        }

        // multi-dropdown.js `_checkCramped`: a long placeholder that is cut
        // off in the full layout switches every empty box to its short one.
        final full = fit([for (var i = 0; i < n; i++) math.max(widest[i], longs[i] ?? 0) + chrome]);
        final cramped = [
          for (var i = 0; i < n; i++)
            if (longs[i] case final l?) l > full[i] - chrome + .5,
        ].any((c) => c);
        final widths = cramped ? fit([for (var i = 0; i < n; i++) widest[i] + chrome]) : full;
        final lefts = [for (var i = 0, x = 0.0; i < n; x += widths[i] - 1, i++) x];

        final boxes = <Widget>[
          for (var i = 0; i < n; i++)
            SizedBox(
              // Neighbours overlap by one border width (`.seg + .seg { margin-left: -1px }`).
              width: i < n - 1 ? math.max(0.0, widths[i] - 1) : widths[i],
              child: OverflowBox(
                alignment: AlignmentDirectional.centerStart,
                minWidth: widths[i],
                maxWidth: widths[i],
                fit: OverflowBoxFit.deferToChild,
                child: _box(i, st, text, chevron, cramped: cramped, width: widths[i]),
              ),
            ),
        ];
        // The open box, else the keyboard-focused one, draws its border (and
        // the focus outline) over its neighbours (z-index: 1).
        final raised = _segs.indexWhere((s) => s.name == _focusVisible);
        final top = raised >= 0 ? raised : _segs.indexWhere((s) => s.name == _open);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            OverflowBox(
              alignment: AlignmentDirectional.centerStart,
              minWidth: 0,
              maxWidth: double.infinity,
              fit: OverflowBoxFit.deferToChild,
              child: Row(mainAxisSize: MainAxisSize.min, children: boxes),
            ),
            if (top >= 0)
              Positioned(
                left: lefts[top],
                top: 0,
                bottom: 0,
                width: widths[top],
                child: IgnorePointer(
                  child: _Raised(radius: _radius(top, st.radius), settings: st, ring: raised >= 0),
                ),
              ),
          ],
        );
      },
    );

    group = Semantics(container: true, explicitChildNodes: true, label: label, child: group);

    Widget field = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: st.labelGap),
          child: ExcludeSemantics(
            child: GestureDetector(
              onTap: _off ? null : _focusFirst,
              child: Text(
                label,
                style: theme.text(size: size, weight: _labelWeight, color: st.text, height: st.font.lineHeight),
              ),
            ),
          ),
        ),
        group,
      ],
    );
    if (_off) field = Opacity(opacity: st.disabledOpacity, child: field);
    return field;
  }

  /// Only the group's outer corners are rounded.
  BorderRadius _radius(int i, double r) {
    final first = i == 0, last = i == _segs.length - 1;
    return BorderRadius.horizontal(left: Radius.circular(first ? r : 0), right: Radius.circular(last ? r : 0));
  }

  Widget _box(
    int i,
    KakaoMultiDropdownSettings st,
    TextStyle text,
    double chevron, {
    required bool cramped,
    required double width,
  }) {
    final seg = _segs[i];
    final v = _values[seg.name];
    final unknown = seg.unknown;
    final isUnknown = v != null && unknown != null && v == unknown.value;
    final open = _open == seg.name;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final radius = _radius(i, st.radius);

    final shown = v == null
        ? (cramped ? seg.short : seg.placeholder)
        : isUnknown
        ? unknown.display
        : seg.options.firstWhere((o) => o.value == v, orElse: () => KakaoMultiDropdownOption(v)).label;
    final spoken = v == null
        ? KakaoMultiDropdown.texts.notSet
        : isUnknown
        ? unknown.label
        : switch (seg.options.where((o) => o.value == v)) {
            final o when o.isEmpty => v,
            final o => o.first.hint.isEmpty ? o.first.label : '${o.first.label} (${o.first.hint})',
          };

    final content = Row(
      children: [
        Expanded(
          child: Text(
            shown,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: v == null || isUnknown ? text.copyWith(color: st.muted) : text,
          ),
        ),
        SizedBox(width: st.chevronGap),
        AnimatedRotation(
          turns: open ? .5 : 0,
          duration: reduce ? Duration.zero : _chevronTurn,
          curve: Curves.ease,
          child: CustomPaint(size: Size.square(chevron), painter: _ChevronPainter(st.muted)),
        ),
      ],
    );

    final focused = _focusVisible == seg.name;
    Widget box = AnimatedContainer(
      duration: reduce ? Duration.zero : _borderFade,
      curve: Curves.ease,
      foregroundDecoration: BoxDecoration(
        border: Border.all(
          color: focused
              ? st.focus
              : open
              ? st.accent
              : st.border,
        ),
        borderRadius: radius,
      ),
      child: AnimatedContainer(
        duration: reduce ? Duration.zero : _bgFade,
        curve: Curves.ease,
        padding: st.padding + const EdgeInsets.all(1),
        decoration: BoxDecoration(color: _hover == seg.name && !_off ? st.hoverBg : st.bg, borderRadius: radius),
        child: content,
      ),
    );

    box = KakaoAnchoredPanel(
      controller: seg.panel,
      enabled: !_off,
      // .popup: absolute, top: calc(100% + popup-offset), left: 0; it never flips.
      placement: KakaoPanelPlacement(
        side: KakaoPanelSide.bottom,
        align: KakaoPanelAlign.start,
        offset: st.popupOffset,
        flip: KakaoPanelFlip.none,
      ),
      motion: KakaoPanelMotion(duration: _popIn, curve: Curves.easeOut, slide: _popSlide, scale: _popScale),
      // Focus never leaves the box while its list is open.
      returnFocus: false,
      panelBuilder: (context, side) => _popup(seg, st, text, width),
      child: box,
    );

    return Semantics(
      button: true,
      enabled: !_off,
      expanded: open,
      focusable: !_off,
      focused: seg.focus.hasFocus,
      label: '${seg.label}, $spoken',
      tooltip: isUnknown ? '${seg.label}: ${unknown.label}' : null,
      onTap: _off ? null : () => _tap(seg),
      excludeSemantics: true,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        includeSemantics: false,
        onKeyEvent: (_, e) => _onKey(seg, e),
        child: FocusableActionDetector(
          focusNode: seg.focus,
          enabled: !_off,
          mouseCursor: _off ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
          onShowFocusHighlight: (on) {
            if (on) {
              setState(() => _focusVisible = seg.name);
            } else if (_focusVisible == seg.name) {
              setState(() => _focusVisible = null);
            }
          },
          child: MouseRegion(
            onEnter: (_) => setState(() => _hover = seg.name),
            onExit: (_) {
              if (_hover == seg.name) setState(() => _hover = null);
            },
            child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _off ? null : () => _tap(seg), child: box),
          ),
        ),
      ),
    );
  }

  /// `.popup`: the open list.
  Widget _popup(_Seg seg, KakaoMultiDropdownSettings st, TextStyle text, double boxWidth) {
    final rows = _listFor(seg);
    final current = _values[seg.name];
    final at = rows.indexWhere((o) => o.value == current);
    final initial = at >= 0 ? at : rows.indexWhere((o) => !o.disabled && !o.unknown);
    final rowText = text.copyWith(height: st.font.lineHeight);
    final selected = TextStyle(
      color: st.accent,
      fontWeight: FontWeight.values[(_selectedWeight / 100).round() - 1],
      fontVariations: const [FontVariation.weight(_selectedWeight)],
    );
    final struck = TextStyle(decoration: TextDecoration.lineThrough, decorationColor: st.muted);
    const italic = TextStyle(fontStyle: FontStyle.italic);
    final lineBox = _scaledLine(rowText);

    final style = KakaoOptionListStyle(
      text: rowText,
      rowMinHeight: 0,
      rowPadding: st.optionPadding,
      rowRadius: st.optionRadius,
      gap: _optionGap,
      trailingGap: _optionGap,
      leadSize: 0,
      highlight: st.hoverBg,
      check: st.accent,
      icon: st.muted,
      heading: rowText,
      headingPadding: EdgeInsets.zero,
      separator: st.hoverBg,
      separatorMargin: 0,
      padding: EdgeInsets.all(st.popupPadding),
      duration: _optionFade,
      curve: Curves.ease,
      disabledColor: st.muted,
    );

    final entries = <KakaoOptionEntry>[
      for (final o in rows)
        () {
          final on = o.value == current;
          var extra = const TextStyle();
          if (o.unknown) extra = extra.merge(italic);
          if (on) extra = extra.merge(selected);
          if (o.disabled) extra = extra.merge(struck);
          Widget? hint;
          if (o.hint.isNotEmpty) {
            final hs = rowText.merge(extra).copyWith(color: st.muted, fontSize: rowText.fontSize! * _hintSize);
            // The hint's smaller line box sits at the top of the row (align-items: stretch).
            hint = Padding(
              padding: EdgeInsets.only(bottom: math.max(0, lineBox - _scaledLine(hs))),
              child: Text(o.hint, style: hs),
            );
          }
          return KakaoOption(label: o.label, disabled: o.disabled, textStyle: extra, selected: on, trailing: hint);
        }(),
    ];

    final unknownRow = seg.unknown != null ? 0 : -1;
    final minWidth = math.max(boxWidth, _popupMinWidth);
    return ConstrainedBox(
      key: widget.panelKey,
      constraints: BoxConstraints(minWidth: minWidth, maxHeight: st.popupHeight),
      child: IntrinsicWidth(
        child: Container(
          decoration: BoxDecoration(
            color: st.bg,
            border: Border.all(color: st.border),
            borderRadius: BorderRadius.circular(st.radius),
            boxShadow: st.popupShadow,
          ),
          child: KakaoOptionList(
            entries: entries,
            style: style,
            controller: _list,
            initial: initial >= 0 ? initial : null,
            onActivate: (i) {
              if (i < rows.length && !rows[i].disabled) _pick(seg, rows[i].value);
            },
            // `.option.is-unknown`: a line under it, and a little room.
            rowWrapper: (i, row) => i != unknownRow
                ? row
                : Padding(
                    padding: const EdgeInsets.only(bottom: _unknownGap),
                    child: DecoratedBox(
                      position: DecorationPosition.foreground,
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: st.hoverBg)),
                        borderRadius: BorderRadius.circular(st.optionRadius),
                      ),
                      child: Padding(padding: const EdgeInsets.only(bottom: 1), child: row),
                    ),
                  ),
            semanticsRole: SemanticsRole.list,
            semanticsLabel: seg.label,
          ),
        ),
      ),
    );
  }

  double _scaledLine(TextStyle s) => MediaQuery.textScalerOf(context).scale(s.fontSize!) * (s.height ?? 1);
}

/// The open or keyboard-focused box's border (and focus outline) drawn over
/// its neighbours.
class _Raised extends StatelessWidget {
  const _Raised({required this.radius, required this.settings, required this.ring});

  final BorderRadius radius;
  final KakaoMultiDropdownSettings settings;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final st = settings;
    final color = ring ? st.focus : st.accent;
    final out = st.focusOffset + st.focusWidth;
    Radius grow(Radius r) => r == Radius.zero ? r : Radius.circular(r.x + out);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: color),
              borderRadius: radius,
            ),
          ),
        ),
        if (ring)
          Positioned(
            left: -out,
            top: -out,
            right: -out,
            bottom: -out,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: st.focus, width: st.focusWidth),
                borderRadius: BorderRadius.only(
                  topLeft: grow(radius.topLeft),
                  topRight: grow(radius.topRight),
                  bottomLeft: grow(radius.bottomLeft),
                  bottomRight: grow(radius.bottomRight),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// multi-dropdown.js `CHEVRON`: `M7 10l5 5 5-5` in a 24 box, stroke 2, round caps and joins.
class _ChevronPainter extends CustomPainter {
  const _ChevronPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    canvas.drawPath(
      Path()
        ..moveTo(7 * k, 10 * k)
        ..lineTo(12 * k, 15 * k)
        ..lineTo(17 * k, 10 * k),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = _chevronStroke * k
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter old) => old.color != color;
}
