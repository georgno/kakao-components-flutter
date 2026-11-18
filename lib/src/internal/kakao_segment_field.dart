// The segmented date / time field: the browser's own editable part of a
// date, time, datetime-local, month or week <input> (Chromium's
// `-webkit-datetime-edit`), as date-input and time-input keep it. Not
// exported; the owner holds the parts and draws the box around it.
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'kakao_date_values.dart';

// Chromium's datetime edit, outside any settings block.
const _segmentPadding = 1.0; // -webkit-datetime-edit-*-field: padding-inline 1px
const _monthNamePlaceholder = '---------'; // an empty month name field
const _dashes = '--'; // an empty week, hour, minute, second or AM / PM field

/// The parts of a date or time field, edited one at a time, as Chromium's
/// native field does:
///
/// - focus lands on the first part (the last one when it comes back with
///   Shift+Tab), a pointer down on a part focuses that part; Tab, Shift+Tab,
///   Left and Right move between parts (Tab leaves after the last one);
/// - digits type into the part and move on once no further digit fits
///   (a month after "3" or "12", a year after four digits); "a" / "p" set
///   AM / PM; a separator moves on from a part that has a value;
/// - Up and Down step the part with wrap-around (minutes and seconds by the
///   field's step where it divides the hour or minute), an empty part takes
///   its lowest / highest value, an empty year the current one;
/// - Backspace and Delete empty the part.
///
/// [fields] is the owner's; every edit is [onChanged] with the new parts.
/// [onCommit] comes when the user leaves a part (to another part or out of
/// the field): the native field's `change` point. Alt+Down and F4 call
/// [onOpenPicker]; with [tapOpensPicker] (a touch platform, where the
/// browser opens its picker dialog on a tap) a tap does too.
///
/// The focused part is filled with [highlight] while the field has focus.
/// [readOnly] keeps it focusable and walkable but not editable; [enabled]
/// false takes focus away.
class KakaoSegmentField extends StatefulWidget {
  const KakaoSegmentField({
    super.key,
    required this.layout,
    required this.fields,
    required this.format,
    required this.focusNode,
    required this.style,
    required this.highlight,
    required this.onChanged,
    this.step = 60,
    this.enabled = true,
    this.readOnly = false,
    this.dayPeriods = const ('AM', 'PM'),
    this.onCommit,
    this.onOpenPicker,
    this.tapOpensPicker = false,
    this.now = DateTime.now,
  });

  /// [KakaoSegment]s and literal strings, in order ([KakaoDateFormat.layout]).
  final List<Object> layout;
  final KakaoDateFields fields;
  final KakaoDateFormat format;
  final FocusNode focusNode;

  /// The text style (tabular figures, as `font-variant-numeric: tabular-nums`).
  final TextStyle style;
  final Color highlight;
  final ValueChanged<KakaoDateFields> onChanged;

  /// The field's `step` in seconds (time parts).
  final double step;
  final bool enabled;
  final bool readOnly;
  final (String, String) dayPeriods;
  final VoidCallback? onCommit;
  final VoidCallback? onOpenPicker;
  final bool tapOpensPicker;

  /// The clock an empty year steps from.
  final DateTime Function() now;

  @override
  State<KakaoSegmentField> createState() => KakaoSegmentFieldState();
}

class KakaoSegmentFieldState extends State<KakaoSegmentField> {
  /// Indexes into [KakaoSegmentField.layout] of the parts.
  List<int> get _parts => [
    for (var i = 0; i < widget.layout.length; i++)
      if (widget.layout[i] is KakaoSegment) i,
  ];

  /// The focused part, by its place among the parts.
  int _active = 0;

  /// The digits typed into the focused part so far.
  String _typed = '';

  /// A part a pointer went down on, to focus once focus arrives.
  int? _pointerPart;
  bool _focused = false;

  /// The parts after this field's last edit, until the owner rebuilds it
  /// with them (two keys in one frame build on each other).
  KakaoDateFields? _latest;
  KakaoDateFields get _f => _latest ?? widget.fields;

  /// The focused part.
  KakaoSegment? get activeSegment {
    final parts = _parts;
    if (!_focused || parts.isEmpty) return null;
    return widget.layout[parts[_active.clamp(0, parts.length - 1)]] as KakaoSegment;
  }

