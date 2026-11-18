// Date and time values for the date and time fields (date-input, time-input):
// the ISO forms of the native <input> types, ISO weeks, the browser's field
// formats per locale, and the "today" shortcut's rules. No widgets; shared by
// the segment field and the picker.
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The native `<input type>` a date field stands for.
enum KakaoDateKind {
  date,
  time,
  dateTimeLocal,
  month,
  week;

  bool get hasDate => this == date || this == dateTimeLocal;
  bool get hasTime => this == time || this == dateTimeLocal;
}

/// A part of a date field (Chromium's `-webkit-datetime-edit-*-field`).
enum KakaoSegment { year, month, monthName, day, week, hour, minute, second, dayPeriod }

/// What a date field holds, part by part; null: that part is empty. [hour]
/// is 1-12 with [pm] on a 12-hour field, else 0-23.
@immutable
class KakaoDateFields {
  const KakaoDateFields({this.year, this.month, this.day, this.week, this.hour, this.minute, this.second, this.pm});

  static const empty = KakaoDateFields();

  final int? year;
  final int? month;
  final int? day;
  final int? week;
  final int? hour;
  final int? minute;
  final int? second;
  final bool? pm;

  int? operator [](KakaoSegment s) => switch (s) {
    KakaoSegment.year => year,
    KakaoSegment.month || KakaoSegment.monthName => month,
    KakaoSegment.day => day,
    KakaoSegment.week => week,
    KakaoSegment.hour => hour,
    KakaoSegment.minute => minute,
    KakaoSegment.second => second,
    KakaoSegment.dayPeriod => pm == null ? null : (pm! ? 1 : 0),
  };

  /// [s] set to [v] (null: emptied).
  KakaoDateFields withPart(KakaoSegment s, int? v) => KakaoDateFields(
    year: s == KakaoSegment.year ? v : year,
    month: s == KakaoSegment.month || s == KakaoSegment.monthName ? v : month,
    day: s == KakaoSegment.day ? v : day,
    week: s == KakaoSegment.week ? v : week,
    hour: s == KakaoSegment.hour ? v : hour,
    minute: s == KakaoSegment.minute ? v : minute,
    second: s == KakaoSegment.second ? v : second,
    pm: s == KakaoSegment.dayPeriod ? (v == null ? null : v == 1) : pm,
  );

  /// These fields with the date [y]-[m]-[d].
  KakaoDateFields withDate(int y, int m, int d) =>
      KakaoDateFields(year: y, month: m, day: d, week: week, hour: hour, minute: minute, second: second, pm: pm);

  /// These fields with the time of day [h]:[mi]:[s] (24 hours), written for
  /// a 12-hour field when [hour12].
  KakaoDateFields withTime(int h, int mi, int? s, {required bool hour12}) => KakaoDateFields(
    year: year,
    month: month,
    day: day,
    week: week,
    hour: hour12 ? (h % 12 == 0 ? 12 : h % 12) : h,
    minute: mi,
    second: s,
    pm: hour12 ? h >= 12 : null,
  );

  /// The hour on a 24-hour clock, or null.
  int? hour24({required bool hour12}) {
    final h = hour;
    if (h == null) return null;
    if (!hour12) return h;
    final p = pm;
    if (p == null) return null;
    return h % 12 + (p ? 12 : 0);
  }

  @override
  bool operator ==(Object other) =>
      other is KakaoDateFields &&
      other.year == year &&
      other.month == month &&
      other.day == day &&
      other.week == week &&
      other.hour == hour &&
      other.minute == minute &&
      other.second == second &&
      other.pm == pm;

  @override
  int get hashCode => Object.hash(year, month, day, week, hour, minute, second, pm);

  @override
  String toString() => 'KakaoDateFields($year-$month-$day w$week $hour:$minute:$second pm=$pm)';
}

String _pad(int n, [int w = 2]) => n.toString().padLeft(w, '0');

/// The largest year a native date field takes.
const kakaoMaxYear = 275760;

