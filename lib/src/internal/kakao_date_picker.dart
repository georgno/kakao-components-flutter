// The date and time picker: what the browser opens for a date, time,
// datetime-local, month or week <input>, drawn in the library's look for the
// anchored panel. Not exported; date-input (and time-input after it) put it
// in a KakaoAnchoredPanel and feed it their own colours and the select's
// panel chrome.
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'kakao_date_values.dart';
import 'kakao_field.dart';

/// The picker's words (English defaults in the owner's `texts`).
typedef KakaoPickerTexts = ({
  String clear,
  String today,
  String previous,
  String next,
  String chooseMonth,
  String week,
  // Monday first.
  List<String> weekdays,
  List<String> months,
  List<String> monthsShort,
  String hours,
  String minutes,
  String seconds,
  String dayPeriod,
});

/// How the picker looks: every colour and length from the owner's settings.
@immutable
class KakaoPickerStyle {
  const KakaoPickerStyle({
    required this.text,
    required this.heading,
    required this.small,
    required this.textColor,
    required this.muted,
    required this.background,
    required this.hover,
    required this.selected,
    required this.onSelected,
    required this.focus,
    required this.radius,
    required this.cellRadius,
    required this.cell,
    required this.padding,
    required this.shadow,
    required this.disabledOpacity,
    required this.focusWidth,
  });

  /// Day numbers, month names, buttons.
  final TextStyle text;

  /// The month and year over the calendar.
  final TextStyle heading;

  /// The weekday row and week numbers.
  final TextStyle small;
  final Color textColor;
  final Color muted;
  final Color background;
  final Color hover;
  final Color selected;
  final Color onSelected;
  final Color focus;
  final double radius;
  final double cellRadius;

  /// A day cell's side, a month cell's and a time row's height.
  final double cell;
  final double padding;
  final List<BoxShadow> shadow;
  final double disabledOpacity;
  final double focusWidth;
}

// The picker's own layout (the browser draws its picker; nothing in the web
// settings): rows of a time column shown, the gap between calendar and time
// columns, months per row of the year grid, the weekday row's height.
const _timeRows = 7;
const _sectionGap = 8.0;
const _monthColumns = 3;
const _weekdayRow = .75; // of a cell

/// The picker for [kind]: a month calendar (date; a week row per pick for
/// week; date and time columns side by side for datetime-local), a year of
/// months (month, or the calendar's header), or time columns (time).
///
/// [fields] is the field's current value; a pick is [onPick] with the new
/// parts and whether the picker is done (a day, week or month closes it;
/// the datetime calendar and time columns keep it open). [onClear] empties
/// the field, [onClose] asks to close (Enter in the time columns).
class KakaoDatePicker extends StatefulWidget {
  const KakaoDatePicker({
    super.key,
    required this.kind,
    required this.fields,
    required this.format,
    required this.style,
    required this.texts,
    required this.onPick,
    required this.onClear,
    required this.onClose,
    this.min,
    this.max,
    this.step = 1,
    this.seconds = false,
    this.dayPeriods = const ('AM', 'PM'),
    this.now = DateTime.now,
  });

  final KakaoDateKind kind;
  final KakaoDateFields fields;
  final KakaoDateFormat format;
  final KakaoPickerStyle style;
  final KakaoPickerTexts texts;
  final void Function(KakaoDateFields fields, {required bool done}) onPick;
  final VoidCallback onClear;
  final VoidCallback onClose;
  final String? min;
  final String? max;

  /// `step`: days, weeks or months for the calendar, seconds for time.
  final double step;
  final bool seconds;
  final (String, String) dayPeriods;
  final DateTime Function() now;

  @override
  State<KakaoDatePicker> createState() => _KakaoDatePickerState();
}

class _KakaoDatePickerState extends State<KakaoDatePicker> {
  late int _year;
  late int _month;

  /// The day the keyboard is on.
  late DateTime _active;
  late bool _months = widget.kind == KakaoDateKind.month;
  final _grid = FocusNode(debugLabel: 'KakaoDatePicker grid');
  final _firstColumn = FocusNode(debugLabel: 'KakaoDatePicker time');
  int? _hoverWeek;

