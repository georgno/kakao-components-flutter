// KakaoMultiDropdown (multi-dropdown.js).
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakao_components/kakao_components.dart';
import 'package:kakao_components/src/internal/kakao_anchored_panel.dart';
import 'package:kakao_components/src/internal/kakao_option_list.dart';

Widget app(Widget child, {bool reduceMotion = false, bool highContrast = false, double width = 900}) => WidgetsApp(
  color: const Color(0xFFFFFFFF),
  builder: (context, _) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion, highContrast: highContrast),
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
                child: Stack(
                  children: [
                    Positioned(
                      left: 20,
                      top: 20,
                      width: width,
                      child: Align(alignment: Alignment.topLeft, child: child),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);

void useScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

const panelKey = Key('panel');
Finder get panel => find.byKey(panelKey);
final st = KakaoMultiDropdownSettings.of(KakaoThemeData.light.colors);

// multi-dropdown/demo.html "Product variant".
const variant = [
  KakaoMultiDropdownSegment(
    name: 'size',
    label: 'Size',
    options: [
      KakaoMultiDropdownOption('XS'),
      KakaoMultiDropdownOption('S'),
      KakaoMultiDropdownOption('M'),
      KakaoMultiDropdownOption('L'),
      KakaoMultiDropdownOption('XL'),
    ],
  ),
  KakaoMultiDropdownSegment(
    name: 'color',
    label: 'Colour',
    options: [KakaoMultiDropdownOption('black'), KakaoMultiDropdownOption('white'), KakaoMultiDropdownOption('sand')],
  ),
];

/// A segment's box, by the start of its accessible name ("Day, …").
Finder box(String segment) => find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.button == true && (w.properties.label?.startsWith('$segment, ') ?? false),
);

String boxLabel(WidgetTester tester, String segment) => tester.widget<Semantics>(box(segment)).properties.label!;

/// The text a box shows.
String shown(WidgetTester tester, String segment) =>
    tester.widget<Text>(find.descendant(of: box(segment), matching: find.byType(Text)).first).data!;

Future<void> key(WidgetTester tester, LogicalKeyboardKey k) async {
  await tester.sendKeyEvent(k);
  await tester.pump();
}

Future<void> open(WidgetTester tester, String segment) async {
  await tester.tap(box(segment));
  await tester.pumpAndSettle();
}

/// The rows of the open list.
List<KakaoOption> rows(WidgetTester tester) =>
    kakaoOptionRows(tester.widget<KakaoOptionList>(find.byType(KakaoOptionList)).entries);

int? highlighted(WidgetTester tester) =>
    tester.widget<KakaoOptionList>(find.byType(KakaoOptionList)).controller.highlighted;

Future<void> tapRow(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: panel, matching: find.text(label)).first);
  await tester.pumpAndSettle();
}

bool focused(WidgetTester tester, String segment) => tester.widget<Semantics>(box(segment)).properties.focused == true;

/// Width of the box of [segment].
double boxWidth(WidgetTester tester, String segment) => tester.getSize(box(segment)).width;

