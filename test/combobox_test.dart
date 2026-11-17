// KakaoCombobox (combobox.js).
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakao_components/kakao_components.dart';
import 'package:kakao_components/src/internal/kakao_field.dart';
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

// combobox/demo.html "Suggestions" (shortened), "Groups", "Free text".
const countries = [
  KakaoComboboxOption('at', label: 'Österreich'),
  KakaoComboboxOption('de', label: 'Deutschland'),
  KakaoComboboxOption('ch', label: 'Schweiz'),
  KakaoComboboxOption('li', label: 'Liechtenstein'),
];
const cities = [
  KakaoComboboxGroup('Germany', [KakaoComboboxOption('Berlin'), KakaoComboboxOption('Hamburg')]),
  KakaoComboboxGroup('Austria', [
    KakaoComboboxOption('Wien'),
    KakaoComboboxOption('Salzburg (sold out)', disabled: true),
    KakaoComboboxOption('Graz'),
  ]),
  KakaoComboboxGroup('Switzerland', [KakaoComboboxOption('Zürich')]),
];
const fruits = [
  KakaoComboboxOption('Apple'),
  KakaoComboboxOption('Apricot'),
  KakaoComboboxOption('Banana'),
  KakaoComboboxOption('Blackberry'),
];

const panelKey = Key('panel');
Finder get panel => find.byKey(panelKey);
Finder get field => find.byType(KakaoCombobox);
Finder get input => find.byType(EditableText);
final st = KakaoComboboxSettings.of(KakaoThemeData.light.colors);

Widget combobox({
  List<KakaoComboboxEntry> options = countries,
  String value = '',
  ValueChanged<KakaoComboboxChange>? onChanged,
  ValueChanged<String>? onCreate,
  ValueChanged<bool>? onOpenChanged,
  String? label = 'Country',
  String? hint,
  String? error,
  String? placeholder,
  KakaoComboboxAutocomplete autocomplete = KakaoComboboxAutocomplete.list,
  String? createLabel,
  bool noCreate = false,
  bool strict = false,
  int? maxLength,
  KakaoComboboxSize size = KakaoComboboxSize.md,
  bool disabled = false,
  KakaoComboboxController? controller,
  FocusNode? focusNode,
}) => KakaoCombobox(
  options: options,
  value: value,
  onChanged: onChanged,
  onCreate: onCreate,
  onOpenChanged: onOpenChanged,
  label: label,
  hint: hint,
  error: error,
  placeholder: placeholder,
  autocomplete: autocomplete,
  createLabel: createLabel,
  noCreate: noCreate,
  strict: strict,
  maxLength: maxLength,
  size: size,
  disabled: disabled,
  controller: controller,
  focusNode: focusNode,
  panelKey: panelKey,
);

/// The field's box (`.field`).
Finder get box => find.descendant(of: field, matching: find.byType(AnimatedContainer)).first;
BoxDecoration boxDecoration(WidgetTester tester) => tester.widget<AnimatedContainer>(box).decoration! as BoxDecoration;

/// The chevron toggle.
Finder get chevron => find.descendant(
  of: field,
  matching: find.byWidgetPredicate((w) => w is CustomPaint && w.painter is KakaoChevronPainter),
);

String text(WidgetTester tester) => tester.widget<EditableText>(input).controller.text;
TextSelection selection(WidgetTester tester) => tester.widget<EditableText>(input).controller.selection;
bool focused(WidgetTester tester) => tester.widget<EditableText>(input).focusNode.hasFocus;

/// The labels of the rows shown in the list, in order.
List<String> rows(WidgetTester tester) => [
  for (final e in find.descendant(of: find.byType(KakaoOptionList), matching: find.byType(Semantics)).evaluate())
    if ((e.widget as Semantics).properties.enabled != null) (e.widget as Semantics).properties.label!,
];

