// KakaoSelect (select.js).
import 'dart:ui' show CheckedState, Tristate;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakao_components/kakao_components.dart';
import 'package:kakao_components/src/internal/kakao_option_list.dart';

const _screen = Size(400, 800);

Widget app(Widget child, {bool reduceMotion = false, bool highContrast = false}) => WidgetsApp(
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
              builder: (_) => ColoredBox(color: const Color(0xFFFFFFFF), child: child),
            ),
          ],
        ),
      ),
    ),
  ),
);

/// [child] [width] wide at [at].
Widget at(Offset at, Widget child, {double width = 260}) => Stack(
  children: [Positioned(left: at.dx, top: at.dy, width: width, child: child)],
);

void useScreen(WidgetTester tester) {
  tester.view.physicalSize = _screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

// select/demo.html "Single" (shortened) and "Groups".
const countries = [
  KakaoSelectOption('at', label: 'Österreich'),
  KakaoSelectOption('de', label: 'Deutschland'),
  KakaoSelectOption('ch', label: 'Schweiz'),
  KakaoSelectOption('li', label: 'Liechtenstein'),
];
const cities = [
  KakaoSelectGroup('Germany', [KakaoSelectOption('Berlin'), KakaoSelectOption('Hamburg')]),
  KakaoSelectGroup('Austria', [
    KakaoSelectOption('Wien'),
    KakaoSelectOption('Salzburg (sold out)', disabled: true),
    KakaoSelectOption('Graz'),
  ]),
  KakaoSelectGroup('Switzerland', [KakaoSelectOption('Zürich')]),
];
const genres = [
  KakaoSelectOption('action', label: 'Action'),
  KakaoSelectOption('comedy', label: 'Comedy'),
  KakaoSelectOption('drama', label: 'Drama'),
  KakaoSelectOption('romance', label: 'Romance'),
];

const panelKey = Key('panel');
Finder get panel => find.byKey(panelKey);
Finder get field => find.byType(KakaoSelect);
final st = KakaoSelectSettings.of(KakaoThemeData.light.colors);

Widget select({
  List<KakaoSelectEntry> options = countries,
  List<String> values = const ['de'],
  bool multiple = false,
  ValueChanged<KakaoSelectChange>? onChanged,
  ValueChanged<bool>? onOpenChanged,
  String? label = 'Country',
  String? hint,
  String? error,
  KakaoSelectSize size = KakaoSelectSize.md,
  bool disabled = false,
  KakaoSelectController? controller,
  FocusNode? focusNode,
}) => KakaoSelect(
  options: options,
  values: values,
  multiple: multiple,
  onChanged: onChanged,
  onOpenChanged: onOpenChanged,
  label: label,
  hint: hint,
  error: error,
  size: size,
  disabled: disabled,
  controller: controller,
  focusNode: focusNode,
  panelKey: panelKey,
);

/// The field's box (`.trigger`).
Finder get trigger => find.descendant(of: field, matching: find.byType(AnimatedContainer)).first;
BoxDecoration triggerBox(WidgetTester tester) => tester.widget<AnimatedContainer>(trigger).decoration! as BoxDecoration;

/// The labels of the rows shown in the panel, in order.
List<String> rows(WidgetTester tester) => [
  for (final e in find.descendant(of: find.byType(KakaoOptionList), matching: find.byType(Semantics)).evaluate())
    if ((e.widget as Semantics).properties.enabled != null) (e.widget as Semantics).properties.label!,
];

/// The highlighted row's label, from its background.
String? highlighted(WidgetTester tester) {
  for (final e
      in find.descendant(of: find.byType(KakaoOptionList), matching: find.byType(AnimatedContainer)).evaluate()) {
    final w = e.widget as AnimatedContainer;
    if ((w.decoration as BoxDecoration?)?.color == st.hoverBg) {
      return (find.descendant(of: find.byWidget(w), matching: find.byType(Text)).evaluate().first.widget as Text).data;
    }
  }
  return null;
}

Future<void> key(WidgetTester tester, LogicalKeyboardKey k) async {
  await tester.sendKeyEvent(k);
  await tester.pump();
}

Future<void> open(WidgetTester tester) async {
  await tester.tap(trigger);
  await tester.pumpAndSettle();
}

bool searchFocused(WidgetTester tester) => tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus;

void main() {
  test('fold: case and accents ignored', () {
    expect(kakaoFold('Österreich'), 'osterreich');
    expect(kakaoFold('ZÜRICH'), 'zurich');
    expect(kakaoFold('Genève'), 'geneve');
    expect(kakaoFold('Café'), 'cafe');
  });

  group('KakaoSelect field', () {
    testWidgets('label, value, placeholder, hint; height per size', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(app(at(const Offset(40, 40), select(hint: 'Type to filter'))));
      expect(find.text('Country'), findsOneWidget);
      expect(find.text('Deutschland'), findsOneWidget);
      expect(find.text('Type to filter'), findsOneWidget);
      expect(tester.getSize(trigger).height, st.height);
      expect(triggerBox(tester).border, Border.all(color: st.border));
      expect(triggerBox(tester).borderRadius, BorderRadius.circular(st.radius));
      // label-gap below the label, message-gap above the hint.
      expect(tester.getTopLeft(trigger).dy - tester.getBottomLeft(find.text('Country')).dy, st.labelGap);
      expect(tester.getTopLeft(find.text('Type to filter')).dy - tester.getBottomLeft(trigger).dy, st.messageGap);

      await tester.pumpWidget(app(at(const Offset(40, 40), select(values: const []))));
      final placeholder = tester.widget<Text>(find.text('Please select'));
      expect(placeholder.style!.color, st.muted);

      for (final (size, h) in [(KakaoSelectSize.sm, 36.0), (KakaoSelectSize.lg, 52.0)]) {
        await tester.pumpWidget(app(at(const Offset(40, 40), select(size: size))));
        expect(tester.getSize(trigger).height, h);
      }
    });

    testWidgets('error: danger border, message instead of the hint, invalid', (tester) async {
      useScreen(tester);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        app(at(const Offset(40, 40), select(values: const [], hint: 'A hint', error: 'Pick a plan to continue.'))),
      );
      expect(find.text('A hint'), findsNothing);
      expect(tester.widget<Text>(find.text('Pick a plan to continue.')).style!.color, st.danger);
      expect(triggerBox(tester).border, Border.all(color: st.danger));
      final data = tester.getSemantics(trigger).getSemanticsData();
      expect(data.validationResult, SemanticsValidationResult.invalid);
      expect(data.hint, 'Pick a plan to continue.');
      expect(data.label, 'Country, nothing selected');
      // Open, the border stays danger.
      await open(tester);
      expect(triggerBox(tester).border, Border.all(color: st.danger));
      handle.dispose();
    });

    testWidgets('disabled: dimmed, not focusable, does not open', (tester) async {
      useScreen(tester);
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(app(at(const Offset(40, 40), select(disabled: true, focusNode: focus))));
      expect(
        tester.widget<Opacity>(find.ancestor(of: trigger, matching: find.byType(Opacity)).first).opacity,
        st.disabledOpacity,
      );
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      focus.requestFocus();
      await tester.pump();
      expect(focus.hasFocus, isFalse);
    });

    testWidgets('a tap on the label focuses the field: focus border and outline', (tester) async {
      useScreen(tester);
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(app(at(const Offset(40, 40), select(focusNode: focus))));
      await tester.tap(find.text('Country'));
      await tester.pump();
      expect(focus.hasFocus, isTrue);
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
      await tester.pumpAndSettle();
      expect(triggerBox(tester).border, Border.all(color: st.focus));
      final ring = tester
          .widgetList<DecoratedBox>(find.descendant(of: field, matching: find.byType(DecoratedBox)))
          .map((d) => d.decoration as BoxDecoration)
          .where((d) => d.border == Border.all(color: st.focus, width: st.focusWidth));
      expect(ring.single.borderRadius, BorderRadius.circular(st.radius + st.focusOffset + st.focusWidth));
      final outline = tester.getRect(
        find.descendant(
          of: field,
          matching: find.byWidgetPredicate((w) => w is DecoratedBox && ring.contains(w.decoration)),
        ),
      );
      expect(outline, tester.getRect(trigger).inflate(st.focusOffset + st.focusWidth));
    });
  });

  group('KakaoSelect panel', () {
    testWidgets('a tap opens it below, as wide as the field, on the selected option; the search has focus', (
      tester,
    ) async {
      useScreen(tester);
      final changes = <bool>[];
      await tester.pumpWidget(app(at(const Offset(40, 40), select(onOpenChanged: changes.add))));
      expect(panel, findsNothing);
      await open(tester);
      expect(changes, [true]);
      final f = tester.getRect(trigger);
      final p = tester.getRect(panel);
      expect(p.top, f.bottom + st.panelOffset);
      expect(p.left, f.left);
      expect(p.width, f.width);
      expect(searchFocused(tester), isTrue);
      expect(find.text('Search'), findsOneWidget);
      expect(rows(tester), ['Österreich', 'Deutschland', 'Schweiz', 'Liechtenstein']);
      expect(highlighted(tester), 'Deutschland');
      // The selected row: check mark, weight 600.
      expect(
        tester
            .widgetList<CustomPaint>(find.descendant(of: panel, matching: find.byType(CustomPaint)))
            .map((c) => c.painter)
            .whereType<KakaoCheckPainter>()
            .single
            .color,
        st.check,
      );
      expect(tester.widget<Text>(find.text('Deutschland').last).style!.fontWeight, FontWeight.w600);
      expect(
        tester.getSize(find.ancestor(of: find.text('Schweiz'), matching: find.byType(AnimatedContainer)).first).height,
        st.optionHeight,
      );
      expect(triggerBox(tester).border, Border.all(color: st.focus));
      expect(tester.widget<AnimatedRotation>(find.byType(AnimatedRotation)).turns, .5);
      // A tap on the field closes it again.
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      expect(changes, [true, false]);
    });

    testWidgets('at least panel-min-width; no room below: above; the side stays while filtering', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(app(at(const Offset(40, 700), select(), width: 120)));
      await open(tester);
      final f = tester.getRect(trigger);
      final p = tester.getRect(panel);
      expect(p.width, st.panelMinWidth);
      expect(p.bottom, f.top - st.panelOffset);
      await tester.enterText(find.byType(EditableText), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('No matches'), findsOneWidget);
      expect(tester.getRect(panel).bottom, f.top - st.panelOffset);
    });

    testWidgets('height: at most panel-height, scrolling', (tester) async {
      useScreen(tester);
      final many = [for (var i = 0; i < 40; i++) KakaoSelectOption('p$i', label: 'Product $i')];
      await tester.pumpWidget(app(at(const Offset(40, 40), select(options: many, values: const []))));
      await open(tester);
      expect(tester.getSize(panel).height, st.panelHeight);
    });

    testWidgets('typing filters, case and accents ignored; groups hide; empty text', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(app(at(const Offset(40, 40), select(options: cities, values: const []))));
      await open(tester);
      expect(find.text('Germany'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'zur');
      await tester.pumpAndSettle();
      expect(rows(tester), ['Zürich']);
      expect(find.text('Germany'), findsNothing);
      expect(find.text('Switzerland'), findsOneWidget);
      expect(highlighted(tester), 'Zürich');
      await tester.enterText(find.byType(EditableText), 'BURG');
      await tester.pumpAndSettle();
      expect(rows(tester), ['Hamburg', 'Salzburg (sold out)']);
      await tester.enterText(find.byType(EditableText), 'xyz');
      await tester.pumpAndSettle();
      expect(rows(tester), isEmpty);
      expect(find.text('No matches'), findsOneWidget);
    });

    testWidgets('keys: Enter opens, type, Down, Enter picks; focus back on the field', (tester) async {
      useScreen(tester);
      final focus = FocusNode();
      addTearDown(focus.dispose);
      final picked = <KakaoSelectChange>[];
      await tester.pumpWidget(
        app(
          at(const Offset(40, 40), select(options: cities, values: const [], onChanged: picked.add, focusNode: focus)),
        ),
      );
      focus.requestFocus();
      await tester.pump();
      await key(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(panel, findsOneWidget);
      expect(searchFocused(tester), isTrue);
      expect(highlighted(tester), 'Berlin');
      // Down moves, skipping the disabled option; clamped at the end.
      await key(tester, LogicalKeyboardKey.arrowDown);
      await key(tester, LogicalKeyboardKey.arrowDown);
      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(highlighted(tester), 'Graz');
      await key(tester, LogicalKeyboardKey.pageDown);
      expect(highlighted(tester), 'Zürich');
      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(highlighted(tester), 'Zürich');
      await key(tester, LogicalKeyboardKey.pageUp);
      expect(highlighted(tester), 'Berlin');
      await tester.enterText(find.byType(EditableText), 'a');
      await tester.pumpAndSettle();
      expect(highlighted(tester), 'Hamburg');
      await key(tester, LogicalKeyboardKey.arrowDown);
      await key(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      expect(picked.single.values, ['Graz']);
      expect(picked.single.previous, isEmpty);
      expect(focus.hasFocus, isTrue);
      expect(find.text('Graz'), findsOneWidget);
    });

    testWidgets('a letter on the closed field opens with it in the search; Delete clears', (tester) async {
      useScreen(tester);
      final focus = FocusNode();
      addTearDown(focus.dispose);
      final picked = <KakaoSelectChange>[];
      await tester.pumpWidget(app(at(const Offset(40, 40), select(onChanged: picked.add, focusNode: focus))));
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyE, character: 'e');
      await tester.pumpAndSettle();
      expect(panel, findsOneWidget);
      expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, 'e');
      expect(rows(tester), ['Österreich', 'Deutschland', 'Schweiz', 'Liechtenstein']);
      // Not on the selected option: on the first match.
      expect(highlighted(tester), 'Österreich');
      await key(tester, LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      expect(focus.hasFocus, isTrue);
      await key(tester, LogicalKeyboardKey.delete);
      expect(picked.single.values, isEmpty);
      expect(find.text('Please select'), findsOneWidget);
      // The search is empty each time it opens.
      await key(tester, LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, '');
    });

    testWidgets('Alt+Up and Escape close with focus back; Tab closes and moves on; outside closes', (tester) async {
      useScreen(tester);
      final focus = FocusNode();
      final after = FocusNode();
      addTearDown(focus.dispose);
      addTearDown(after.dispose);
      await tester.pumpWidget(
        app(
          Stack(
            children: [
              Positioned(left: 40, top: 40, width: 260, child: select(focusNode: focus)),
              Positioned(
                left: 40,
                top: 600,
                child: Focus(focusNode: after, child: const SizedBox(width: 10, height: 10)),
              ),
            ],
          ),
        ),
      );
      focus.requestFocus();
      await tester.pump();
      await key(tester, LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(panel, findsOneWidget);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await key(tester, LogicalKeyboardKey.arrowUp);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      expect(focus.hasFocus, isTrue);

      await key(tester, LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      await key(tester, LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      expect(after.hasFocus, isTrue);

      await tester.tap(trigger);
      await tester.pumpAndSettle();
      expect(panel, findsOneWidget);
      await tester.tapAt(const Offset(390, 790));
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      expect(focus.hasFocus, isFalse);
    });

    testWidgets('a tap picks and closes; a disabled option does nothing; a new values from the owner wins', (
      tester,
    ) async {
      useScreen(tester);
      final picked = <KakaoSelectChange>[];
      await tester.pumpWidget(
        app(at(const Offset(40, 40), select(options: cities, values: const [], onChanged: picked.add))),
      );
      await open(tester);
      await tester.tap(find.text('Salzburg (sold out)'));
      await tester.pumpAndSettle();
      expect(panel, findsOneWidget);
      expect(picked, isEmpty);
      expect(tester.widget<Text>(find.text('Salzburg (sold out)')).style!.color, st.muted);
      await tester.tap(find.text('Wien'));
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      expect(picked.single.value, 'Wien');
      await tester.pumpWidget(app(at(const Offset(40, 40), select(options: cities, values: const ['Graz']))));
      expect(find.text('Graz'), findsOneWidget);
      expect(picked, hasLength(1));
    });

    testWidgets('the mouse moves the highlight', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(app(at(const Offset(40, 40), select())));
      await open(tester);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.text('Schweiz')));
      await tester.pump();
      expect(highlighted(tester), 'Schweiz');
    });

    testWidgets('the controller opens and closes it', (tester) async {
      useScreen(tester);
      final c = KakaoSelectController();
      addTearDown(c.dispose);
      await tester.pumpWidget(app(at(const Offset(40, 40), select(controller: c))));
      c.open();
      await tester.pumpAndSettle();
      expect(panel, findsOneWidget);
      c.close();
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
    });

    testWidgets('enters with fade and a 4 px slide; with reduced motion at once', (tester) async {
      useScreen(tester);
      for (final reduce in [false, true]) {
        await tester.pumpWidget(app(at(const Offset(40, 40), select()), reduceMotion: reduce));
        await tester.tap(trigger);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 20));
        expect(tester.layers.whereType<OpacityLayer>().last.alpha, reduce ? 255 : lessThan(255));
        await tester.pumpAndSettle();
        expect(tester.getRect(panel).top, tester.getRect(trigger).bottom + st.panelOffset);
        expect(
          tester.widget<AnimatedRotation>(find.byType(AnimatedRotation)).duration,
          reduce ? Duration.zero : const Duration(milliseconds: 200),
        );
      }
    });

    testWidgets('colours from the theme, more-contrast too', (tester) async {
      useScreen(tester);
      for (final hc in [false, true]) {
        await tester.pumpWidget(app(at(const Offset(40, 40), select()), highContrast: hc));
        final s = KakaoSelectSettings.of(hc ? KakaoThemeData.light.highContrast : KakaoThemeData.light.colors);
        expect(triggerBox(tester).border, Border.all(color: s.border));
        expect(triggerBox(tester).color, s.bg);
        await open(tester);
        final d =
            tester.widget<Container>(find.descendant(of: panel, matching: find.byType(Container)).first).decoration!
                as BoxDecoration;
        expect(d.color, s.panelBg);
        expect(d.boxShadow, s.panelShadow);
        expect(d.borderRadius, BorderRadius.circular(s.panelRadius));
        await tester.tapAt(const Offset(390, 790));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('semantics: a button named by label and value, expanded; a named list', (tester) async {
      useScreen(tester);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(app(at(const Offset(40, 40), select())));
      var data = tester.getSemantics(trigger).getSemanticsData();
      expect(data.label, 'Country, Deutschland');
      expect(data.flagsCollection.isExpanded, Tristate.isFalse);
      await open(tester);
      data = tester.getSemantics(trigger).getSemanticsData();
      expect(data.flagsCollection.isExpanded, Tristate.isTrue);
      expect(find.bySemanticsLabel('Search Country'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Deutschland').last).getSemanticsData().flagsCollection.isSelected,
        Tristate.isTrue,
      );
      handle.dispose();
    });
  });

  group('KakaoSelect multiple', () {
    testWidgets('picks toggle and stay open; the field reads "first +N"', (tester) async {
      useScreen(tester);
      final picked = <KakaoSelectChange>[];
      await tester.pumpWidget(
        app(
          at(
            const Offset(40, 40),
            select(options: genres, values: const ['drama'], multiple: true, onChanged: picked.add),
          ),
        ),
      );
      expect(find.text('Drama'), findsOneWidget);
      await open(tester);
      expect(find.text('Select all'), findsOneWidget);
      await tester.tap(find.text('Action'));
      await tester.pumpAndSettle();
      expect(panel, findsOneWidget);
      expect(picked.last.values, ['action', 'drama']);
      expect(picked.last.value, 'action,drama');
      expect(find.descendant(of: trigger, matching: find.text('Action')), findsOneWidget);
      expect(find.descendant(of: trigger, matching: find.text('+1')), findsOneWidget);
      // No weight change in a multiple select.
      expect(tester.widget<Text>(find.text('Action').last).style!.fontWeight, FontWeight.w400);
      await tester.tap(find.text('Action').last);
      await tester.pumpAndSettle();
      expect(picked.last.values, ['drama']);
    });

    testWidgets('select all: mixed, all, none; with a filter only the matches', (tester) async {
      useScreen(tester);
      final handle = tester.ensureSemantics();
      final picked = <KakaoSelectChange>[];
      await tester.pumpWidget(
        app(
          at(
            const Offset(40, 40),
            select(options: genres, values: const ['comedy'], multiple: true, onChanged: picked.add),
          ),
        ),
      );
      await open(tester);
      expect(
        tester.getSemantics(find.text('Select all')).getSemanticsData().flagsCollection.isChecked,
        CheckedState.mixed,
      );
      await tester.tap(find.text('Select all'));
      await tester.pumpAndSettle();
      expect(picked.last.values, ['action', 'comedy', 'drama', 'romance']);
      expect(
        tester.getSemantics(find.text('Select all')).getSemanticsData().flagsCollection.isChecked,
        CheckedState.isTrue,
      );
      await tester.tap(find.text('Select all'));
      await tester.pumpAndSettle();
      expect(picked.last.values, isEmpty);

      await tester.enterText(find.byType(EditableText), 'ma');
      await tester.pumpAndSettle();
      expect(find.text('Select all 2 matches'), findsOneWidget);
      expect(highlighted(tester), 'Drama');
      // Up from the first match goes to "Select all"; Enter toggles the matches.
      await key(tester, LogicalKeyboardKey.arrowUp);
      await key(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(picked.last.values, ['drama', 'romance']);
      expect(panel, findsOneWidget);
      handle.dispose();
    });
  });
}