  KakaoDateKind get _kind => widget.kind;
  bool get _hour12 => widget.format.hour12;

  @override
  void initState() {
    super.initState();
    final f = widget.fields;
    final now = widget.now();
    DateTime start;
    if (f.year != null && f.month != null && f.day != null && f.day! <= kakaoDaysInMonth(f.year!, f.month!)) {
      start = DateTime.utc(f.year!, f.month!, f.day!);
    } else if (_kind == KakaoDateKind.week && f.year != null && f.week != null) {
      start = kakaoIsoWeekMonday(f.year!, f.week!);
    } else if (_kind == KakaoDateKind.month && f.year != null && f.month != null) {
      start = DateTime.utc(f.year!, f.month!);
    } else {
      start = DateTime.utc(now.year, now.month, now.day);
      // An empty field opens on the allowed range.
      final lo = _minDate, hi = _maxDate;
      if (lo != null && start.isBefore(lo)) start = lo;
      if (hi != null && start.isAfter(hi)) start = hi;
    }
    _active = start;
    _year = start.year;
    _month = start.month;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      (_kind == KakaoDateKind.time ? _firstColumn : _grid).requestFocus();
    });
  }

  @override
  void dispose() {
    _grid.dispose();
    _firstColumn.dispose();
    super.dispose();
  }

  /// The first and last day min and max allow (date part only).
  DateTime? get _minDate => _bound(widget.min);
  DateTime? get _maxDate => _bound(widget.max, end: true);

  DateTime? _bound(String? v, {bool end = false}) {
    if (v == null || v.isEmpty) return null;
    switch (_kind) {
      case KakaoDateKind.date || KakaoDateKind.dateTimeLocal:
        final f = kakaoParseIso(KakaoDateKind.date, v.length >= 10 ? v.substring(0, 10) : v, hour12: false);
        return f.year == null ? null : DateTime.utc(f.year!, f.month!, f.day!);
      case KakaoDateKind.month:
        final f = kakaoParseIso(KakaoDateKind.month, v, hour12: false);
        if (f.year == null) return null;
        return end
            ? DateTime.utc(f.year!, f.month!, kakaoDaysInMonth(f.year!, f.month!))
            : DateTime.utc(f.year!, f.month!);
      case KakaoDateKind.week:
        final f = kakaoParseIso(KakaoDateKind.week, v, hour12: false);
        if (f.year == null) return null;
        final monday = kakaoIsoWeekMonday(f.year!, f.week!);
        return end ? monday.add(const Duration(days: 6)) : monday;
      case KakaoDateKind.time:
        return null;
    }
  }

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool _dayEnabled(DateTime d) {
    switch (_kind) {
      case KakaoDateKind.date:
        return kakaoInRange(KakaoDateKind.date, _iso(d), widget.min, widget.max) &&
            kakaoOnStep(
              KakaoDateKind.date,
              KakaoDateFields(year: d.year, month: d.month, day: d.day),
              widget.step,
              widget.min,
            );
      case KakaoDateKind.dateTimeLocal:
        final lo = _minDate, hi = _maxDate;
        return (lo == null || !d.isBefore(lo)) && (hi == null || !d.isAfter(hi));
      case KakaoDateKind.week:
        final (y, w) = kakaoIsoWeek(d);
        final f = KakaoDateFields(year: y, week: w);
        return kakaoInRange(
              KakaoDateKind.week,
              kakaoIsoValue(KakaoDateKind.week, f, hour12: false, seconds: false),
              widget.min,
              widget.max,
            ) &&
            kakaoOnStep(KakaoDateKind.week, f, widget.step, widget.min);
      case KakaoDateKind.month || KakaoDateKind.time:
        return true;
    }
  }

  bool _monthEnabled(int y, int m) {
    final iso = '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}';
    if (_kind == KakaoDateKind.month) {
      return kakaoInRange(KakaoDateKind.month, iso, widget.min, widget.max) &&
          kakaoOnStep(KakaoDateKind.month, KakaoDateFields(year: y, month: m), widget.step, widget.min);
    }
    // Navigation only: a month with an allowed day.
    final lo = _minDate, hi = _maxDate;
    final first = DateTime.utc(y, m), last = DateTime.utc(y, m, kakaoDaysInMonth(y, m));
    return (lo == null || !last.isBefore(lo)) && (hi == null || !first.isAfter(hi));
  }

  bool _isSelected(DateTime d) {
    final f = widget.fields;
    if (_kind == KakaoDateKind.week) {
      final (y, w) = kakaoIsoWeek(d);
      return f.year == y && f.week == w;
    }
    return f.year == d.year && f.month == d.month && f.day == d.day;
  }

  void _pickDay(DateTime d) {
    if (!_dayEnabled(d)) return;
    setState(() {
      _active = d;
      _year = d.year;
      _month = d.month;
    });
    switch (_kind) {
      case KakaoDateKind.week:
        final (y, w) = kakaoIsoWeek(d);
        widget.onPick(KakaoDateFields(year: y, week: w), done: true);
      case KakaoDateKind.dateTimeLocal:
        widget.onPick(widget.fields.withDate(d.year, d.month, d.day), done: false);
      default:
        widget.onPick(widget.fields.withDate(d.year, d.month, d.day), done: true);
    }
  }

  void _pickMonth(int y, int m) {
    if (!_monthEnabled(y, m)) return;
    if (_kind == KakaoDateKind.month) {
      setState(() {
        _year = y;
        _month = m;
      });
      widget.onPick(KakaoDateFields(year: y, month: m), done: true);
      return;
    }
    // From the calendar's header: back to that month's days.
    setState(() {
      _year = y;
      _month = m;
      _months = false;
      final d = math.min(_active.day, kakaoDaysInMonth(y, m));
      _active = DateTime.utc(y, m, d);
    });
    _grid.requestFocus();
  }

  void _today() {
    final n = widget.now();
    final d = DateTime.utc(n.year, n.month, n.day);
    if (_kind == KakaoDateKind.month) {
      _pickMonth(d.year, d.month);
    } else {
      _pickDay(d);
    }
  }

  bool get _todayEnabled {
    final n = widget.now();
    return _kind == KakaoDateKind.month
        ? _monthEnabled(n.year, n.month)
        : _dayEnabled(DateTime.utc(n.year, n.month, n.day));
  }

  void _moveActive(DateTime d) {
    setState(() {
      _active = d;
      if (_months) {
        _year = d.year;
      } else {
        _year = d.year;
        _month = d.month;
      }
    });
  }

  DateTime _addMonths(DateTime d, int n) {
    final total = d.year * 12 + d.month - 1 + n;
    final y = total ~/ 12, m = total % 12 + 1;
    return DateTime.utc(y, m, math.min(d.day, kakaoDaysInMonth(y, m)));
  }

  void _page(int months) {
    setState(() {
      if (_months) {
        _year += months ~/ 12 == 0 ? (months > 0 ? 1 : -1) : months ~/ 12;
        _active = DateTime.utc(_year, _active.month);
      } else {
        final first = _addMonths(DateTime.utc(_year, _month), months);
        _year = first.year;
        _month = first.month;
        _active = _addMonths(_active, months);
      }
    });
  }

  KeyEventResult _onGridKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final rtl = Directionality.maybeOf(context) == TextDirection.rtl;
    final a = _active;
    if (_months) {
      int? by;
      if (key == LogicalKeyboardKey.arrowLeft) by = rtl ? 1 : -1;
      if (key == LogicalKeyboardKey.arrowRight) by = rtl ? -1 : 1;
      if (key == LogicalKeyboardKey.arrowUp) by = -_monthColumns;
      if (key == LogicalKeyboardKey.arrowDown) by = _monthColumns;
      if (by != null) {
        _moveActive(_addMonths(DateTime.utc(a.year, a.month), by));
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.pageUp || key == LogicalKeyboardKey.pageDown) {
        _moveActive(_addMonths(DateTime.utc(a.year, a.month), key == LogicalKeyboardKey.pageUp ? -12 : 12));
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
        _pickMonth(a.year, a.month);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    int? days;
    if (key == LogicalKeyboardKey.arrowLeft) days = rtl ? 1 : -1;
    if (key == LogicalKeyboardKey.arrowRight) days = rtl ? -1 : 1;
    if (key == LogicalKeyboardKey.arrowUp) days = -7;
    if (key == LogicalKeyboardKey.arrowDown) days = 7;
    final first = widget.format.firstWeekday;
    if (key == LogicalKeyboardKey.home) days = -((a.weekday - first + 7) % 7);
    if (key == LogicalKeyboardKey.end) days = 6 - (a.weekday - first + 7) % 7;
    if (days != null) {
      _moveActive(DateTime.utc(a.year, a.month, a.day + days));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.pageUp || key == LogicalKeyboardKey.pageDown) {
      final n = (key == LogicalKeyboardKey.pageUp ? -1 : 1) * (shift ? 12 : 1);
      _moveActive(_addMonths(a, n));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
      _pickDay(a);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// A time column's pick: the other parts empty so far take their first
  /// value, so the field gets a whole time.
  void _pickTime(KakaoSegment s, int v, {bool done = false}) {
    var f = widget.fields.withPart(s, v);
    if (f.hour == null) f = f.withPart(KakaoSegment.hour, _hour12 ? 12 : 0);
    f = f.withPart(KakaoSegment.minute, f.minute ?? 0);
    if (widget.seconds) f = f.withPart(KakaoSegment.second, f.second ?? 0);
    if (_hour12 && f.pm == null) f = f.withPart(KakaoSegment.dayPeriod, 0);
    widget.onPick(f, done: done);
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.style;
    final hasCalendar = _kind != KakaoDateKind.time;
    final calendar = hasCalendar ? _calendar(st) : null;
    final time = _kind.hasTime ? _timeColumns(st, hasCalendar) : null;
    final body = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ?calendar,
        if (calendar != null && time != null) const SizedBox(width: _sectionGap),
        ?time,
      ],
    );
    return FocusScope(
      child: Container(
        padding: EdgeInsets.all(st.padding * 2),
        decoration: BoxDecoration(
          color: st.background,
          borderRadius: BorderRadius.circular(st.radius),
          boxShadow: st.shadow,
        ),
        child: DefaultTextStyle(style: st.text, child: body),
      ),
    );
  }

  /* ---- calendar --------------------------------------------------------- */

  Widget _calendar(KakaoPickerStyle st) {
    final t = widget.texts;
    final week = _kind == KakaoDateKind.week;
    final width = st.cell * (week ? 8 : 7);
    final months = widget.format.monthNames ?? t.months;
    final header = Row(
      children: [
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            // The month kind is a year of months: its year is a heading; the
            // others switch to that view and back.
            child: _kind == KakaoDateKind.month
                ? Padding(
                    padding: EdgeInsets.symmetric(horizontal: st.padding * 2),
                    child: Text('$_year', style: st.heading),
                  )
                : _PickerButton(
                    style: st,
                    label: _months ? '$_year' : '${months[_month - 1]} $_year',
                    semanticLabel: t.chooseMonth,
                    onTap: () => setState(() {
                      _months = !_months;
                      _active = _months ? DateTime.utc(_year, _month) : DateTime.utc(_year, _month, 1);
                      _grid.requestFocus();
                    }),
                    chevron: _months,
                  ),
          ),
        ),
        _PickerButton(style: st, semanticLabel: t.previous, arrow: -1, onTap: () => _page(_months ? -12 : -1)),
        _PickerButton(style: st, semanticLabel: t.next, arrow: 1, onTap: () => _page(_months ? 12 : 1)),
      ],
    );
    final grid = Focus(
      focusNode: _grid,
      onKeyEvent: _onGridKey,
      onFocusChange: (_) => setState(() {}),
      child: _months ? _monthGrid(st, width) : _dayGrid(st, week),
    );
    final footer = Wrap(
      alignment: WrapAlignment.spaceBetween,
      children: [
        _PickerButton(style: st, label: t.clear, onTap: widget.onClear),
        _PickerButton(style: st, label: t.today, onTap: _todayEnabled ? _today : null),
      ],
    );
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          SizedBox(height: st.padding),
          grid,
          SizedBox(height: st.padding),
          footer,
        ],
      ),
    );
  }

  /// Header, gap, weekday row, six weeks, gap, footer.
  double _calendarHeight(KakaoPickerStyle st) => st.cell * (8 + _weekdayRow) + 2 * st.padding;

  bool get _keyboardFocus => _grid.hasFocus && FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

  Widget _dayGrid(KakaoPickerStyle st, bool week) {
    final t = widget.texts;
    final first = widget.format.firstWeekday;
    final start = DateTime.utc(_year, _month, 1);
    final lead = (start.weekday - first + 7) % 7;
    final gridStart = DateTime.utc(_year, _month, 1 - lead);
    final now = widget.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    Widget head(String s) => SizedBox(
      width: st.cell,
      height: st.cell * _weekdayRow,
      child: Center(
        child: Text(s, style: st.small.copyWith(color: st.muted)),
      ),
    );
    final rows = <Widget>[
      ExcludeSemantics(
        child: Row(
          children: [if (week) head(t.week), for (var i = 0; i < 7; i++) head(t.weekdays[(first - 1 + i) % 7])],
        ),
      ),
    ];
    for (var r = 0; r < 6; r++) {
      final rowStart = DateTime.utc(gridStart.year, gridStart.month, gridStart.day + r * 7);
      final (wy, wn) = kakaoIsoWeek(
        DateTime.utc(rowStart.year, rowStart.month, rowStart.day + (8 - rowStart.weekday) % 7),
      );
      final weekKey = wy * 100 + wn;
      final rowSelected = week && widget.fields.year == wy && widget.fields.week == wn;
      final cells = <Widget>[
        if (week)
          SizedBox(
            width: st.cell,
            height: st.cell,
            child: Center(
              child: ExcludeSemantics(
                child: Text('$wn', style: st.small.copyWith(color: st.muted)),
              ),
            ),
          ),
      ];
      for (var c = 0; c < 7; c++) {
        final d = DateTime.utc(rowStart.year, rowStart.month, rowStart.day + c);
        cells.add(
          _DayCell(
            style: st,
            day: d,
            outside: d.month != _month,
            enabled: _dayEnabled(d),
            selected: week ? rowSelected : _isSelected(d),
            today: d == today,
            active: _keyboardFocus && d == _active,
            hoverRow: week && _hoverWeek == weekKey,
            onHover: week ? (h) => setState(() => _hoverWeek = h ? weekKey : null) : null,
            onTap: () => _pickDay(d),
          ),
        );
      }
      rows.add(Row(children: cells));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }

  Widget _monthGrid(KakaoPickerStyle st, double width) {
    final names = widget.texts.monthsShort;
    final f = widget.fields;
    // From a calendar's header: as tall as the days it stands for.
    final height = _kind == KakaoDateKind.month ? st.cell : st.cell * (6 + _weekdayRow) / (12 ~/ _monthColumns);
    final rows = <Widget>[];
    for (var r = 0; r < 12 ~/ _monthColumns; r++) {
      rows.add(
        Row(
          children: [
            for (var c = 0; c < _monthColumns; c++)
              () {
                final m = r * _monthColumns + c + 1;
                final selected = _kind == KakaoDateKind.month
                    ? f.year == _year && f.month == m
                    : _year == _active.year && m == _month;
                return _Cell(
                  style: st,
                  width: width / _monthColumns,
                  height: height,
                  label: names[m - 1],
                  semanticLabel: '${(widget.format.monthNames ?? widget.texts.months)[m - 1]} $_year',
                  enabled: _monthEnabled(_year, m),
                  selected: selected,
                  active: _keyboardFocus && _active.year == _year && _active.month == m,
                  onTap: () => _pickMonth(_year, m),
                );
              }(),
          ],
        ),
      );
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }

  /* ---- time ------------------------------------------------------------- */

  Widget _timeColumns(KakaoPickerStyle st, bool beside) {
    final f = widget.fields;
    final t = widget.texts;
    // Beside the calendar: as tall as it; alone: seven rows.
    final height = beside ? null : st.cell * _timeRows;
    final hourStep = kakaoPartStep(KakaoSegment.hour, widget.step);
    final minuteStep = kakaoPartStep(KakaoSegment.minute, widget.step);
    final secondStep = kakaoPartStep(KakaoSegment.second, widget.step);
    final hours = _hour12 ? [for (var h = 1; h <= 12; h++) h] : [for (var h = 0; h < 24; h += hourStep) h];
    final columns = <Widget>[
      _TimeColumn(
        style: st,
        focusNode: _firstColumn,
        semanticLabel: t.hours,
        values: hours,
        selected: f.hour,
        label: (v) => v.toString().padLeft(2, '0'),
        onPick: (v) => _pickTime(KakaoSegment.hour, v),
        onDone: widget.onClose,
      ),
      _TimeColumn(
        style: st,
        semanticLabel: t.minutes,
        values: [for (var m = 0; m < 60; m += minuteStep) m],
        selected: f.minute,
        label: (v) => v.toString().padLeft(2, '0'),
        onPick: (v) => _pickTime(KakaoSegment.minute, v),
        onDone: widget.onClose,
      ),
      if (widget.seconds)
        _TimeColumn(
          style: st,
          semanticLabel: t.seconds,
          values: [for (var s = 0; s < 60; s += secondStep) s],
          selected: f.second,
          label: (v) => v.toString().padLeft(2, '0'),
          onPick: (v) => _pickTime(KakaoSegment.second, v),
          onDone: widget.onClose,
        ),
      if (_hour12)
        _TimeColumn(
          style: st,
          semanticLabel: t.dayPeriod,
          values: const [0, 1],
          selected: f.pm == null ? null : (f.pm! ? 1 : 0),
          label: (v) => v == 1 ? widget.dayPeriods.$2 : widget.dayPeriods.$1,
          onPick: (v) => _pickTime(KakaoSegment.dayPeriod, v),
          onDone: widget.onClose,
        ),
    ];
    final row = Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: columns);
    return SizedBox(height: height ?? _calendarHeight(st), child: row);
  }
}