bool kakaoLeapYear(int y) => (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;

int kakaoDaysInMonth(int y, int m) => switch (m) {
  2 => kakaoLeapYear(y) ? 29 : 28,
  4 || 6 || 9 || 11 => 30,
  _ => 31,
};

/// ISO 8601 weeks in [y]: 53 when the year starts on a Thursday, or on a
/// Wednesday in a leap year.
int kakaoWeeksInYear(int y) {
  final jan1 = DateTime.utc(y).weekday;
  return jan1 == DateTime.thursday || (jan1 == DateTime.wednesday && kakaoLeapYear(y)) ? 53 : 52;
}

/// The ISO week of a day: the week belongs to the year its Thursday falls in.
(int year, int week) kakaoIsoWeek(DateTime day) {
  final d = DateTime.utc(day.year, day.month, day.day);
  final thursday = d.add(Duration(days: DateTime.thursday - d.weekday));
  final year = thursday.year;
  final week = ((thursday.difference(DateTime.utc(year)).inDays) ~/ 7) + 1;
  return (year, week);
}

/// The Monday of ISO week [week] of [year].
DateTime kakaoIsoWeekMonday(int year, int week) {
  final jan4 = DateTime.utc(year, 1, 4);
  return jan4.subtract(Duration(days: jan4.weekday - 1)).add(Duration(days: 7 * (week - 1)));
}

/// What the browser takes for `step` (date-input.js: seconds for times, days
/// for dates, weeks, months): the default when missing or not above 0.
double kakaoStep(KakaoDateKind kind, num? step) {
  final s = step?.toDouble();
  if (s != null && s > 0) return s;
  return kind.hasTime ? 60 : 1;
}

/// Whether a time field shows seconds: a step that is not whole minutes,
/// or a value with seconds.
bool kakaoShowsSeconds(num? step, String value) {
  final s = step?.toDouble();
  if (s != null && s > 0 && s % 60 != 0) return true;
  final m = RegExp(r'\d{2}:\d{2}:(\d{2})').firstMatch(value);
  return m != null && m.group(1) != '00';
}

/// The ISO value of [f] for [kind] ('' when a part is missing or the date
/// does not exist, as the native input's `value`).
String kakaoIsoValue(KakaoDateKind kind, KakaoDateFields f, {required bool hour12, required bool seconds}) {
  String? date() {
    final y = f.year, m = f.month, d = f.day;
    if (y == null || m == null || d == null) return null;
    if (y < 1 || y > kakaoMaxYear || m < 1 || m > 12 || d < 1 || d > kakaoDaysInMonth(y, m)) return null;
    return '${_pad(y, 4)}-${_pad(m)}-${_pad(d)}';
  }

  String? time() {
    final h = f.hour24(hour12: hour12), mi = f.minute;
    if (h == null || mi == null) return null;
    final hm = '${_pad(h)}:${_pad(mi)}';
    if (!seconds) return hm;
    final s = f.second;
    return s == null ? null : '$hm:${_pad(s)}';
  }

  switch (kind) {
    case KakaoDateKind.date:
      return date() ?? '';
    case KakaoDateKind.time:
      return time() ?? '';
    case KakaoDateKind.dateTimeLocal:
      final d = date(), t = time();
      return d == null || t == null ? '' : '${d}T$t';
    case KakaoDateKind.month:
      final y = f.year, m = f.month;
      if (y == null || m == null || y < 1 || y > kakaoMaxYear) return '';
      return '${_pad(y, 4)}-${_pad(m)}';
    case KakaoDateKind.week:
      final y = f.year, w = f.week;
      if (y == null || w == null || y < 1 || y > kakaoMaxYear || w > kakaoWeeksInYear(y)) return '';
      return '${_pad(y, 4)}-W${_pad(w)}';
  }
}

final _dateRe = RegExp(r'^(\d{4,6})-(\d{2})-(\d{2})');
final _timeRe = RegExp(r'(\d{2}):(\d{2})(?::(\d{2})(?:\.\d{1,3})?)?$');

/// The parts of an ISO [value] of [kind]; empty fields when it does not parse.
KakaoDateFields kakaoParseIso(KakaoDateKind kind, String value, {required bool hour12}) {
  final v = value.trim();
  KakaoDateFields time(KakaoDateFields f, String t) {
    final m = _timeRe.firstMatch(t);
    if (m == null) return KakaoDateFields.empty;
    final h = int.parse(m.group(1)!), mi = int.parse(m.group(2)!), s = int.parse(m.group(3) ?? '0');
    if (h > 23 || mi > 59 || s > 59) return KakaoDateFields.empty;
    return f.withTime(h, mi, s, hour12: hour12);
  }

  switch (kind) {
    case KakaoDateKind.date:
      final m = _dateRe.firstMatch(v);
      if (m == null || v.length != m.group(0)!.length) return KakaoDateFields.empty;
      final y = int.parse(m.group(1)!), mo = int.parse(m.group(2)!), d = int.parse(m.group(3)!);
      if (mo < 1 || mo > 12 || d < 1 || d > kakaoDaysInMonth(y, mo)) return KakaoDateFields.empty;
      return KakaoDateFields(year: y, month: mo, day: d);
    case KakaoDateKind.time:
      if (!RegExp(r'^\d{2}:\d{2}').hasMatch(v)) return KakaoDateFields.empty;
      return time(KakaoDateFields.empty, v);
    case KakaoDateKind.dateTimeLocal:
      final parts = v.split(RegExp('[T ]'));
      if (parts.length != 2) return KakaoDateFields.empty;
      final date = kakaoParseIso(KakaoDateKind.date, parts[0], hour12: hour12);
      if (date.year == null) return KakaoDateFields.empty;
      final t = time(date, parts[1]);
      return t.hour == null ? KakaoDateFields.empty : t;
    case KakaoDateKind.month:
      final m = RegExp(r'^(\d{4,6})-(\d{2})$').firstMatch(v);
      if (m == null) return KakaoDateFields.empty;
      final mo = int.parse(m.group(2)!);
      if (mo < 1 || mo > 12) return KakaoDateFields.empty;
      return KakaoDateFields(year: int.parse(m.group(1)!), month: mo);
    case KakaoDateKind.week:
      final m = RegExp(r'^(\d{4,6})-W(\d{2})$').firstMatch(v);
      if (m == null) return KakaoDateFields.empty;
      final y = int.parse(m.group(1)!), w = int.parse(m.group(2)!);
      if (w < 1 || w > kakaoWeeksInYear(y)) return KakaoDateFields.empty;
      return KakaoDateFields(year: y, week: w);
  }
}

/// [value] with a time of 'HH:MM' or a date-time of '…THH:MM' given seconds,
/// so ISO strings of one kind compare in order (date-input.js `inRange`'s
/// `norm`).
String _norm(KakaoDateKind kind, String v) {
  if (kind == KakaoDateKind.time && v.length == 5) return '$v:00';
  if (kind == KakaoDateKind.dateTimeLocal && v.length == 16) return '$v:00';
  return v;
}

/// date-input.js `inRange`: whether an ISO value lies within [min] and
/// [max] ('' or null: open). A time range may run over midnight (min after max).
bool kakaoInRange(KakaoDateKind kind, String v, String? min, String? max) {
  final val = _norm(kind, v);
  final lo = min == null || min.isEmpty ? null : _norm(kind, min);
  final hi = max == null || max.isEmpty ? null : _norm(kind, max);
  if (kind == KakaoDateKind.time && lo != null && hi != null && lo.compareTo(hi) > 0) {
    return val.compareTo(lo) >= 0 || val.compareTo(hi) <= 0;
  }
  return (lo == null || val.compareTo(lo) >= 0) && (hi == null || val.compareTo(hi) <= 0);
}

/// time-input.js `timeSeconds`: seconds since midnight of an ISO time (or
/// of a date-time's time), or null.
int? kakaoTimeSeconds(String? v) {
  if (v == null) return null;
  final t = v.contains('T') ? v.substring(v.indexOf('T') + 1) : v;
  final m = RegExp(r'^(\d{2}):(\d{2})(?::(\d{2}))?').firstMatch(t);
  if (m == null) return null;
  return int.parse(m.group(1)!) * 3600 + int.parse(m.group(2)!) * 60 + int.parse(m.group(3) ?? '0');
}

double _snap(double n, double base, double step, double Function(double) mode) => base + mode((n - base) / step) * step;

/// date-input.js `todayValues`: the value for "now" in [kind] (today, the
/// current month, the ISO week, or the time snapped to [step] counted from
/// [min]); candidates, nearest first, for the range check to choose from.
List<String> kakaoTodayValues(KakaoDateKind kind, num? step, String? min, DateTime now) {
  final y = now.year, mo = now.month, d = now.day;
  switch (kind) {
    case KakaoDateKind.date:
      return ['${_pad(y, 4)}-${_pad(mo)}-${_pad(d)}'];
    case KakaoDateKind.month:
      return ['${_pad(y, 4)}-${_pad(mo)}'];
    case KakaoDateKind.week:
      final (wy, w) = kakaoIsoWeek(now);
      return ['${_pad(wy, 4)}-W${_pad(w)}'];
    case KakaoDateKind.time || KakaoDateKind.dateTimeLocal:
      break;
  }
  var stepSec = step?.toDouble() ?? double.nan;
  if (!(stepSec >= 1)) stepSec = 60;
  stepSec = stepSec.roundToDouble();
  final modes = <double Function(double)>[
    (x) => (x + .5).floorToDouble(), // Math.round
    (x) => x.floorToDouble(),
    (x) => x.ceilToDouble(),
  ];
  if (kind == KakaoDateKind.time) {
    final t = kakaoParseIso(KakaoDateKind.time, min ?? '', hour12: false);
    final base = t.hour == null ? 0.0 : (t.hour! * 3600 + t.minute! * 60 + (t.second ?? 0)).toDouble();
    final secs = (now.hour * 3600 + now.minute * 60 + now.second).toDouble();
    final withSeconds = stepSec % 60 != 0 || base % 60 != 0;
    return [
      for (final mode in modes)
        () {
          final t = ((_snap(secs, base, stepSec, mode) % 86400) + 86400) % 86400;
          final hm = '${_pad(t ~/ 3600)}:${_pad((t ~/ 60) % 60)}';
          return withSeconds ? '$hm:${_pad((t % 60).toInt())}' : hm;
        }(),
    ];
  }
  final m = kakaoParseIso(KakaoDateKind.dateTimeLocal, min ?? '', hour12: false);
  final base = m.year == null
      ? 0.0
      : DateTime.utc(m.year!, m.month!, m.day!, m.hour!, m.minute!, m.second ?? 0).millisecondsSinceEpoch.toDouble();
  final ms = DateTime.utc(y, mo, d, now.hour, now.minute, now.second).millisecondsSinceEpoch.toDouble();
  final withSeconds = stepSec % 60 != 0 || (base / 1000) % 60 != 0;
  return [
    for (final mode in modes)
      () {
        final t = DateTime.fromMillisecondsSinceEpoch(_snap(ms, base, stepSec * 1000, mode).toInt(), isUtc: true);
        final v = '${_pad(t.year, 4)}-${_pad(t.month)}-${_pad(t.day)}T${_pad(t.hour)}:${_pad(t.minute)}';
        return withSeconds ? '$v:${_pad(t.second)}' : v;
      }(),
  ];
}

/// The order of day, month and year in a date field.
enum KakaoDateOrder { mdy, dmy, ymd }

/// How the browser writes a date field in a locale (Chromium draws it in
/// the browser's language): part order, separators, 12 or 24 hours, the
/// empty parts' placeholders, the first day of the week, month names.
@immutable
class KakaoDateFormat {
  const KakaoDateFormat({
    required this.order,
    required this.separator,
    required this.hour12,
    this.yearPlaceholder = 'yyyy',
    this.monthPlaceholder = 'mm',
    this.dayPlaceholder = 'dd',
    this.firstWeekday = DateTime.monday,
    this.monthNames,
    this.weekLabel = 'Week',
  });

  final KakaoDateOrder order;
  final String separator;
  final bool hour12;
  final String yearPlaceholder;
  final String monthPlaceholder;
  final String dayPlaceholder;

  /// [DateTime.monday] … [DateTime.sunday].
  final int firstWeekday;

  /// Twelve names: a month field writes "March 2026"; null: numbers.
  final List<String>? monthNames;

  /// "Week 10, 2026".
  final String weekLabel;

  static const englishMonths = [
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
  ];

  /// en-US, Chromium's field in a US English browser: 03/04/2026, 02:30 PM,
  /// March 2026, Week 10, 2026; weeks start on Sunday.
  static const enUS = KakaoDateFormat(
    order: KakaoDateOrder.mdy,
    separator: '/',
    hour12: true,
    firstWeekday: DateTime.sunday,
    monthNames: englishMonths,
  );

  /// The format for [locale], from a small built-in table (English,
  /// German, French, Spanish, Italian, Portuguese, Dutch, the Nordic and
  /// Slavic languages, Japanese, Chinese, Korean); other languages get
  /// ISO order (2026-03-04, 24 hours).
  static KakaoDateFormat forLocale(Locale? locale) {
    if (locale == null) return enUS;
    final lang = locale.languageCode.toLowerCase();
    final region = locale.countryCode?.toUpperCase();
    switch (lang) {
      case 'en':
        if (region == null || const {'US', 'PH', 'PR', 'UM', 'VI', 'AS', 'GU', 'MP'}.contains(region)) return enUS;
        if (region == 'CA') {
          return const KakaoDateFormat(
            order: KakaoDateOrder.ymd,
            separator: '-',
            hour12: true,
            firstWeekday: DateTime.sunday,
            monthNames: englishMonths,
          );
        }
        return KakaoDateFormat(
          order: KakaoDateOrder.dmy,
          separator: '/',
          hour12: const {'AU', 'NZ', 'IN'}.contains(region),
          monthNames: englishMonths,
        );
      case 'de':
        return const KakaoDateFormat(
          order: KakaoDateOrder.dmy,
          separator: '.',
          hour12: false,
          yearPlaceholder: 'jjjj',
          dayPlaceholder: 'tt',
          weekLabel: 'Woche',
        );
      case 'fr':
        return const KakaoDateFormat(
          order: KakaoDateOrder.dmy,
          separator: '/',
          hour12: false,
          yearPlaceholder: 'aaaa',
          dayPlaceholder: 'jj',
          weekLabel: 'Semaine',
        );
      case 'es' || 'it' || 'pt':
        return KakaoDateFormat(
          order: KakaoDateOrder.dmy,
          separator: '/',
          hour12: false,
          yearPlaceholder: 'aaaa',
          dayPlaceholder: lang == 'it' ? 'gg' : 'dd',
          weekLabel: 'Semana',
        );
      case 'nl':
        return const KakaoDateFormat(order: KakaoDateOrder.dmy, separator: '-', hour12: false, yearPlaceholder: 'jjjj');
      case 'ru' || 'pl' || 'cs' || 'sk' || 'fi' || 'nb' || 'no' || 'da' || 'tr' || 'uk':
        return const KakaoDateFormat(order: KakaoDateOrder.dmy, separator: '.', hour12: false);
      case 'ja' || 'zh':
        return const KakaoDateFormat(
          order: KakaoDateOrder.ymd,
          separator: '/',
          hour12: false,
          firstWeekday: DateTime.sunday,
        );
      case 'ko':
        return const KakaoDateFormat(
          order: KakaoDateOrder.ymd,
          separator: '. ',
          hour12: true,
          firstWeekday: DateTime.sunday,
        );
      default:
        return const KakaoDateFormat(order: KakaoDateOrder.ymd, separator: '-', hour12: false);
    }
  }

  /// The field's parts for [kind]: [KakaoSegment]s and literal strings.
  List<Object> layout(KakaoDateKind kind, {required bool seconds}) {
    List<Object> date() => switch (order) {
      KakaoDateOrder.mdy => [KakaoSegment.month, separator, KakaoSegment.day, separator, KakaoSegment.year],
      KakaoDateOrder.dmy => [KakaoSegment.day, separator, KakaoSegment.month, separator, KakaoSegment.year],
      KakaoDateOrder.ymd => [KakaoSegment.year, separator, KakaoSegment.month, separator, KakaoSegment.day],
    };
    List<Object> time() => [
      KakaoSegment.hour,
      ':',
      KakaoSegment.minute,
      if (seconds) ...[':', KakaoSegment.second],
      // ICU (72 on) writes a narrow no-break space before AM / PM.
      if (hour12) ...['\u202f', KakaoSegment.dayPeriod],
    ];
    return switch (kind) {
      KakaoDateKind.date => date(),
      KakaoDateKind.time => time(),
      KakaoDateKind.dateTimeLocal => [...date(), ', ', ...time()],
      KakaoDateKind.month =>
        monthNames != null
            ? [KakaoSegment.monthName, ' ', KakaoSegment.year]
            : order == KakaoDateOrder.ymd
            ? [KakaoSegment.year, separator, KakaoSegment.month]
            : [KakaoSegment.month, separator, KakaoSegment.year],
      KakaoDateKind.week => ['$weekLabel ', KakaoSegment.week, ', ', KakaoSegment.year],
    };
  }

  @override
  bool operator ==(Object other) =>
      other is KakaoDateFormat &&
      other.order == order &&
      other.separator == separator &&
      other.hour12 == hour12 &&
      other.yearPlaceholder == yearPlaceholder &&
      other.monthPlaceholder == monthPlaceholder &&
      other.dayPlaceholder == dayPlaceholder &&
      other.firstWeekday == firstWeekday &&
      listEquals(other.monthNames, monthNames) &&
      other.weekLabel == weekLabel;

  @override
  int get hashCode => Object.hash(
    order,
    separator,
    hour12,
    yearPlaceholder,
    monthPlaceholder,
    dayPlaceholder,
    firstWeekday,
    Object.hashAll(monthNames ?? const []),
    weekLabel,
  );
}

/// How far an arrow key moves the [minute] / [hour] / [second] part, from
/// the field's `step` in seconds (Chromium steps a part by the step when the
/// step is a whole number of that part's unit and fits in the next one).
int kakaoPartStep(KakaoSegment s, double step) {
  final secs = step.round();
  switch (s) {
    case KakaoSegment.second:
      return secs < 60 && 60 % secs == 0 ? secs : 1;
    case KakaoSegment.minute:
      return secs % 60 == 0 && secs < 3600 && 3600 % secs == 0 ? secs ~/ 60 : 1;
    case KakaoSegment.hour:
      return secs % 3600 == 0 && secs < 86400 && 86400 % secs == 0 ? secs ~/ 3600 : 1;
    default:
      return 1;
  }
}

/// The range a part takes, given the other parts (a day stops at the
/// month's last day once month and year are known; a week at the year's
/// last ISO week).
(int, int) kakaoPartRange(KakaoSegment s, KakaoDateFields f, {required bool hour12}) => switch (s) {
  KakaoSegment.year => (1, kakaoMaxYear),
  KakaoSegment.month || KakaoSegment.monthName => (1, 12),
  KakaoSegment.day => (1, f.month == null ? 31 : kakaoDaysInMonth(f.year ?? 2000, f.month!)),
  KakaoSegment.week => (1, f.year == null ? 53 : kakaoWeeksInYear(f.year!)),
  KakaoSegment.hour => hour12 ? (1, 12) : (0, 23),
  KakaoSegment.minute || KakaoSegment.second => (0, 59),
  KakaoSegment.dayPeriod => (0, 1),
};

/// The digits a numeric part holds at most.
int kakaoPartDigits(KakaoSegment s) => s == KakaoSegment.year ? 4 : 2;

/// Days from 1970-01-01 (for step checks on dates).
int kakaoEpochDay(int y, int m, int d) => DateTime.utc(y, m, d).millisecondsSinceEpoch ~/ 86400000;

/// Whether a day, month or week is on the field's [step] from its base
/// ([min], else 1970-01-01 / 1970-01 / 1970-W01), as the browser's picker
/// leaves out the others.
bool kakaoOnStep(KakaoDateKind kind, KakaoDateFields f, double step, String? min) {
  final s = step.round();
  if (s <= 1) return true;
  final base = kakaoParseIso(kind == KakaoDateKind.dateTimeLocal ? KakaoDateKind.date : kind, min ?? '', hour12: false);
  switch (kind) {
    case KakaoDateKind.date:
      final b = base.year == null ? 0 : kakaoEpochDay(base.year!, base.month!, base.day!);
      return (kakaoEpochDay(f.year!, f.month!, f.day!) - b) % s == 0;
    case KakaoDateKind.month:
      final b = base.year == null ? 1970 * 12 : base.year! * 12 + base.month! - 1;
      return (f.year! * 12 + f.month! - 1 - b) % s == 0;
    case KakaoDateKind.week:
      final monday = kakaoIsoWeekMonday(f.year!, f.week!).millisecondsSinceEpoch ~/ 86400000;
      final b = base.year == null
          ? kakaoIsoWeekMonday(1970, 1).millisecondsSinceEpoch ~/ 86400000
          : kakaoIsoWeekMonday(base.year!, base.week!).millisecondsSinceEpoch ~/ 86400000;
      return ((monday - b) ~/ 7) % s == 0;
    case KakaoDateKind.time || KakaoDateKind.dateTimeLocal:
      return true;
  }
}

/// [v] kept within [lo] and [hi].
int kakaoClampInt(int v, int lo, int hi) => math.max(lo, math.min(hi, v));
