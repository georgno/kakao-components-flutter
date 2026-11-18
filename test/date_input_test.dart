// KakaoDateInput (date-input.js), with the shared date values, segment field
// and picker.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakao_components/kakao_components.dart';
import 'package:kakao_components/src/internal/kakao_date_values.dart';

Widget app(Widget child, {bool reduceMotion = false}) => WidgetsApp(
  color: const Color(0xFFFFFFFF),
  builder: (context, _) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
    child: KakaoTheme(
      data: KakaoThemeData.light,
      child: FocusScope(
        autofocus: true,
        child: Overlay(
          key: UniqueKey(),
          initialEntries: [
            OverlayEntry(
              builder: (_) => ColoredBox(
                color: const Color(0xFFFFFFFF),
                child: Stack(children: [Positioned(left: 40, top: 40, width: 320, child: child)]),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);

final st = KakaoDateInputSettings.of(KakaoThemeData.light.colors);
final sel = KakaoSelectSettings.of(KakaoThemeData.light.colors);
Finder get field => find.byType(KakaoDateInput);
Finder get box => find.descendant(of: field, matching: find.byType(AnimatedContainer)).first;
BoxDecoration boxDecoration(WidgetTester tester) => tester.widget<AnimatedContainer>(box).decoration! as BoxDecoration;

/// The field as it reads: the parts' and separators' texts in order.
String shown(WidgetTester tester) {
  final row = find.descendant(of: field, matching: find.byType(SingleChildScrollView));
  return tester.widgetList<Text>(find.descendant(of: row, matching: find.byType(Text))).map((t) => t.data).join();
}

/// The picker icon (its CustomPaint, inside the button's detector).
Finder get icon => find.bySemanticsLabel(KakaoDateInput.texts.picker);

/// A desktop platform: segments take a pointer; flutter_test's default is Android.
void desk(String name, WidgetTesterCallback body) =>
    testWidgets(name, body, variant: TargetPlatformVariant.only(TargetPlatform.linux));

Future<void> type(WidgetTester tester, String keys) async {
  for (final ch in keys.split('')) {
    final key = switch (ch) {
      '/' => LogicalKeyboardKey.slash,
      'a' => LogicalKeyboardKey.keyA,
      'p' => LogicalKeyboardKey.keyP,
      _ => LogicalKeyboardKey(LogicalKeyboardKey.digit0.keyId + int.parse(ch)),
    };
    await tester.sendKeyEvent(key, character: ch);
  }
  await tester.pump();
}

void main() {
  setUp(() => KakaoDateInput.clock = () => DateTime(2026, 11, 18, 10, 7, 30));
  tearDown(() => KakaoDateInput.clock = DateTime.now);

  group('date values', () {
    test('ISO weeks, week counts, value parsing and writing', () {
      expect(kakaoIsoWeek(DateTime.utc(2026, 3, 4)), (2026, 10));
      expect(kakaoIsoWeek(DateTime.utc(2027, 1, 1)), (2026, 53));
      expect(kakaoIsoWeek(DateTime.utc(2024, 12, 30)), (2025, 1));
      expect(kakaoWeeksInYear(2026), 53);
      expect(kakaoWeeksInYear(2025), 52);
      expect(kakaoIsoWeekMonday(2026, 10), DateTime.utc(2026, 3, 2));
      final f = kakaoParseIso(KakaoDateKind.dateTimeLocal, '2026-03-04T14:30', hour12: true);
      expect((f.hour, f.minute, f.pm), (2, 30, true));
      expect(kakaoIsoValue(KakaoDateKind.dateTimeLocal, f, hour12: true, seconds: false), '2026-03-04T14:30');
      expect(kakaoParseIso(KakaoDateKind.date, '2026-02-30', hour12: false), KakaoDateFields.empty);
      // A date that does not exist has no value.
      const feb31 = KakaoDateFields(year: 2026, month: 2, day: 31);
      expect(kakaoIsoValue(KakaoDateKind.date, feb31, hour12: false, seconds: false), '');
      expect(KakaoDateInput.valueAsDate(KakaoDateInputType.week, '2026-W10'), DateTime.utc(2026, 3, 2));
      expect(KakaoDateInput.valueAsDate(KakaoDateInputType.time, '09:30'), DateTime.utc(1970, 1, 1, 9, 30));
      expect(KakaoDateInput.valueAsDate(KakaoDateInputType.date, 'nope'), isNull);
    });

    test('today values: the step counted from min, nearest first; ranges over midnight', () {
      final now = DateTime(2026, 11, 18, 10, 7, 30);
      expect(kakaoTodayValues(KakaoDateKind.date, null, null, now), ['2026-11-18']);
      expect(kakaoTodayValues(KakaoDateKind.week, null, null, now), ['2026-W47']);
      // 10:07:30 is half way: Math.round goes up.
      expect(kakaoTodayValues(KakaoDateKind.time, 900, null, now), ['10:15', '10:00', '10:15']);
      expect(kakaoTodayValues(KakaoDateKind.time, null, null, now).first, '10:08');
      expect(kakaoTodayValues(KakaoDateKind.time, 900, '09:05', now), ['10:05', '10:05', '10:20']);
      expect(kakaoTodayValues(KakaoDateKind.dateTimeLocal, 1, null, now).first, '2026-11-18T10:07:30');
      expect(kakaoInRange(KakaoDateKind.time, '23:00', '22:00', '06:00'), isTrue);
      expect(kakaoInRange(KakaoDateKind.time, '12:00', '22:00', '06:00'), isFalse);
      expect(kakaoInRange(KakaoDateKind.date, '2026-11-30', '2026-11-16', '2026-11-27'), isFalse);
    });

    test('formats per locale', () {
      final de = KakaoDateFormat.forLocale(const Locale('de', 'AT'));
      expect((de.order, de.separator, de.hour12), (KakaoDateOrder.dmy, '.', false));
      expect(KakaoDateFormat.forLocale(const Locale('en', 'GB')).hour12, isFalse);
      expect(KakaoDateFormat.forLocale(const Locale('ja')).order, KakaoDateOrder.ymd);
      expect(KakaoDateFormat.forLocale(null), KakaoDateFormat.enUS);
    });
  });

  group('KakaoDateInput', () {
    desk('draws the field as date-input.js: Chromium\'s en-US parts, the icon where the chevron sits', (tester) async {
      await tester.pumpWidget(app(const KakaoDateInput(label: 'Start date', value: '2026-03-04', hint: 'Value')));
      expect(shown(tester), '03/04/2026');
      expect(tester.getSize(box).height, st.height);
      expect(boxDecoration(tester).border, Border.all(color: st.border));
      expect(boxDecoration(tester).color, st.bg);
      expect(boxDecoration(tester).borderRadius, BorderRadius.circular(st.radius));
      expect(find.text('Start date'), findsOneWidget);
      expect(find.text('Value'), findsOneWidget);
      // The icon: icon-size (1em of 15.2), its centre 0.45em in from the padding edge.
      final glyph = find.descendant(of: icon, matching: find.byType(CustomPaint)).first;
      expect(tester.getSize(glyph), Size.square(st.iconSize.of(st.font.size)));
      final centre = tester.getCenter(glyph).dx;
      expect(tester.getTopRight(box).dx - 1 - st.paddingX - centre, closeTo(.45 * st.font.size, .01));
      // The first part starts at the padding (+ the part's 1 px).
      final first = find.text('03');
      expect(tester.getTopLeft(first).dx - tester.getTopLeft(box).dx, 1 + st.paddingX + 1);

      await tester.pumpWidget(app(const KakaoDateInput(value: '2026-03-04', size: KakaoDateInputSize.sm)));
      expect(tester.getSize(box).height, 36);
      await tester.pumpWidget(app(const KakaoDateInput(value: '2026-03-04', size: KakaoDateInputSize.lg)));
      expect(tester.getSize(box).height, 52);
    });

    desk('every type in en-US, empty placeholders, other locales', (tester) async {
      Future<String> show(Widget w) async {
        await tester.pumpWidget(app(w));
        return shown(tester);
      }

      expect(await show(const KakaoDateInput()), 'mm/dd/yyyy');
      expect(await show(const KakaoDateInput(type: KakaoDateInputType.time, value: '09:30')), '09:30\u202fAM');
      expect(
        await show(const KakaoDateInput(type: KakaoDateInputType.time, value: '14:30:15', step: 1)),
        '02:30:15\u202fPM',
      );
      expect(await show(const KakaoDateInput(type: KakaoDateInputType.time)), '--:--\u202f--');
      expect(
        await show(const KakaoDateInput(type: KakaoDateInputType.dateTimeLocal, value: '2026-03-04T14:30')),
        '03/04/2026, 02:30\u202fPM',
      );
      expect(await show(const KakaoDateInput(type: KakaoDateInputType.month, value: '2026-03')), 'March 2026');
      expect(await show(const KakaoDateInput(type: KakaoDateInputType.week, value: '2026-W10')), 'Week 10, 2026');
      expect(await show(const KakaoDateInput(type: KakaoDateInputType.week)), 'Week --, yyyy');
      expect(await show(const KakaoDateInput(locale: Locale('de', 'AT'), value: '2026-03-04')), '04.03.2026');
      expect(await show(const KakaoDateInput(locale: Locale('de'))), 'tt.mm.jjjj');
      expect(
        await show(const KakaoDateInput(locale: Locale('de'), type: KakaoDateInputType.time, value: '14:30')),
        '14:30',
      );
      expect(await show(const KakaoDateInput(locale: Locale('ja'), value: '2026-03-04')), '2026/03/04');
    });

    desk('typing: digits fill a part and move on; input on every change, change on leaving a part', (tester) async {
      final input = <String>[];
      final change = <String>[];
      await tester.pumpWidget(app(KakaoDateInput(onChanged: input.add, onCommitted: change.add)));
      await tester.tap(find.text('mm'));
      await tester.pump();
      await type(tester, '3'); // a month after 3: no second digit fits
      expect(shown(tester), '03/dd/yyyy');
      await type(tester, '4');
      await type(tester, '2026');
      expect(shown(tester), '03/04/2026');
      // Each year digit is a value, as in Chromium (0002, 0020, 0202, 2026).
      expect(input, ['0002-03-04', '0020-03-04', '0202-03-04', '2026-03-04']);
      // Leaving month and day committed nothing new (no value yet); the year is still focused.
      expect(change, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(change, ['2026-03-04']);
    });

    desk('Up / Down step with wrap; an empty year takes the current one; Backspace empties', (tester) async {
      final input = <String>[];
      await tester.pumpWidget(app(KakaoDateInput(value: '2026-12-31', onChanged: input.add)));
      await tester.tap(find.text('12'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(shown(tester), '01/31/2026');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(shown(tester), '11/31/2026'); // kept, but no such day
      expect(input.last, '');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(shown(tester), '11/01/2026'); // 30 days: 31 wraps to 1
      expect(input.last, '2026-11-01');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      expect(shown(tester), '11/01/yyyy');
      expect(input.last, '');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(shown(tester), '11/01/2026'); // the clock's year
    });

    desk('time parts: the minute steps by step; AM / PM by letter', (tester) async {
      final input = <String>[];
      await tester.pumpWidget(
        app(KakaoDateInput(type: KakaoDateInputType.time, value: '09:30', step: 900, onChanged: input.add)),
      );
      await tester.tap(find.text('30'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(shown(tester), '09:45\u202fAM');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(shown(tester), '09:00\u202fAM');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await type(tester, 'p');
      expect(shown(tester), '09:00\u202fPM');
      expect(input.last, '21:00');
    });

    desk('the field and its icon are tab stops; focus draws the border and outline', (tester) async {
      await tester.pumpWidget(app(const KakaoDateInput(value: '2026-03-04')));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(boxDecoration(tester).border, Border.all(color: st.focus));
      // Through the three parts, then the icon.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        Focus.of(tester.element(find.descendant(of: icon, matching: find.byType(CustomPaint)).first)).hasFocus,
        isTrue,
      );
      expect(boxDecoration(tester).border, Border.all(color: st.focus));
      // Enter on the icon opens the picker.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('March 2026'), findsOneWidget);
    });

    desk('the calendar: a day picks and closes, input and change once; min / max disable', (tester) async {
      final input = <String>[];
      final change = <String>[];
      await tester.pumpWidget(
        app(
          KakaoDateInput(
            value: '2026-03-04',
            min: '2026-03-02',
            max: '2026-03-20',
            onChanged: input.add,
            onCommitted: change.add,
          ),
        ),
      );
      await tester.tap(icon);
      await tester.pumpAndSettle();
      expect(find.text('March 2026'), findsOneWidget);
      // Panel below the field, panel-offset away, in the select's panel chrome.
      final panel = find.ancestor(of: find.text('March 2026'), matching: find.byType(Container)).last;
      expect(tester.getTopLeft(panel).dy - tester.getBottomLeft(box).dy, sel.panelOffset);
      expect((tester.widget<Container>(panel).decoration! as BoxDecoration).boxShadow, sel.panelShadow);
      // US weeks start on Sunday.
      expect(tester.getCenter(find.text('Su')).dx, lessThan(tester.getCenter(find.text('Mo')).dx));
      // Out of range: nothing.
      await tester.tap(find.text('25'));
      await tester.pumpAndSettle();
      expect(input, isEmpty);
      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();
      expect(input, ['2026-03-15']);
      expect(change, ['2026-03-15']);
      expect(find.text('March 2026'), findsNothing);
      expect(shown(tester), '03/15/2026');
    });

    desk('the calendar by keyboard: arrows, PageDown, Enter; Escape closes and returns focus', (tester) async {
      final input = <String>[];
      await tester.pumpWidget(app(KakaoDateInput(value: '2026-03-04', onChanged: input.add)));
      await tester.tap(find.text('03'));
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();
      expect(find.text('March 2026'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pump();
      expect(find.text('April 2026'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(input, ['2026-04-12']);
      expect(find.text('April 2026'), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.f4);
      await tester.pumpAndSettle();
      expect(find.text('April 2026'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('April 2026'), findsNothing);
      expect(boxDecoration(tester).border, Border.all(color: st.focus));
    });

    desk('Clear and Today at the foot; the header switches to a year of months', (tester) async {
      final input = <String>[];
      await tester.pumpWidget(app(KakaoDateInput(value: '2026-03-04', onChanged: input.add)));
      await tester.tap(icon);
      await tester.pumpAndSettle();
      await tester.tap(find.text('March 2026'));
      await tester.pumpAndSettle();
      expect(find.text('March 2026'), findsNothing);
      expect(find.text('Dec'), findsOneWidget);
      await tester.tap(find.text('Jul'));
      await tester.pumpAndSettle();
      expect(find.text('July 2026'), findsOneWidget);
      expect(input, isEmpty); // navigation only
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();
      expect(input, ['2026-11-18']);
      await tester.tap(icon);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      expect(input.last, '');
      expect(shown(tester), 'mm/dd/yyyy');
    });

    desk('week: the row is the pick, with week numbers; month: a year of months', (tester) async {
      final input = <String>[];
      await tester.pumpWidget(
        app(KakaoDateInput(type: KakaoDateInputType.week, value: '2026-W10', onChanged: input.add)),
      );
      await tester.tap(icon);
      await tester.pumpAndSettle();
      expect(find.text('Wk'), findsOneWidget);
      expect(find.text('10'), findsWidgets);
      await tester.tap(find.text('19').first); // Thursday 19 March: week 12
      await tester.pumpAndSettle();
      expect(input, ['2026-W12']);
      expect(shown(tester), 'Week 12, 2026');

      input.clear();
      await tester.pumpWidget(
        app(KakaoDateInput(type: KakaoDateInputType.month, value: '2026-03', max: '2026-06', onChanged: input.add)),
      );
      await tester.tap(icon);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sep')); // after max
      await tester.pumpAndSettle();
      expect(input, isEmpty);
      await tester.tap(find.text('May'));
      await tester.pumpAndSettle();
      expect(input, ['2026-05']);
      expect(shown(tester), 'May 2026');
    });

    desk('time: columns pick parts and stay open; datetime-local: calendar and columns side by side', (tester) async {
      final input = <String>[];
      await tester.pumpWidget(app(KakaoDateInput(type: KakaoDateInputType.time, step: 900, onChanged: input.add)));
      await tester.tap(icon);
      await tester.pumpAndSettle();
      expect(find.text('45'), findsOneWidget); // minutes in 15-minute steps
      expect(find.text('10'), findsNothing);
      await tester.tap(find.text('PM'));
      await tester.pump();
      expect(input, ['12:00']); // the empty parts take their first value: 12 PM
      await tester.tap(find.text('45'));
      await tester.pump();
      expect(input.last, '12:45');
      expect(find.text('45'), findsWidgets); // still open
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(ListView), findsNothing);

      input.clear();
      await tester.pumpWidget(
        app(KakaoDateInput(type: KakaoDateInputType.dateTimeLocal, value: '2026-03-04T14:30', onChanged: input.add)),
      );
      await tester.tap(icon);
      await tester.pumpAndSettle();
      expect(find.text('March 2026'), findsOneWidget);
      expect(find.byType(ListView), findsNWidgets(3)); // hours, minutes, AM / PM
      await tester.tap(find.text('9').first);
      await tester.pump();
      expect(input, ['2026-03-09T14:30']);
      expect(find.text('March 2026'), findsOneWidget); // a day keeps it open
    });

    desk('the today tag: sets the value as a user edit; out of range it is disabled and says why', (tester) async {
      final input = <String>[];
      final change = <String>[];
      await tester.pumpWidget(
        app(KakaoDateInput(today: true, hint: 'Today in one click', onChanged: input.add, onCommitted: change.add)),
      );
      final tag = find.text('Today');
      expect(tag, findsOneWidget);
      final style = tester.widget<Text>(tag).style!;
      expect(style.fontSize, st.todayFontSize);
      expect(style.color, st.todayText);
      final drawn = find.ancestor(of: tag, matching: find.byType(AnimatedContainer)).first;
      expect(tester.getSize(drawn).height, st.todayHeight);
      expect((tester.widget<AnimatedContainer>(drawn).decoration! as BoxDecoration).color, st.todayBg);
      // At the end of the row under the field, beside the hint.
      expect(tester.getTopRight(drawn).dx, tester.getTopRight(box).dx);
      expect(tester.getTopLeft(drawn).dy, tester.getTopLeft(find.text('Today in one click')).dy);
      expect(find.bySemanticsLabel('Set to today'), findsOneWidget);
      await tester.tap(tag);
      await tester.pump();
      expect(input, ['2026-11-18']);
      expect(change, ['2026-11-18']);
      expect(shown(tester), '11/18/2026');

      input.clear();
      await tester.pumpWidget(app(KakaoDateInput(today: true, min: '2026-11-25', onChanged: input.add)));
      await tester.tap(find.text('Today'));
      await tester.pump();
      expect(input, isEmpty);
      final node = tester.getSemantics(find.bySemanticsLabel('Set to today'));
      expect(node.hint, 'Today (2026-11-18) is outside the allowed range: 2026-11-25 or later.');

      await tester.pumpWidget(app(const KakaoDateInput(today: true, type: KakaoDateInputType.time, step: 900)));
      expect(find.text('Now'), findsOneWidget);
      await tester.pumpWidget(app(const KakaoDateInput(today: true, locale: Locale('de'))));
      expect(find.text('Heute'), findsOneWidget);
      await tester.pumpWidget(app(const KakaoDateInput(today: true, todayLabel: 'Use today')));
      expect(find.text('Use today'), findsOneWidget);
      await tester.pumpWidget(app(const KakaoDateInput(today: true, disabled: true)));
      expect(find.text('Today'), findsNothing);
      await tester.pumpWidget(app(const KakaoDateInput(today: true, readOnly: true)));
      expect(find.text('Today'), findsNothing);
    });

    desk('disabled dims and takes focus away; read only walks the parts but does not edit or open', (tester) async {
      final input = <String>[];
      await tester.pumpWidget(app(KakaoDateInput(value: '2026-03-04', disabled: true, onChanged: input.add)));
      expect(
        tester.widget<Opacity>(find.descendant(of: field, matching: find.byType(Opacity)).first).opacity,
        st.disabledOpacity,
      );
      // No picker icon on a disabled or read-only field (Chromium draws none).
      expect(icon, findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(boxDecoration(tester).border, Border.all(color: st.border));

      await tester.pumpWidget(app(KakaoDateInput(value: '2026-03-04', readOnly: true, onChanged: input.add)));
      await tester.tap(find.text('03'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await type(tester, '1');
      expect(shown(tester), '03/04/2026');
      expect(icon, findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.f4);
      await tester.pumpAndSettle();
      expect(find.text('March 2026'), findsNothing);
      expect(input, isEmpty);
    });

    desk('error: danger border and message; a new value from the owner shows without reporting', (tester) async {
      final input = <String>[];
      await tester.pumpWidget(
        app(KakaoDateInput(value: '2026-03-04', error: 'Too early', hint: 'h', onChanged: input.add)),
      );
      expect(boxDecoration(tester).border, Border.all(color: st.danger));
      expect(tester.widget<Text>(find.text('Too early')).style!.color, st.danger);
      expect(find.text('h'), findsNothing);
      await tester.pumpWidget(app(KakaoDateInput(value: '2026-12-24', error: 'Too early', onChanged: input.add)));
      expect(shown(tester), '12/24/2026');
      expect(input, isEmpty);
    });

    testWidgets('touch platforms: a tap on the field opens the picker', (tester) async {
      await tester.pumpWidget(app(const KakaoDateInput(value: '2026-03-04')));
      await tester.tap(find.text('04'));
      await tester.pumpAndSettle();
      expect(find.text('March 2026'), findsOneWidget);
      // A pick closes it again.
      await tester.tap(find.text('5').first);
      await tester.pumpAndSettle();
      expect(find.text('March 2026'), findsNothing);
      expect(shown(tester), '03/05/2026');
      expect(defaultTargetPlatform, TargetPlatform.android);
    });

    desk('controller: showPicker', (tester) async {
      final ctl = KakaoDateInputController();
      addTearDown(ctl.dispose);
      await tester.pumpWidget(app(KakaoDateInput(value: '2026-03-04', controller: ctl)));
      ctl.open();
      await tester.pumpAndSettle();
      expect(find.text('March 2026'), findsOneWidget);
      ctl.close();
      await tester.pumpAndSettle();
      expect(find.text('March 2026'), findsNothing);
    });
  });
}