/// A day of the calendar (or a week's day, when the row is the pick).
class _DayCell extends StatefulWidget {
  const _DayCell({
    required this.style,
    required this.day,
    required this.outside,
    required this.enabled,
    required this.selected,
    required this.today,
    required this.active,
    required this.hoverRow,
    required this.onHover,
    required this.onTap,
  });

  final KakaoPickerStyle style;
  final DateTime day;
  final bool outside;
  final bool enabled;
  final bool selected;
  final bool today;
  final bool active;
  final bool hoverRow;
  final ValueChanged<bool>? onHover;
  final VoidCallback onTap;

  @override
  State<_DayCell> createState() => _DayCellState();
}

class _DayCellState extends State<_DayCell> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final st = widget.style;
    final hover = widget.onHover != null ? widget.hoverRow : _hover;
    final fill = widget.selected
        ? st.selected
        : hover && widget.enabled
        ? st.hover
        : null;
    final color = widget.selected
        ? st.onSelected
        : widget.outside || !widget.enabled
        ? st.muted
        : st.textColor;
    final border = widget.active
        ? Border.all(color: st.focus, width: st.focusWidth)
        : widget.today && !widget.selected
        ? Border.all(color: st.focus)
        : null;
    Widget cell = Container(
      width: st.cell,
      height: st.cell,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: fill, border: border, borderRadius: BorderRadius.circular(st.cellRadius)),
      child: Text('${widget.day.day}', style: st.text.copyWith(color: color)),
    );
    if (!widget.enabled) cell = Opacity(opacity: st.disabledOpacity, child: cell);
    return Semantics(
      button: true,
      enabled: widget.enabled,
      selected: widget.selected,
      label:
          '${widget.day.year}-${widget.day.month.toString().padLeft(2, '0')}-${widget.day.day.toString().padLeft(2, '0')}',
      onTap: widget.enabled ? widget.onTap : null,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) {
          setState(() => _hover = true);
          widget.onHover?.call(true);
        },
        onExit: (_) {
          setState(() => _hover = false);
          widget.onHover?.call(false);
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? widget.onTap : null,
          child: cell,
        ),
      ),
    );
  }
}