void main() {
  group('KakaoMultiDropdown value', () {
    testWidgets('date preset: a partly known date shows dashes and keeps its value', (tester) async {
      useScreen(tester);
      final c = KakaoMultiDropdownController();
      await tester.pumpWidget(
        app(
          KakaoMultiDropdown.date(
            label: 'Date of birth',
            allowUnknown: const {'day', 'month'},
            value: '00.00.1990',
            controller: c,
          ),
        ),
      );
      expect(shown(tester, 'Day'), '–');
      expect(shown(tester, 'Month'), '–');
      expect(shown(tester, 'Year'), '1990');
      expect(c.value, '00.00.1990');
      expect(c.parts, {'day': '00', 'month': '00', 'year': '1990'});
      // The accessible name still says Unknown.
      expect(boxLabel(tester, 'Day'), 'Day, Unknown');
      expect(find.text('Date of birth'), findsOneWidget);
    });

    testWidgets('custom segments join with the separator', (tester) async {
      useScreen(tester);
      final changes = <KakaoMultiDropdownChange>[];
      await tester.pumpWidget(
        app(
          KakaoMultiDropdown(
            label: 'Variant',
            separator: ' / ',
            segments: variant,
            onChanged: changes.add,
            panelKey: panelKey,
          ),
        ),
      );
      expect(shown(tester, 'Size'), 'Please select');
      await open(tester, 'Size');
      await tapRow(tester, 'M');
      expect(changes.last.value, '');
      expect(changes.last.complete, isFalse);
      expect(changes.last.parts, {'size': 'M', 'color': null});
      await open(tester, 'Colour');
      await tapRow(tester, 'black');
      expect(changes.last.value, 'M / black');
      expect(changes.last.complete, isTrue);
      expect(shown(tester, 'Size'), 'M');
    });

    testWidgets('a day that no longer fits moves to the last day and comes back', (tester) async {
      useScreen(tester);
      final c = KakaoMultiDropdownController();
      final changes = <KakaoMultiDropdownChange>[];
      await tester.pumpWidget(
        app(KakaoMultiDropdown.date(minYear: 2020, maxYear: 2026, controller: c, onChanged: changes.add)),
      );
      c.setPart('day', '31');
      c.setPart('month', '02');
      await tester.pump();
      expect(c.parts['day'], '29'); // February, year unknown: 29
      c.setPart('year', '2023');
      await tester.pump();
      expect(c.parts['day'], '28');
      expect(changes.last.value, '28.02.2023');
      c.setPart('year', '2024');
      c.setPart('month', '03');
      await tester.pump();
      expect(c.value, '31.03.2024');
    });

    testWidgets('impossible days are disabled', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(app(KakaoMultiDropdown.date(minYear: 2020, maxYear: 2026, value: '01.02.2023')));
      await open(tester, 'Day');
      final r = rows(tester);
      expect(r.length, 31);
      expect(
        [
          for (final o in r)
            if (o.disabled) o.label,
        ],
        ['29', '30', '31'],
      );
      expect(r[30].textStyle?.decoration, TextDecoration.lineThrough);
    });

    testWidgets('owner value, clear and the unknown list', (tester) async {
      useScreen(tester);
      final c = KakaoMultiDropdownController();
      final changes = <KakaoMultiDropdownChange>[];
      Widget build(String v) =>
          app(KakaoMultiDropdown.date(allowUnknown: const {}, value: v, controller: c, onChanged: changes.add));
      await tester.pumpWidget(build('05.06.2001'));
      await tester.pumpWidget(build('00.06.0000'));
      expect(c.value, '00.06.0000');
      expect(changes, isEmpty); // the owner's value is not reported
      c.setPart('month', '00');
      await tester.pump();
      expect(changes.last.unknown, ['day', 'month', 'year']);
      c.clear();
      await tester.pump();
      expect(c.value, '');
      expect(shown(tester, 'Day'), 'Please select');
      expect(changes.last.parts.values.every((v) => v == null), isTrue);
    });
  });

  group('KakaoMultiDropdown look', () {
    testWidgets('boxes keep their size when the value changes', (tester) async {
      useScreen(tester);
      final c = KakaoMultiDropdownController();
      await tester.pumpWidget(app(KakaoMultiDropdown.date(value: '01.05.2000', controller: c)));
      final before = boxWidth(tester, 'Month');
      c.setPart('month', '09');
      await tester.pump();
      expect(shown(tester, 'Month'), 'September');
      expect(boxWidth(tester, 'Month'), before);
    });

    testWidgets('placeholders, the short ones when cramped, then ellipsis', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(app(KakaoMultiDropdown.date(), width: 900));
      expect(shown(tester, 'Day'), 'Please select');
      expect(shown(tester, 'Year'), 'Please select');
      await tester.pumpWidget(app(KakaoMultiDropdown.date(), width: 500));
      expect(shown(tester, 'Day'), 'DD');
      expect(shown(tester, 'Month'), 'MM');
      expect(shown(tester, 'Year'), 'YYYY');
      await tester.pumpWidget(app(KakaoMultiDropdown.date(), width: 200));
      final group = tester.getSize(find.byType(LayoutBuilder).first);
      expect(group.width, lessThanOrEqualTo(200));
      expect(tester.takeException(), isNull);
    });

    testWidgets('outer corners rounded only; neighbours share a border', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(app(KakaoMultiDropdown.date(value: '01.05.2000')));
      final day = tester.getRect(box('Day'));
      final month = tester.getRect(box('Month'));
      expect(month.left, closeTo(day.right - 1, .01));
      BorderRadius radius(String s) =>
          ((tester
                          .widgetList<AnimatedContainer>(
                            find.descendant(of: box(s), matching: find.byType(AnimatedContainer)),
                          )
                          .first
                          .foregroundDecoration)!
                      as BoxDecoration)
                  .borderRadius!
              as BorderRadius;
      expect(radius('Day').topLeft, Radius.circular(st.radius));
      expect(radius('Day').topRight, Radius.zero);
      expect(radius('Month'), BorderRadius.zero);
      expect(radius('Year').bottomRight, Radius.circular(st.radius));
    });

    testWidgets('the open list: unknown first in italics, selected in the accent', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(
        app(KakaoMultiDropdown.date(allowUnknown: const {'month'}, value: '01.06.2000', panelKey: panelKey)),
      );
      await open(tester, 'Month');
      final r = rows(tester);
      expect(r.first.label, 'Unknown');
      expect(r.first.textStyle?.fontStyle, FontStyle.italic);
      final oct = r.firstWhere((o) => o.label == 'June');
      expect(oct.selected, isTrue);
      expect(oct.textStyle?.color, st.accent);
      expect(oct.textStyle?.fontWeight, FontWeight.w600);
      expect(highlighted(tester), r.indexOf(oct));
      // The hint (the month's number) sits at the row's end.
      expect(find.descendant(of: panel, matching: find.text('06')), findsOneWidget);
      // At least as wide as its box, at most popup-height tall.
      expect(tester.getSize(panel).width, greaterThanOrEqualTo(tester.getSize(box('Month')).width));
      expect(tester.getSize(panel).height, lessThanOrEqualTo(st.popupHeight));
      // Below the box, popup-offset away.
      expect(tester.getRect(panel).top, closeTo(tester.getRect(box('Month')).bottom + st.popupOffset, .01));
      // The current value is centred.
      final row = tester.getRect(find.descendant(of: panel, matching: find.text('June')));
      final p = tester.getRect(panel);
      expect(row.center.dy, closeTo(p.center.dy, 20));
    });

    testWidgets('more contrast: the theme’s more-contrast colours', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(app(KakaoMultiDropdown.date(), highContrast: true));
      final hc = KakaoMultiDropdownSettings.of(KakaoThemeData.light.highContrast);
      final d =
          tester
                  .widgetList<AnimatedContainer>(
                    find.descendant(of: box('Day'), matching: find.byType(AnimatedContainer)),
                  )
                  .first
                  .foregroundDecoration!
              as BoxDecoration;
      expect((d.border! as Border).top.color, hc.border);
      final placeholder = tester.widget<Text>(find.descendant(of: box('Day'), matching: find.byType(Text)).first);
      expect(placeholder.style!.color, hc.muted);
      expect(hc.muted, isNot(st.muted));
    });

    testWidgets('disabled: dimmed, does not open', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(app(KakaoMultiDropdown.date(value: '01.01.2000', disabled: true, panelKey: panelKey)));
      expect(tester.widget<Opacity>(find.byType(Opacity).first).opacity, st.disabledOpacity);
      await tester.tap(box('Day'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
    });
  });

  group('KakaoMultiDropdown pointer', () {
    testWidgets('tap opens, tap again closes; another box switches; outside closes', (tester) async {
      useScreen(tester);
      final events = <String>[];
      await tester.pumpWidget(
        app(
          KakaoMultiDropdown.date(
            panelKey: panelKey,
            onOpenChanged: (s, o) => events.add('$s ${o ? 'open' : 'close'}'),
          ),
        ),
      );
      await open(tester, 'Day');
      expect(panel, findsOneWidget);
      expect(tester.widget<Semantics>(box('Day')).properties.expanded, isTrue);
      await open(tester, 'Day');
      expect(panel, findsNothing);
      await open(tester, 'Day');
      await open(tester, 'Year');
      expect(events, ['day open', 'day close', 'day open', 'day close', 'year open']);
      await tester.tapAt(const Offset(700, 800));
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      expect(events.last, 'year close');
    });

    testWidgets('a pick closes the list and keeps focus on the box', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(app(KakaoMultiDropdown(segments: variant, panelKey: panelKey)));
      await open(tester, 'Size');
      await tapRow(tester, 'L');
      expect(panel, findsNothing);
      expect(shown(tester, 'Size'), 'L');
      expect(focused(tester, 'Size'), isTrue);
    });

    testWidgets('hover highlights a row and the box', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(app(KakaoMultiDropdown(segments: variant, panelKey: panelKey)));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(box('Colour')));
      addTearDown(mouse.removePointer);
      await tester.pumpAndSettle();
      final bg =
          tester
                  .widgetList<AnimatedContainer>(
                    find.descendant(of: box('Colour'), matching: find.byType(AnimatedContainer)),
                  )
                  .elementAt(1)
                  .decoration!
              as BoxDecoration;
      expect(bg.color, st.hoverBg);
      await open(tester, 'Colour');
      await mouse.moveTo(tester.getCenter(find.descendant(of: panel, matching: find.text('sand'))));
      await tester.pumpAndSettle();
      expect(rows(tester)[highlighted(tester)!].label, 'sand');
      await key(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(shown(tester, 'Colour'), 'sand');
    });
  });

  group('KakaoMultiDropdown keyboard', () {
    Future<void> focusFirst(WidgetTester tester) async {
      await key(tester, LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
    }

    testWidgets('typing a date moves on box by box', (tester) async {
      useScreen(tester);
      final c = KakaoMultiDropdownController();
      await tester.pumpWidget(app(KakaoMultiDropdown.date(minYear: 1950, maxYear: 2026, controller: c)));
      await focusFirst(tester);
      expect(focused(tester, 'Day'), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit5);
      await tester.pump();
      expect(c.parts['day'], '15');
      expect(focused(tester, 'Month'), isTrue);
      // "0" waits (01 for now), "05" is complete and moves on.
      await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
      await tester.pump();
      expect(c.parts['month'], '01');
      expect(focused(tester, 'Month'), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit5);
      await tester.pump();
      expect(c.parts['month'], '05');
      expect(focused(tester, 'Year'), isTrue);
      await key(tester, LogicalKeyboardKey.arrowLeft);
      expect(focused(tester, 'Month'), isTrue);
      await key(tester, LogicalKeyboardKey.arrowRight);
      for (final k in [
        LogicalKeyboardKey.digit1,
        LogicalKeyboardKey.digit9,
        LogicalKeyboardKey.digit8,
        LogicalKeyboardKey.digit4,
      ]) {
        await tester.sendKeyEvent(k);
      }
      await tester.pump();
      expect(c.value, '15.05.1984');
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('closed: Up / Down step, Delete clears, Enter opens', (tester) async {
      useScreen(tester);
      final c = KakaoMultiDropdownController();
      await tester.pumpWidget(app(KakaoMultiDropdown(segments: variant, controller: c, panelKey: panelKey)));
      await focusFirst(tester);
      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(c.parts['size'], 'XS');
      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(c.parts['size'], 'S');
      await key(tester, LogicalKeyboardKey.arrowUp);
      expect(c.parts['size'], 'XS');
      await key(tester, LogicalKeyboardKey.arrowUp); // stays at the start
      expect(c.parts['size'], 'XS');
      await key(tester, LogicalKeyboardKey.delete);
      expect(c.parts['size'], isNull);
      await key(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(panel, findsOneWidget);
      // The first option is highlighted when nothing is chosen.
      expect(highlighted(tester), 0);
    });

    testWidgets('open: arrows, Home / End, Page keys, Enter picks, Escape closes', (tester) async {
      useScreen(tester);
      final c = KakaoMultiDropdownController();
      await tester.pumpWidget(
        app(KakaoMultiDropdown.date(minYear: 2000, maxYear: 2026, controller: c, panelKey: panelKey)),
      );
      await focusFirst(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await key(tester, LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();
      expect(panel, findsOneWidget);
      expect(highlighted(tester), 0);
      await key(tester, LogicalKeyboardKey.arrowUp); // clamped
      expect(highlighted(tester), 0);
      await key(tester, LogicalKeyboardKey.pageDown);
      expect(highlighted(tester), 8);
      await key(tester, LogicalKeyboardKey.end);
      expect(highlighted(tester), 30);
      await key(tester, LogicalKeyboardKey.arrowDown); // clamped
      expect(highlighted(tester), 30);
      await key(tester, LogicalKeyboardKey.home);
      expect(highlighted(tester), 0);
      await key(tester, LogicalKeyboardKey.arrowDown);
      await key(tester, LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      expect(c.parts['day'], '02');
      expect(focused(tester, 'Day'), isTrue);
      await key(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(highlighted(tester), 1);
      // Type-ahead jumps without picking.
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit5);
      await tester.pump();
      expect(rows(tester)[highlighted(tester)!].label, '25');
      expect(c.parts['day'], '02');
      await key(tester, LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      expect(focused(tester, 'Day'), isTrue);
      expect(c.parts['day'], '02');
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('Tab closes the list and moves on', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(app(KakaoMultiDropdown(segments: variant, panelKey: panelKey)));
      await focusFirst(tester);
      await key(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(panel, findsOneWidget);
      await key(tester, LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      expect(focused(tester, 'Colour'), isTrue);
    });

    testWidgets('keyboard focus: focus border and outline over the neighbours', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(app(KakaoMultiDropdown.date(value: '01.05.2000')));
      await focusFirst(tester);
      await key(tester, LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      final ring = find.byWidgetPredicate(
        (w) => w is DecoratedBox && ((w.decoration as BoxDecoration).border as Border?)?.top.width == st.focusWidth,
      );
      expect(ring, findsOneWidget);
      final r = tester.getRect(ring);
      final m = tester.getRect(box('Month'));
      final out = st.focusOffset + st.focusWidth;
      expect(r.left, closeTo(m.left - out, .01));
      expect(r.width, closeTo(m.width + 2 * out, .01));
    });
  });

  group('KakaoMultiDropdown motion', () {
    testWidgets('the list fades in over 140 ms; at once with reduced motion', (tester) async {
      useScreen(tester);
      for (final reduce in [false, true]) {
        await tester.pumpWidget(
          app(
            KakaoMultiDropdown(segments: variant, panelKey: panelKey),
            reduceMotion: reduce,
          ),
        );
        await tester.tap(box('Size'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.layers.whereType<OpacityLayer>().last.alpha, reduce ? 255 : lessThan(255));
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.layers.whereType<OpacityLayer>().last.alpha, 255);
        await key(tester, LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
      }
    });
  });

  test('anchored panel placement never flips for the multi dropdown', () {
    // A list with no room below still goes below (multi-dropdown.js .popup is absolute).
    const p = KakaoPanelPlacement(flip: KakaoPanelFlip.none);
    expect(
      kakaoPanelSide(const Rect.fromLTWH(0, 850, 100, 40), const Size(200, 200), const Size(1000, 900), p),
      KakaoPanelSide.bottom,
    );
  });
}
