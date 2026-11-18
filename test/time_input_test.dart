// KakaoTimeInput (time-input.js), and the time columns' min / max rule it
// brought to the shared picker.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakao_components/kakao_components.dart';
import 'package:kakao_components/src/internal/kakao_date_values.dart';

Widget app(Widget child) => WidgetsApp(
  color: const Color(0xFFFFFFFF),
  builder: (context, _) => KakaoTheme(
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
);

final st = KakaoTimeInputSettings.of(KakaoThemeData.light.colors);
Finder get field => find.byType(KakaoTimeInput);
Finder get box => find.descendant(of: field, matching: find.byType(AnimatedContainer)).first;
BoxDecoration boxDecoration(WidgetTester tester) => tester.widget<AnimatedContainer>(box).decoration! as BoxDecoration;

/// The field as it reads: the parts' and separators' texts in order.
String shown(WidgetTester tester, [Finder? of]) {
  final row = find.descendant(of: of ?? field, matching: find.byType(SingleChildScrollView));
  return tester.widgetList<Text>(find.descendant(of: row, matching: find.byType(Text))).map((t) => t.data).join();
}

Finder get icon => find.bySemanticsLabel(KakaoTimeInput.texts.picker);

/// A row of the picker's [column]th time column.
Finder cell(int column, String text) =>
    find.descendant(of: find.byType(ListView).at(column), matching: find.text(text));

/// The opacity a picker row is drawn at (1: it can be picked).
double rowOpacity(WidgetTester tester, Finder row) =>
    tester.widget<Opacity>(find.ancestor(of: row, matching: find.byType(Opacity)).first).opacity;

/// A desktop platform: segments take a pointer; flutter_test's default is Android.
void desk(String name, WidgetTesterCallback body) =>
    testWidgets(name, body, variant: TargetPlatformVariant.only(TargetPlatform.linux));

Future<void> type(WidgetTester tester, String keys) async {
  for (final ch in keys.split('')) {
    final key = switch (ch) {
      'a' => LogicalKeyboardKey.keyA,
      'p' => LogicalKeyboardKey.keyP,
      _ => LogicalKeyboardKey(LogicalKeyboardKey.digit0.keyId + int.parse(ch)),
    };
    await tester.sendKeyEvent(key, character: ch);
  }
  await tester.pump();
}

void main() {
  setUp(() {
    KakaoTimeInput.clock = () => DateTime(2026, 11, 18, 10, 7, 30);
    KakaoDateInput.clock = () => DateTime(2026, 11, 18, 10, 7, 30);
  });
  tearDown(() {
    KakaoTimeInput.clock = DateTime.now;
    KakaoDateInput.clock = DateTime.now;
  });

  test('valueAsNumber, valueAsDate, the now label, time seconds', () {
    expect(KakaoTimeInput.valueAsNumber('14:30'), (14 * 3600 + 30 * 60) * 1000);
    expect(KakaoTimeInput.valueAsNumber('00:01:30.25'), 90250);
    expect(KakaoTimeInput.valueAsNumber(''), isNull);
    expect(KakaoTimeInput.valueAsDate('14:30'), DateTime.utc(1970, 1, 1, 14, 30));
    expect(KakaoTimeInput.nowLabelFor(const Locale('fr')), 'Maintenant');
    expect(KakaoTimeInput.nowLabelFor(const Locale('ja')), 'Now');
    expect(kakaoTimeSeconds('2026-03-04T09:00:05'), 9 * 3600 + 5);
    expect(kakaoTimeSeconds('x'), isNull);
  });

  group('KakaoTimeInput', () {
    desk('draws the field as time-input.js: Chromium\'s en-US parts, the clock where the chevron sits', (tester) async {
      await tester.pumpWidget(app(const KakaoTimeInput(label: 'Start', value: '09:30', hint: 'Office hours')));
      expect(shown(tester), '09:30 AM');
      expect(tester.getSize(box).height, st.height);
      expect(boxDecoration(tester).border, Border.all(color: st.border));
      expect(boxDecoration(tester).color, st.bg);
      expect(boxDecoration(tester).borderRadius, BorderRadius.circular(st.radius));
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('Office hours'), findsOneWidget);
      final glyph = find.descendant(of: icon, matching: find.byType(CustomPaint)).first;
      expect(tester.getSize(glyph), Size.square(st.iconSize.of(st.font.size)));
      expect(
        tester.getTopRight(box).dx - 1 - st.paddingX - tester.getCenter(glyph).dx,
        closeTo(.45 * st.font.size, .01),
      );

      await tester.pumpWidget(app(const KakaoTimeInput(value: '09:30', size: KakaoTimeInputSize.sm)));
      expect(tester.getSize(box).height, 36);
      await tester.pumpWidget(app(const KakaoTimeInput(value: '09:30', size: KakaoTimeInputSize.lg)));
      expect(tester.getSize(box).height, 52);
    });

    desk('12 or 24 hours by locale; seconds when step is below a minute', (tester) async {
      Future<String> show(Widget w) async {
        await tester.pumpWidget(app(w));
        return shown(tester);
      }

      expect(await show(const KakaoTimeInput()), '--:-- --');
      expect(await show(const KakaoTimeInput(value: '14:30:15', step: 1)), '02:30:15 PM');
      expect(await show(const KakaoTimeInput(value: '00:01:30', step: 1, locale: Locale('de'))), '00:01:30');
      expect(await show(const KakaoTimeInput(value: '14:30', locale: Locale('de'))), '14:30');
    });

    desk('typing and Up / Down by step; input on every change, change on leaving a part', (tester) async {
      final input = <String>[];
      final change = <String>[];
      await tester.pumpWidget(
        app(KakaoTimeInput(step: 900, locale: const Locale('de'), onChanged: input.add, onCommitted: change.add)),
      );
      await tester.tap(find.text('--').first);
      await tester.pump();
      await type(tester, '14');
      expect(shown(tester), '14:--');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(shown(tester), '14:00');
      expect(input, ['14:00']);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(input.last, '14:15');
      expect(change, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(change, ['14:15']);
    });

    desk('the picker: time columns pick and stay open; rows outside min / max are dimmed and skipped', (tester) async {
      final input = <String>[];
      await tester.pumpWidget(
        app(
          KakaoTimeInput(
            value: '17:00',
            min: '09:00',
            max: '17:00',
            step: 900,
            locale: const Locale('de'),
            onChanged: input.add,
          ),
        ),
      );
      await tester.tap(icon);
      await tester.pumpAndSettle();
      expect(find.byType(ListView), findsNWidgets(2)); // hours, minutes
      expect(rowOpacity(tester, cell(0, '17')), 1);
      expect(rowOpacity(tester, cell(0, '18')), st.disabledOpacity);
      expect(rowOpacity(tester, cell(1, '00')), 1);
      expect(rowOpacity(tester, cell(1, '15')), st.disabledOpacity); // 17:15 is after max
      await tester.tap(cell(0, '18'));
      await tester.tap(cell(1, '15'));
      await tester.pump();
      expect(input, isEmpty);
      await tester.tap(cell(0, '16'));
      await tester.pump();
      expect(input, ['16:00']);
      await tester.tap(cell(1, '45'));
      await tester.pump();
      expect(input.last, '16:45');
      // Down from 16 walks past the evening and night to 09.
      await tester.tap(cell(0, '16'));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(input.last, '17:45'); // the hour alone decides the hour column
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(input.last, '09:45');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(ListView), findsNothing);
    });

    desk('a range over midnight; AM / PM rows in 12 hours', (tester) async {
      await tester.pumpWidget(app(const KakaoTimeInput(value: '23:00', min: '22:00', max: '06:00')));
      await tester.tap(icon);
      await tester.pumpAndSettle();
      // 11 PM picked: 10 and 11 can be (PM), 08 (8 PM) cannot.
      expect(rowOpacity(tester, cell(0, '11')), 1);
      expect(rowOpacity(tester, cell(0, '08')), st.disabledOpacity);
      // AM with hour 11 is 11:00: out of range.
      expect(rowOpacity(tester, cell(2, 'AM')), st.disabledOpacity);
      expect(rowOpacity(tester, cell(2, 'PM')), 1);
    });

    desk('the now tag: the time snapped to step, as a user edit; out of range disabled and says why', (tester) async {
      final input = <String>[];
      final change = <String>[];
      await tester.pumpWidget(
        app(KakaoTimeInput(now: true, step: 900, hint: 'h', onChanged: input.add, onCommitted: change.add)),
      );
      final tag = find.text('Now');
      final style = tester.widget<Text>(tag).style!;
      expect(style.fontSize, st.nowFontSize);
      expect(style.color, st.nowText);
      final drawn = find.ancestor(of: tag, matching: find.byType(AnimatedContainer)).first;
      expect(tester.getSize(drawn).height, st.nowHeight);
      expect((tester.widget<AnimatedContainer>(drawn).decoration! as BoxDecoration).color, st.nowBg);
      expect(tester.getTopRight(drawn).dx, tester.getTopRight(box).dx);
      expect(find.bySemanticsLabel('Set to now'), findsOneWidget);
      await tester.tap(tag);
      await tester.pump();
      expect(input, ['10:15']); // 10:07:30 is past half of the quarter
      expect(change, ['10:15']);
      expect(shown(tester), '10:15 AM');

      input.clear();
      await tester.pumpWidget(app(KakaoTimeInput(now: true, min: '12:00', max: '13:00', onChanged: input.add)));
      await tester.tap(find.text('Now'));
      await tester.pump();
      expect(input, isEmpty);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Set to now')).hint,
        'Now (10:08) is outside the allowed range: 12:00 to 13:00.',
      );

      await tester.pumpWidget(app(const KakaoTimeInput(now: true, locale: Locale('de'))));
      expect(find.text('Jetzt'), findsOneWidget);
      await tester.pumpWidget(app(const KakaoTimeInput(now: true, nowLabel: 'Right now')));
      expect(find.text('Right now'), findsOneWidget);
      await tester.pumpWidget(app(const KakaoTimeInput(now: true, disabled: true)));
      expect(find.text('Now'), findsNothing);
      await tester.pumpWidget(app(const KakaoTimeInput(now: true, readOnly: true)));
      expect(find.text('Now'), findsNothing);
    });

    desk('disabled and read only: no icon, no picker; error: danger border; owner values do not report', (
      tester,
    ) async {
      final input = <String>[];
      await tester.pumpWidget(app(KakaoTimeInput(value: '09:30', disabled: true, onChanged: input.add)));
      expect(
        tester.widget<Opacity>(find.descendant(of: field, matching: find.byType(Opacity)).first).opacity,
        st.disabledOpacity,
      );
      expect(icon, findsNothing);
      await tester.pumpWidget(app(KakaoTimeInput(value: '09:30', readOnly: true, onChanged: input.add)));
      expect(icon, findsNothing);
      await tester.tap(find.text('09'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.f4);
      await tester.pumpAndSettle();
      expect(find.byType(ListView), findsNothing);
      expect(shown(tester), '09:30 AM');

      await tester.pumpWidget(app(KakaoTimeInput(value: '09:30', error: 'Too early', onChanged: input.add)));
      expect(boxDecoration(tester).border, Border.all(color: st.danger));
      expect(tester.widget<Text>(find.text('Too early')).style!.color, st.danger);
      await tester.pumpWidget(app(KakaoTimeInput(value: '18:00', error: 'Too early', onChanged: input.add)));
      expect(shown(tester), '06:00 PM');
      expect(input, isEmpty);
    });

    testWidgets('touch platforms: a tap on the field opens the picker', (tester) async {
      await tester.pumpWidget(app(const KakaoTimeInput(value: '09:30')));
      await tester.tap(find.text('30'));
      await tester.pumpAndSettle();
      expect(find.byType(ListView), findsNWidgets(3));
      expect(defaultTargetPlatform, TargetPlatform.android);
    });

    desk('controller: showPicker', (tester) async {
      final ctl = KakaoTimeInputController();
      addTearDown(ctl.dispose);
      await tester.pumpWidget(app(KakaoTimeInput(value: '09:30', controller: ctl)));
      ctl.open();
      await tester.pumpAndSettle();
      expect(find.byType(ListView), findsNWidgets(3));
      ctl.close();
      await tester.pumpAndSettle();
      expect(find.byType(ListView), findsNothing);
    });
  });

  desk('date-input datetime-local: the time columns follow min on its day', (tester) async {
    await tester.pumpWidget(
      app(
        const KakaoDateInput(
          type: KakaoDateInputType.dateTimeLocal,
          value: '2026-03-04T15:30',
          min: '2026-03-04T15:00',
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel(KakaoDateInput.texts.picker));
    await tester.pumpAndSettle();
    expect(rowOpacity(tester, cell(0, '02')), st.disabledOpacity); // 2 PM, before 3 PM
    expect(rowOpacity(tester, cell(0, '03')), 1);
    expect(rowOpacity(tester, cell(2, 'AM')), st.disabledOpacity);
    // Another day: every time.
    await tester.tap(find.text('5').first);
    await tester.pump();
    expect(rowOpacity(tester, cell(0, '02')), 1);
  });
}