/// A month in the year grid.
class _Cell extends StatefulWidget {
  const _Cell({
    required this.style,
    required this.width,
    required this.height,
    required this.label,
    required this.semanticLabel,
    required this.enabled,
    required this.selected,
    required this.active,
    required this.onTap,
  });

  final KakaoPickerStyle style;
  final double width;
  final double height;
  final String label;
  final String semanticLabel;
  final bool enabled;
  final bool selected;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_Cell> createState() => _CellState();
}

class _CellState extends State<_Cell> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final st = widget.style;
    Widget cell = Container(
      width: widget.width,
      height: widget.height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: widget.selected
            ? st.selected
            : _hover && widget.enabled
            ? st.hover
            : null,
        border: widget.active ? Border.all(color: st.focus, width: st.focusWidth) : null,
        borderRadius: BorderRadius.circular(st.cellRadius),
      ),
      child: Text(widget.label, style: st.text.copyWith(color: widget.selected ? st.onSelected : st.textColor)),
    );
    if (!widget.enabled) cell = Opacity(opacity: st.disabledOpacity, child: cell);
    return Semantics(
      button: true,
      enabled: widget.enabled,
      selected: widget.selected,
      label: widget.semanticLabel,
      onTap: widget.enabled ? widget.onTap : null,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? widget.onTap : null,
          child: cell,
        ),
      ),
    );
  }
}