/// The highlighted row's label (the "Use" row included), from its background.
String? highlighted(WidgetTester tester) {
  for (final e in find.descendant(of: panel, matching: find.byType(AnimatedContainer)).evaluate()) {
    final w = e.widget as AnimatedContainer;
    if ((w.decoration as BoxDecoration?)?.color == st.hoverBg) {
      return (find.descendant(of: find.byWidget(w), matching: find.byType(Text)).evaluate().first.widget as Text).data;
    }
  }
  return null;
}

Future<void> key(WidgetTester tester, LogicalKeyboardKey k) async {
  await tester.sendKeyEvent(k);
  await tester.pumpAndSettle();
}

Future<void> type(WidgetTester tester, String s) async {
  await tester.enterText(input, s);
  await tester.pumpAndSettle();
}

Future<void> focus(WidgetTester tester) async {
  await tester.tap(input);
  await tester.pumpAndSettle();
}

void main() {
  group('KakaoCombobox field', () {
    testWidgets('label, value as its label, placeholder, hint; height per size', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(app(at(const Offset(40, 40), combobox(value: 'de', hint: 'Any text is kept too.'))));
      expect(find.text('Country'), findsOneWidget);
      expect(text(tester), 'Deutschland');
      expect(find.text('Any text is kept too.'), findsOneWidget);
      expect(tester.getSize(box).height, st.height);
      expect(boxDecoration(tester).border, Border.all(color: st.border));
      expect(boxDecoration(tester).borderRadius, BorderRadius.circular(st.radius));
      expect(tester.getTopLeft(box).dy - tester.getBottomLeft(find.text('Country')).dy, st.labelGap);
      expect(tester.getTopLeft(find.text('Any text is kept too.')).dy - tester.getBottomLeft(box).dy, st.messageGap);
      // The text starts padding-x in; the chevron ends padding-x from the edge.
      expect(tester.getTopLeft(input).dx - tester.getTopLeft(box).dx, st.paddingX + 1);
      expect(tester.getTopRight(box).dx - tester.getTopRight(chevron).dx, st.paddingX + 1);
      expect(tester.getSize(chevron).width, st.chevronSize.of(st.font.size));

      // Free text shows itself.
      await tester.pumpWidget(app(at(const Offset(40, 40), combobox(value: 'Bremen'))));
      expect(text(tester), 'Bremen');

      await tester.pumpWidget(app(at(const Offset(40, 40), combobox(placeholder: 'Pick or type a country'))));
      expect(tester.widget<Text>(find.text('Pick or type a country')).style!.color, st.muted);

      for (final (size, h) in [(KakaoComboboxSize.sm, 36.0), (KakaoComboboxSize.lg, 52.0)]) {
        await tester.pumpWidget(app(at(const Offset(40, 40), combobox(size: size))));
        expect(tester.getSize(box).height, h);
      }
    });

    testWidgets('focus: focus border and the 2 px outline; error: danger border, message, invalid', (tester) async {
      useScreen(tester);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(app(at(const Offset(40, 40), combobox(hint: 'A hint'))));
      await tester.tap(find.text('Country'));
      await tester.pumpAndSettle();
      expect(focused(tester), isTrue);
      expect(boxDecoration(tester).border, Border.all(color: st.focus));
      Iterable<BoxDecoration> rings(Color c) => tester
          .widgetList<DecoratedBox>(find.descendant(of: field, matching: find.byType(DecoratedBox)))
          .map((d) => d.decoration as BoxDecoration)
          .where((d) => d.border == Border.all(color: c, width: st.focusWidth));
      expect(rings(st.focus).single.borderRadius, BorderRadius.circular(st.radius + st.focusOffset + st.focusWidth));
      // The label's tap also opens the list (a click on the input).
      expect(panel, findsOneWidget);

      await tester.pumpWidget(app(at(const Offset(40, 40), combobox(hint: 'A hint', error: 'Pick or name a plan.'))));
      await tester.pumpAndSettle();
      expect(find.text('A hint'), findsNothing);
      expect(tester.widget<Text>(find.text('Pick or name a plan.')).style!.color, st.danger);
      expect(boxDecoration(tester).border, Border.all(color: st.danger));
      final data = tester.getSemantics(input).getSemanticsData();
      expect(data.validationResult, SemanticsValidationResult.invalid);
      expect(data.hint, 'Pick or name a plan.');
      expect(data.label, contains('Country'));
      await focus(tester);
      expect(boxDecoration(tester).border, Border.all(color: st.danger));
      expect(rings(st.danger), hasLength(1));
      handle.dispose();
    });

    testWidgets('disabled: dimmed, not focusable, does not open', (tester) async {
      useScreen(tester);
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(app(at(const Offset(40, 40), combobox(disabled: true, value: 'de', focusNode: node))));
      expect(
        tester.widget<Opacity>(find.ancestor(of: box, matching: find.byType(Opacity)).first).opacity,
        st.disabledOpacity,
      );
      await tester.tap(input, warnIfMissed: false);
      await tester.tap(chevron, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      node.requestFocus();
      await tester.pump();
      expect(node.hasFocus, isFalse);
    });
  });

  group('KakaoCombobox list', () {
    testWidgets('a tap in the field opens it below, as wide as the field; all suggestions, none highlighted', (
      tester,
    ) async {
      useScreen(tester);
      final changes = <bool>[];
      await tester.pumpWidget(app(at(const Offset(40, 40), combobox(value: 'de', onOpenChanged: changes.add))));
      await focus(tester);
      expect(changes, [true]);
      final f = tester.getRect(box);
      final p = tester.getRect(panel);
      expect(p.top, f.bottom + st.panelOffset);
      expect(p.left, f.left);
      expect(p.width, f.width);
      expect(rows(tester), ['Österreich', 'Deutschland', 'Schweiz', 'Liechtenstein']);
      // The current value is marked (check, 600) but not highlighted.
      expect(highlighted(tester), isNull);
      expect(
        tester
            .widgetList<CustomPaint>(find.descendant(of: panel, matching: find.byType(CustomPaint)))
            .map((c) => c.painter)
            .whereType<KakaoCheckPainter>()
            .single
            .color,
        st.check,
      );
      final deText = tester.widget<Text>(find.descendant(of: panel, matching: find.text('Deutschland')));
      expect(deText.style!.fontVariations, [const FontVariation.weight(600)]);
      expect(focused(tester), isTrue);
      // The panel: radius, shadow, padding from the settings.
      final deco = tester.widget<Container>(find.descendant(of: panel, matching: find.byType(Container)).first);
      expect((deco.decoration! as BoxDecoration).boxShadow, st.panelShadow);
      expect((deco.decoration! as BoxDecoration).borderRadius, BorderRadius.circular(st.panelRadius));

      // The chevron closes it; focus stays in the field.
      await tester.tap(chevron);
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      expect(changes, [true, false]);
      expect(focused(tester), isTrue);
      await tester.tap(chevron);
      await tester.pumpAndSettle();
      expect(panel, findsOneWidget);
    });

    testWidgets('typing filters, case and accents ignored; groups without matches hide; empty text', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(app(at(const Offset(40, 40), combobox(options: cities, label: 'City', noCreate: true))));
      await focus(tester);
      await type(tester, 'zur');
      expect(rows(tester), ['Zürich']);
      expect(find.descendant(of: panel, matching: find.text('Switzerland')), findsOneWidget);
      expect(find.descendant(of: panel, matching: find.text('Germany')), findsNothing);
      // Typing does not highlight.
      expect(highlighted(tester), isNull);
      await type(tester, 'xyz');
      expect(rows(tester), isEmpty);
      expect(find.text('No matches'), findsOneWidget);
      // The status reports the matches after 400 ms.
      await type(tester, 'BERL');
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.liveRegion == true && w.properties.label == '1 suggestion',
        ),
        findsOneWidget,
      );
    });

    testWidgets('autocomplete none: not filtered', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(
        app(at(const Offset(40, 40), combobox(autocomplete: KakaoComboboxAutocomplete.none, noCreate: true))),
      );
      await focus(tester);
      await type(tester, 'sch');
      expect(rows(tester), hasLength(4));
    });

    testWidgets('opens above near the bottom edge', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(app(at(const Offset(40, 700), combobox())));
      await focus(tester);
      expect(tester.getRect(panel).bottom, tester.getRect(box).top - st.panelOffset);
    });

    testWidgets('reduced motion: shown at once', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(app(at(const Offset(40, 40), combobox()), reduceMotion: true));
      await tester.tap(input);
      await tester.pump();
      await tester.pump();
      final opacity = tester.widgetList<FadeTransition>(
        find.ancestor(of: panel, matching: find.byType(FadeTransition)),
      );
      for (final o in opacity) {
        expect(o.opacity.value, 1);
      }
      expect(tester.getRect(panel).top, tester.getRect(box).bottom + st.panelOffset);
    });
  });

  group('KakaoCombobox free text', () {
    testWidgets('a "Use" row first; picking it keeps the text; combobox-create', (tester) async {
      useScreen(tester);
      final changes = <KakaoComboboxChange>[];
      final created = <String>[];
      await tester.pumpWidget(
        app(at(const Offset(40, 40), combobox(options: cities, onChanged: changes.add, onCreate: created.add))),
      );
      await focus(tester);
      await type(tester, 'Bremen');
      expect(find.text('Use “Bremen”'), findsOneWidget);
      expect(find.text('No matches'), findsNothing);
      await tester.tap(find.text('Use “Bremen”'));
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      expect(text(tester), 'Bremen');
      expect(changes.single.value, 'Bremen');
      expect(changes.single.option, isNull);
      expect(changes.single.previous, '');
      expect(created, ['Bremen']);
      expect(focused(tester), isTrue);
    });

    testWidgets('an exact match (case ignored) shows no "Use" row; create-label', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(app(at(const Offset(40, 40), combobox(options: cities, createLabel: 'Create “{text}”'))));
      await focus(tester);
      await type(tester, 'berlin');
      expect(find.textContaining('Create'), findsNothing);
      await type(tester, 'Ber');
      expect(find.text('Create “Ber”'), findsOneWidget);
    });

    testWidgets('no-create: no row, but Enter keeps free text', (tester) async {
      useScreen(tester);
      final changes = <KakaoComboboxChange>[];
      await tester.pumpWidget(app(at(const Offset(40, 40), combobox(noCreate: true, onChanged: changes.add))));
      await focus(tester);
      await type(tester, 'Bremen');
      expect(find.textContaining('Use'), findsNothing);
      await key(tester, LogicalKeyboardKey.enter);
      expect(changes.single.value, 'Bremen');
      expect(panel, findsNothing);
    });

    testWidgets('strict: no row, unlisted text goes back to the last value', (tester) async {
      useScreen(tester);
      final changes = <KakaoComboboxChange>[];
      await tester.pumpWidget(
        app(at(const Offset(40, 40), combobox(strict: true, value: 'de', onChanged: changes.add))),
      );
      await focus(tester);
      await type(tester, 'Bremen');
      expect(find.textContaining('Use'), findsNothing);
      await key(tester, LogicalKeyboardKey.enter);
      expect(text(tester), 'Deutschland');
      expect(changes, isEmpty);
      // Listed text (accents ignored) picks the option.
      await type(tester, 'osterreich');
      await key(tester, LogicalKeyboardKey.enter);
      expect(text(tester), 'Österreich');
      expect(changes.single.value, 'at');
      expect(changes.single.option!.label, 'Österreich');
      expect(changes.single.previous, 'de');
    });
  });

  group('KakaoCombobox keyboard', () {
    testWidgets('Down opens on the current value; Up / Down move and stop at the ends; Enter picks', (tester) async {
      useScreen(tester);
      final changes = <KakaoComboboxChange>[];
      await tester.pumpWidget(app(at(const Offset(40, 40), combobox(value: 'ch', onChanged: changes.add))));
      final node = tester.widget<EditableText>(input).focusNode..requestFocus();
      await tester.pumpAndSettle();
      expect(node.hasFocus, isTrue);
      expect(panel, findsNothing);
      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(panel, findsOneWidget);
      expect(highlighted(tester), 'Schweiz');
      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(highlighted(tester), 'Liechtenstein');
      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(highlighted(tester), 'Liechtenstein');
      await key(tester, LogicalKeyboardKey.pageUp);
      expect(highlighted(tester), 'Österreich');
      await key(tester, LogicalKeyboardKey.arrowUp);
      expect(highlighted(tester), 'Österreich');
      await key(tester, LogicalKeyboardKey.arrowDown);
      await key(tester, LogicalKeyboardKey.enter);
      expect(panel, findsNothing);
      expect(text(tester), 'Deutschland');
      expect(changes.single.value, 'de');
      expect(node.hasFocus, isTrue);
    });

    testWidgets('Alt+Down opens without a highlight, Alt+Up closes; disabled rows are skipped', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(app(at(const Offset(40, 40), combobox(options: cities))));
      tester.widget<EditableText>(input).focusNode.requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(panel, findsOneWidget);
      expect(highlighted(tester), isNull);
      await key(tester, LogicalKeyboardKey.arrowUp);
      expect(panel, findsNothing);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();
      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(highlighted(tester), 'Berlin');
      for (var i = 0; i < 3; i++) {
        await key(tester, LogicalKeyboardKey.arrowDown);
      }
      // Berlin, Hamburg, Wien, (Salzburg skipped) Graz.
      expect(highlighted(tester), 'Graz');
    });

    testWidgets('the "Use" row is the first the arrows reach', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(app(at(const Offset(40, 40), combobox(options: cities))));
      await focus(tester);
      await type(tester, 'Ham');
      expect(highlighted(tester), isNull);
      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(highlighted(tester), 'Use “Ham”');
      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(highlighted(tester), 'Hamburg');
      await key(tester, LogicalKeyboardKey.arrowUp);
      await key(tester, LogicalKeyboardKey.enter);
      expect(text(tester), 'Ham');
    });

    testWidgets('Escape closes, then clears; Tab commits and moves on', (tester) async {
      useScreen(tester);
      final changes = <KakaoComboboxChange>[];
      final next = FocusNode();
      addTearDown(next.dispose);
      await tester.pumpWidget(
        app(
          Column(
            children: [
              SizedBox(
                width: 260,
                child: combobox(value: 'de', onChanged: changes.add),
              ),
              Focus(focusNode: next, child: const SizedBox(width: 10, height: 10)),
            ],
          ),
        ),
      );
      await focus(tester);
      expect(panel, findsOneWidget);
      await key(tester, LogicalKeyboardKey.escape);
      expect(panel, findsNothing);
      expect(text(tester), 'Deutschland');
      await key(tester, LogicalKeyboardKey.escape);
      expect(text(tester), '');
      expect(changes.single.value, '');
      expect(changes.single.previous, 'de');

      await type(tester, 'Bremen');
      await key(tester, LogicalKeyboardKey.tab);
      expect(changes.last.value, 'Bremen');
      expect(next.hasFocus, isTrue);
      expect(panel, findsNothing);
    });

    testWidgets('leaving the field commits; a pointer down outside closes', (tester) async {
      useScreen(tester);
      final changes = <KakaoComboboxChange>[];
      await tester.pumpWidget(app(at(const Offset(40, 40), combobox(onChanged: changes.add))));
      await focus(tester);
      await type(tester, 'schweiz');
      expect(panel, findsOneWidget);
      await tester.tapAt(const Offset(390, 790));
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      expect(focused(tester), isFalse);
      expect(changes.single.value, 'ch');
      expect(text(tester), 'Schweiz');
    });
  });

  group('KakaoCombobox pointer', () {
    testWidgets('hover highlights, a tap picks, focus stays', (tester) async {
      useScreen(tester);
      final changes = <KakaoComboboxChange>[];
      await tester.pumpWidget(app(at(const Offset(40, 40), combobox(onChanged: changes.add))));
      await focus(tester);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.descendant(of: panel, matching: find.text('Schweiz'))));
      await tester.pumpAndSettle();
      expect(highlighted(tester), 'Schweiz');
      await tester.tap(find.descendant(of: panel, matching: find.text('Schweiz')));
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      expect(text(tester), 'Schweiz');
      expect(changes.single.value, 'ch');
      expect(focused(tester), isTrue);
    });
  });

  group('KakaoCombobox inline completion', () {
    testWidgets('autocomplete both: completes the first match, the rest selected; Escape drops it', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(
        app(at(const Offset(40, 40), combobox(options: fruits, autocomplete: KakaoComboboxAutocomplete.both))),
      );
      await focus(tester);
      await type(tester, 'b');
      // The typed part keeps its case (combobox.js: typed + the label's rest).
      expect(text(tester), 'banana');
      expect(selection(tester), const TextSelection(baseOffset: 1, extentOffset: 6));
      // The list is filtered by the typed part; the completed row is highlighted.
      expect(rows(tester), ['Banana', 'Blackberry']);
      expect(highlighted(tester), 'Banana');
      await key(tester, LogicalKeyboardKey.escape);
      expect(panel, findsNothing);
      expect(text(tester), 'b');
    });

    testWidgets('Backspace removes the completion instead of completing again', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(
        app(at(const Offset(40, 40), combobox(options: fruits, autocomplete: KakaoComboboxAutocomplete.both))),
      );
      await focus(tester);
      await type(tester, 'ap');
      expect(text(tester), 'apple');
      // The selected rest deleted: the edit is no insertion.
      await type(tester, 'ap');
      expect(text(tester), 'ap');
      expect(rows(tester), ['Apple', 'Apricot']);
      expect(find.text('Use “ap”'), findsOneWidget);
    });

    testWidgets('Enter picks the completion; maxlength limits typing', (tester) async {
      useScreen(tester);
      final changes = <KakaoComboboxChange>[];
      await tester.pumpWidget(
        app(
          at(
            const Offset(40, 40),
            combobox(options: fruits, autocomplete: KakaoComboboxAutocomplete.both, onChanged: changes.add),
          ),
        ),
      );
      await focus(tester);
      await type(tester, 'apr');
      await key(tester, LogicalKeyboardKey.enter);
      expect(text(tester), 'Apricot');
      expect(changes.single.value, 'Apricot');

      await tester.pumpWidget(app(at(const Offset(40, 40), combobox(maxLength: 5))));
      await focus(tester);
      await type(tester, '1234567');
      expect(text(tester), '12345');
    });
  });

  group('KakaoCombobox owner', () {
    testWidgets('a new value from the owner shows without reporting; controller opens', (tester) async {
      useScreen(tester);
      final changes = <KakaoComboboxChange>[];
      final controller = KakaoComboboxController();
      addTearDown(controller.dispose);
      Widget build(String v) =>
          app(at(const Offset(40, 40), combobox(value: v, onChanged: changes.add, controller: controller)));
      await tester.pumpWidget(build('de'));
      await tester.pumpWidget(build('at'));
      expect(text(tester), 'Österreich');
      expect(changes, isEmpty);
      controller.open();
      await tester.pumpAndSettle();
      expect(panel, findsOneWidget);
      controller.close();
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
    });

    testWidgets('more contrast: the field and panel take the high-contrast roles', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(app(at(const Offset(40, 40), combobox()), highContrast: true));
      final hc = KakaoComboboxSettings.of(KakaoThemeData.light.highContrast);
      expect(boxDecoration(tester).border, Border.all(color: hc.border));
    });
  });
}