  bool get _hour12 => widget.format.hour12;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_focusChanged);
    _focused = widget.focusNode.hasFocus;
  }

  @override
  void didUpdateWidget(KakaoSegmentField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_focusChanged);
      widget.focusNode.addListener(_focusChanged);
      _focused = widget.focusNode.hasFocus;
    }
    _latest = null;
    final n = _parts.length;
    if (_active >= n) _active = n == 0 ? 0 : n - 1;
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_focusChanged);
    super.dispose();
  }

  void _focusChanged() {
    final f = widget.focusNode.hasFocus;
    if (f == _focused) return;
    setState(() {
      _focused = f;
      _typed = '';
      if (f) {
        final p = _pointerPart;
        _active = p ?? (HardwareKeyboard.instance.isShiftPressed ? _parts.length - 1 : 0);
      }
      _pointerPart = null;
    });
    if (!f) widget.onCommit?.call();
  }

  /// Moves to part [i]; a commit when that leaves a part.
  void _moveTo(int i) {
    final n = _parts.length;
    final to = i.clamp(0, n - 1);
    if (to == _active) {
      setState(() => _typed = '');
      return;
    }
    setState(() {
      _active = to;
      _typed = '';
    });
    widget.onCommit?.call();
  }

  KakaoSegment get _seg => widget.layout[_parts[_active]] as KakaoSegment;

  void _set(int? v) {
    final next = _f.withPart(_seg, v);
    if (next == _f) return;
    _latest = next;
    widget.onChanged(next);
  }

  void _stepBy(bool up) {
    final s = _seg;
    final f = _f;
    final cur = f[s];
    final (lo, hi) = kakaoPartRange(s, f, hour12: _hour12);
    final by = kakaoPartStep(s, widget.step);
    int next;
    if (s == KakaoSegment.dayPeriod) {
      next = cur == null ? (up ? 0 : 1) : 1 - cur;
    } else if (cur == null) {
      next = s == KakaoSegment.year ? widget.now().year : (up ? lo : lo + (hi - lo) ~/ by * by);
    } else if (s == KakaoSegment.year) {
      next = kakaoClampInt(cur + (up ? 1 : -1), lo, hi);
    } else if (up) {
      next = ((cur - lo) ~/ by + 1) * by + lo;
      if (next > hi) next = lo;
    } else {
      next = (((cur - lo) + by - 1) ~/ by - 1) * by + lo;
      if (next < lo) next = lo + (hi - lo) ~/ by * by;
    }
    _typed = '';
    _set(next);
  }

  void _digit(int d) {
    final s = _seg;
    if (s == KakaoSegment.dayPeriod || s == KakaoSegment.monthName && widget.format.monthNames == null) return;
    final (lo, hi) = kakaoPartRange(s, _f, hour12: _hour12);
    final digits = kakaoPartDigits(s);
    var buf = _typed.length >= digits ? '$d' : '$_typed$d';
    var n = int.parse(buf);
    if (n > hi) {
      buf = '$d';
      n = d;
    }
    _typed = buf;
    _set(n >= lo && n <= hi ? n : null);
    if (buf.length >= digits || n * 10 > hi) {
      if (_active < _parts.length - 1) {
        _moveTo(_active + 1);
      } else {
        setState(() => _typed = '');
      }
    } else {
      setState(() {});
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final keyboard = HardwareKeyboard.instance;
    final n = _parts.length;
    if (n == 0) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.tab) {
      if (keyboard.isControlPressed || keyboard.isAltPressed || keyboard.isMetaPressed) return KeyEventResult.ignored;
      final back = keyboard.isShiftPressed;
      if (back ? _active == 0 : _active == n - 1) return KeyEventResult.ignored;
      _moveTo(_active + (back ? -1 : 1));
      return KeyEventResult.handled;
    }
    final rtl = Directionality.maybeOf(context) == TextDirection.rtl;
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight) {
      final forward = (key == LogicalKeyboardKey.arrowRight) != rtl;
      _moveTo(_active + (forward ? 1 : -1));
      return KeyEventResult.handled;
    }
    if ((key == LogicalKeyboardKey.arrowDown && keyboard.isAltPressed) || key == LogicalKeyboardKey.f4) {
      if (widget.readOnly) return KeyEventResult.handled;
      widget.onOpenPicker?.call();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowDown) {
      if (!widget.readOnly) _stepBy(key == LogicalKeyboardKey.arrowUp);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace || key == LogicalKeyboardKey.delete) {
      if (!widget.readOnly) {
        _typed = '';
        _set(null);
        setState(() {});
      }
      return KeyEventResult.handled;
    }
    if (keyboard.isControlPressed || keyboard.isMetaPressed || keyboard.isAltPressed) return KeyEventResult.ignored;
    final ch = event.character;
    if (ch == null || ch.isEmpty) return KeyEventResult.ignored;
    final digit = int.tryParse(ch);
    if (digit != null && ch.length == 1) {
      if (!widget.readOnly) _digit(digit);
      return KeyEventResult.handled;
    }
    if (_seg == KakaoSegment.dayPeriod) {
      final c = ch.toLowerCase();
      final (am, pm) = widget.dayPeriods;
      final isAm = c == am.substring(0, 1).toLowerCase();
      final isPm = c == pm.substring(0, 1).toLowerCase();
      if (isAm || isPm) {
        if (!widget.readOnly) {
          _set(isPm ? 1 : 0);
          if (_active < n - 1) _moveTo(_active + 1);
        }
        return KeyEventResult.handled;
      }
    }
    if (const {'/', '-', '.', ':', ',', ' '}.contains(ch)) {
      // A separator moves on from a part that holds something.
      if (_active < n - 1 && (_f[_seg] != null || _typed.isNotEmpty)) _moveTo(_active + 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  String _text(KakaoSegment s) {
    final v = _f[s];
    final fmt = widget.format;
    final active = _focused && s == activeSegment;
    if (active && _typed.isNotEmpty) return _typed.padLeft(kakaoPartDigits(s), '0');
    if (v == null) {
      return switch (s) {
        KakaoSegment.year => fmt.yearPlaceholder,
        KakaoSegment.month => fmt.monthPlaceholder,
        KakaoSegment.day => fmt.dayPlaceholder,
        KakaoSegment.monthName => _monthNamePlaceholder,
        _ => _dashes,
      };
    }
    return switch (s) {
      KakaoSegment.year => v.toString().padLeft(4, '0'),
      KakaoSegment.monthName => fmt.monthNames?[v - 1] ?? v.toString().padLeft(2, '0'),
      KakaoSegment.dayPeriod => v == 1 ? widget.dayPeriods.$2 : widget.dayPeriods.$1,
      _ => v.toString().padLeft(2, '0'),
    };
  }

  /// The field as it reads, for semantics ("03/04/2026").
  String get text => [
    for (final p in widget.layout)
      if (p is KakaoSegment) _text(p) else p as String,
  ].join();

  @override
  Widget build(BuildContext context) {
    final parts = _parts;
    final children = <Widget>[];
    for (var i = 0; i < widget.layout.length; i++) {
      final p = widget.layout[i];
      if (p is String) {
        children.add(Text(p, style: widget.style));
        continue;
      }
      final s = p as KakaoSegment;
      final index = parts.indexOf(i);
      final lit = _focused && index == _active;
      children.add(
        Listener(
          onPointerDown: widget.enabled && !widget.tapOpensPicker
              ? (e) {
                  if (e.kind == PointerDeviceKind.mouse && e.buttons != kPrimaryMouseButton) return;
                  if (_focused) {
                    _moveTo(index);
                  } else {
                    _pointerPart = index;
                    widget.focusNode.requestFocus();
                  }
                }
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: _segmentPadding),
            color: lit ? widget.highlight : null,
            child: Text(_text(s), style: widget.style),
          ),
        ),
      );
    }
    return Focus(
      focusNode: widget.focusNode,
      canRequestFocus: widget.enabled,
      skipTraversal: !widget.enabled,
      includeSemantics: false,
      onKeyEvent: _onKey,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled && widget.tapOpensPicker && !widget.readOnly
            ? () {
                widget.focusNode.requestFocus();
                widget.onOpenPicker?.call();
              }
            : null,
        child: ClipRect(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Row(mainAxisSize: MainAxisSize.min, children: children),
          ),
        ),
      ),
    );
  }
}