/// A column of hours, minutes, seconds or AM / PM: the selected row filled,
/// scrolled to the middle on open; Up / Down pick the next row, Enter is
/// done.
class _TimeColumn extends StatefulWidget {
  const _TimeColumn({
    required this.style,
    required this.semanticLabel,
    required this.values,
    required this.selected,
    required this.label,
    required this.onPick,
    required this.onDone,
    this.focusNode,
  });

  final KakaoPickerStyle style;
  final String semanticLabel;
  final List<int> values;
  final int? selected;
  final String Function(int) label;
  final ValueChanged<int> onPick;
  final VoidCallback onDone;
  final FocusNode? focusNode;

  @override
  State<_TimeColumn> createState() => _TimeColumnState();
}

class _TimeColumnState extends State<_TimeColumn> {
  FocusNode? _own;
  FocusNode get _focus => widget.focusNode ?? (_own ??= FocusNode(debugLabel: 'KakaoDatePicker column'));
  ScrollController? _scroll;
  int? _hover;

  @override
  void dispose() {
    _own?.dispose();
    _scroll?.dispose();
    super.dispose();
  }

  void _reveal(int index, double viewport) {
    final c = _scroll;
    if (c == null || !c.hasClients) return;
    final cell = widget.style.cell;
    final top = index * cell, bottom = top + cell;
    final at = c.offset;
    if (top < at) {
      c.jumpTo(top);
    } else if (bottom > at + viewport) {
      c.jumpTo(bottom - viewport);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event, double viewport) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final values = widget.values;
    final rtl = Directionality.maybeOf(context) == TextDirection.rtl;
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowDown) {
      final i = widget.selected == null ? -1 : values.indexOf(widget.selected!);
      final up = key == LogicalKeyboardKey.arrowUp;
      final next = i < 0 ? (up ? values.length - 1 : 0) : (i + (up ? -1 : 1) + values.length) % values.length;
      widget.onPick(values[next]);
      _reveal(next, viewport);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight) {
      final forward = (key == LogicalKeyboardKey.arrowRight) != rtl;
      if (forward) {
        node.nextFocus();
      } else {
        node.previousFocus();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
      widget.onDone();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.style;
    final values = widget.values;
    final width = st.cell + 2 * st.padding;
    return LayoutBuilder(
      builder: (context, c) {
        final viewport = c.maxHeight.isFinite ? c.maxHeight : st.cell * _timeRows;
        final sel = widget.selected == null ? -1 : values.indexOf(widget.selected!);
        _scroll ??= ScrollController(
          initialScrollOffset: sel < 0
              ? 0
              : (sel * st.cell - (viewport - st.cell) / 2).clamp(
                  0.0,
                  math.max(0.0, values.length * st.cell - viewport),
                ),
        );
        final keyboard = _focus.hasFocus && FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
        return Semantics(
          label: widget.semanticLabel,
          container: true,
          child: Focus(
            focusNode: _focus,
            onKeyEvent: (n, e) => _onKey(n, e, viewport),
            onFocusChange: (_) => setState(() {}),
            child: SizedBox(
              width: width,
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                child: ListView.builder(
                  controller: _scroll,
                  itemExtent: st.cell,
                  itemCount: values.length,
                  padding: EdgeInsets.zero,
                  itemBuilder: (context, i) {
                    final v = values[i];
                    final selected = i == sel;
                    return Semantics(
                      button: true,
                      selected: selected,
                      label: widget.label(v),
                      onTap: () => widget.onPick(v),
                      excludeSemantics: true,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        onEnter: (_) => setState(() => _hover = i),
                        onExit: (_) => setState(() => _hover = null),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            _focus.requestFocus();
                            widget.onPick(v);
                          },
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: st.padding),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: selected
                                    ? st.selected
                                    : _hover == i
                                    ? st.hover
                                    : null,
                                border: keyboard && selected ? Border.all(color: st.focus, width: st.focusWidth) : null,
                                borderRadius: BorderRadius.circular(st.cellRadius),
                              ),
                              child: Text(
                                widget.label(v),
                                style: st.text.copyWith(color: selected ? st.onSelected : st.textColor),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A button of the picker: the month and year (with a chevron that turns
/// while the year of months shows), the previous / next arrows, Clear and
/// Today. Focusable; Enter and Space press it; null [onTap]: disabled.
class _PickerButton extends StatefulWidget {
  const _PickerButton({required this.style, this.label, this.semanticLabel, this.arrow, this.chevron, this.onTap});

  final KakaoPickerStyle style;
  final String? label;
  final String? semanticLabel;

  /// -1: previous, 1: next (a chevron pointing that way).
  final int? arrow;

  /// Not null: a chevron after the label, up when true.
  final bool? chevron;
  final VoidCallback? onTap;

  @override
  State<_PickerButton> createState() => _PickerButtonState();
}

class _PickerButtonState extends State<_PickerButton> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final st = widget.style;
    final enabled = widget.onTap != null;
    final label = widget.label;
    final glyph = st.text.fontSize! * .9; // the select's chevron, 0.9em
    Widget content;
    if (widget.arrow case final a?) {
      final rtl = Directionality.maybeOf(context) == TextDirection.rtl;
      content = RotatedBox(
        quarterTurns: (a < 0) != rtl ? 1 : 3,
        child: CustomPaint(size: Size.square(glyph), painter: KakaoChevronPainter(st.muted)),
      );
    } else {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label ?? '',
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: widget.chevron != null ? st.heading : st.text,
            ),
          ),
          if (widget.chevron case final up?) ...[
            SizedBox(width: st.padding),
            RotatedBox(
              quarterTurns: up ? 2 : 0,
              child: CustomPaint(size: Size.square(glyph), painter: KakaoChevronPainter(st.muted)),
            ),
          ],
        ],
      );
    }
    Widget box = Container(
      height: st.cell,
      constraints: BoxConstraints(minWidth: st.cell),
      padding: widget.arrow == null ? EdgeInsets.symmetric(horizontal: st.padding * 2) : null,
      decoration: BoxDecoration(
        color: _hover && enabled ? st.hover : null,
        border: _focus ? Border.all(color: st.focus, width: st.focusWidth) : null,
        borderRadius: BorderRadius.circular(st.cellRadius),
      ),
      // As wide as its content.
      child: Center(widthFactor: 1, child: content),
    );
    if (!enabled) box = Opacity(opacity: st.disabledOpacity, child: box);
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel ?? label,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: FocusableActionDetector(
        enabled: enabled,
        mouseCursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onShowHoverHighlight: (v) => setState(() => _hover = v),
        onShowFocusHighlight: (v) => setState(() => _focus = v),
        actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onTap?.call())},
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onTap, child: box),
      ),
    );
  }
}
