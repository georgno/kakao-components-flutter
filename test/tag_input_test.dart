// KakaoTagInput (tag-input.js).
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakao_components/kakao_components.dart';
import 'package:kakao_components/src/internal/kakao_chip.dart';
import 'package:kakao_components/src/internal/kakao_field.dart';
import 'package:kakao_components/src/internal/kakao_option_list.dart';

const _screen = Size(400, 800);

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
              builder: (_) => ColoredBox(color: const Color(0xFFFFFFFF), child: child),
            ),
          ],
        ),
      ),
    ),
  ),
);

/// [child] [width] wide at (40, 40).
Widget place(Widget child, {double width = 300}) => Stack(
  children: [Positioned(left: 40, top: 40, width: width, child: child)],
);

void useScreen(WidgetTester tester) {
  tester.view.physicalSize = _screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

const panelKey = Key('panel');
Finder get panel => find.byKey(panelKey);
Finder get field => find.byType(KakaoTagInput);
Finder get input => find.byType(EditableText);
Finder get box => find.descendant(of: field, matching: find.byType(AnimatedContainer)).first;
Finder chip(String label) => find.ancestor(of: find.text(label), matching: find.byType(KakaoChipView));
Finder remove(String label) => find.bySemanticsLabel('Remove $label');
final st = KakaoTagInputSettings.of(KakaoThemeData.light.colors);
final chipSt = KakaoChipSettings.of(KakaoThemeData.light.colors);

String text(WidgetTester tester) => tester.widget<EditableText>(input).controller.text;
bool inputFocused(WidgetTester tester) => tester.widget<EditableText>(input).focusNode.hasFocus;
BoxDecoration boxDecoration(WidgetTester tester) => tester.widget<AnimatedContainer>(box).decoration! as BoxDecoration;

/// The chips' labels, in order.
List<String> tags(WidgetTester tester) => [
  for (final e in find.byType(KakaoChipView).evaluate()) (e.widget as KakaoChipView).label,
];

/// The fill of [label]'s chip.
Color? fill(WidgetTester tester, String label) {
  final c = find.descendant(of: chip(label), matching: find.byType(Container)).first;
  return (tester.widget<Container>(c).decoration as BoxDecoration?)?.color;
}

/// The labels of the suggestion rows.
List<String> rows(WidgetTester tester) => [
  for (final e in find.descendant(of: find.byType(KakaoOptionList), matching: find.byType(Text)).evaluate())
    (e.widget as Text).data!,
];

Future<void> key(WidgetTester tester, LogicalKeyboardKey k) async {
  await tester.sendKeyEvent(k);
  await tester.pumpAndSettle();
}

Future<void> type(WidgetTester tester, String s) async {
  await tester.enterText(input, s);
  await tester.pumpAndSettle();
}

const labels = ['Bug', 'Feature', 'Docs', 'Design', 'Performance', 'Security'];

void main() {
  group('KakaoTagInput field', () {
    testWidgets('label, chips, hint; one line per size; the text starts where the text input\'s does', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(
        app(place(const KakaoTagInput(label: 'Keywords', values: ['ab', 'cd'], hint: 'Enter adds.'))),
      );
      expect(find.text('Keywords'), findsOneWidget);
      expect(tags(tester), ['ab', 'cd']);
      expect(find.text('Enter adds.'), findsOneWidget);
      expect(tester.getSize(box).height, st.height);
      expect(boxDecoration(tester).border, Border.all(color: st.border));
      expect(boxDecoration(tester).borderRadius, BorderRadius.circular(st.radius));
      // --_inset: (44 - 2 - 24) / 2 = 9 from the border; chips centred.
      expect(tester.getTopLeft(chip('ab')).dx - tester.getTopLeft(box).dx, 1 + 9);
      expect(tester.getSize(chip('ab')).height, chipSt.height);
      expect(tester.getCenter(chip('ab')).dy, tester.getCenter(box).dy);
      expect(tester.getTopLeft(chip('cd')).dx - tester.getTopRight(chip('ab')).dx, st.gap);
      // The chip's fill and corners.
      expect(fill(tester, 'ab'), chipSt.bg);

      // No tags: placeholder, the text padding-x in.
      await tester.pumpWidget(app(place(const KakaoTagInput(label: 'Topics', placeholder: 'Add a topic'))));
      expect(find.text('Add a topic'), findsOneWidget);
      expect(tester.getTopLeft(input).dx - tester.getTopLeft(box).dx, 1 + st.paddingX);
      // With tags the placeholder goes.
      await tester.pumpWidget(app(place(const KakaoTagInput(placeholder: 'Add a topic', values: ['a']))));
      expect(find.text('Add a topic'), findsNothing);

      for (final (size, h) in [(KakaoTagInputSize.sm, 36.0), (KakaoTagInputSize.lg, 52.0)]) {
        await tester.pumpWidget(app(place(KakaoTagInput(size: size, values: const ['x']))));
        expect(tester.getSize(box).height, h);
        expect(tester.getCenter(chip('x')).dy, tester.getCenter(box).dy);
      }
    });

    testWidgets('many tags wrap; the text takes the rest of the last line, or a line of its own', (tester) async {
      useScreen(tester);
      const many = ['Flour', 'Sugar', 'Butter', 'Eggs', 'Milk', 'Vanilla extract', 'Baking powder', 'Salt'];
      await tester.pumpWidget(app(place(const KakaoTagInput(values: many))));
      final top = tester.getTopLeft(chip('Flour')).dy;
      expect(tester.getSize(box).height, greaterThan(st.height));
      expect(tester.getTopLeft(chip('Salt')).dy, greaterThan(top));
      // Lines of chips: chip height + row gap apart.
      final second = many.firstWhere((t) => tester.getTopLeft(chip(t)).dy > top);
      expect(tester.getTopLeft(chip(second)).dy - top, chipSt.height + st.rowGap);
      // The text reaches the end of the field (less the padding).
      expect(tester.getTopRight(box).dx - tester.getTopRight(input).dx, 1 + st.paddingX);
      expect(tester.getSize(input).width, greaterThanOrEqualTo(st.textMinWidth));
      expect(tester.getSize(find.byType(KakaoFieldText)).height, st.height - 2 - 2 * st.paddingY);
    });

    testWidgets('focus: focus border and outline; error: danger border and message, invalid', (tester) async {
      useScreen(tester);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(app(place(const KakaoTagInput(label: 'Tags', values: ['a']))));
      await tester.tap(find.text('Tags'));
      await tester.pumpAndSettle();
      expect(inputFocused(tester), isTrue);
      expect(boxDecoration(tester).border, Border.all(color: st.focus));
      expect(
        find.byWidgetPredicate(
          (w) => w is DecoratedBox && (w.decoration as BoxDecoration).border == Border.all(color: st.focus, width: 2),
        ),
        findsOneWidget,
      );

      await tester.pumpWidget(app(place(const KakaoTagInput(label: 'Topics', error: 'Add at least one topic.'))));
      await tester.pumpAndSettle();
      expect(boxDecoration(tester).border, Border.all(color: st.danger));
      expect(tester.widget<Text>(find.text('Add at least one topic.')).style!.color, st.danger);
      expect(
        tester.getSemantics(input),
        isSemantics(
          label: 'Topics',
          hint: 'Add at least one topic.',
          validationResult: SemanticsValidationResult.invalid,
        ),
      );
      handle.dispose();
    });
  });

  group('KakaoTagInput adding', () {
    testWidgets('Enter and a delimiter add the text, tidied; change once per action', (tester) async {
      useScreen(tester);
      final changes = <List<String>>[];
      await tester.pumpWidget(app(place(KakaoTagInput(onChanged: changes.add))));
      await type(tester, '  design   system ');
      await key(tester, LogicalKeyboardKey.enter);
      expect(tags(tester), ['design system']);
      expect(text(tester), '');
      await type(tester, 'tokens,');
      expect(tags(tester), ['design system', 'tokens']);
      expect(text(tester), '');
      // The part after the delimiter stays typed.
      await type(tester, 'ab');
      await type(tester, 'a,b');
      expect(tags(tester), ['design system', 'tokens', 'a']);
      expect(text(tester), 'b');
      expect(changes, [
        ['design system'],
        ['design system', 'tokens'],
        ['design system', 'tokens', 'a'],
      ]);
      // Enter in an empty field adds nothing.
      await type(tester, '   ');
      await key(tester, LogicalKeyboardKey.enter);
      expect(tags(tester).length, 3);
    });

    testWidgets('own delimiters; a pasted list adds every part', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(app(place(const KakaoTagInput(delimiters: ',; '))));
      await type(tester, 'ann@example.com;');
      await type(tester, 'bob@example.com ');
      expect(tags(tester), ['ann@example.com', 'bob@example.com']);
      // A paste (several characters at once) adds the last part too.
      await type(tester, 'c, d, e');
      expect(tags(tester), ['ann@example.com', 'bob@example.com', 'c', 'd', 'e']);
      expect(text(tester), '');
    });

    testWidgets('Ctrl+V of lines adds each line', (tester) async {
      useScreen(tester);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.getData') return {'text': 'one\ntwo\tthree'};
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      final changes = <List<String>>[];
      await tester.pumpWidget(app(place(KakaoTagInput(onChanged: changes.add))));
      await tester.tap(input);
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(tags(tester), ['one', 'two', 'three']);
      expect(changes, [
        ['one', 'two', 'three'],
      ]);
    });

    testWidgets('a duplicate is refused: its chip flashes, the text stays; max-tags', (tester) async {
      useScreen(tester);
      final changes = <List<String>>[];
      await tester.pumpWidget(
        app(place(KakaoTagInput(values: const ['CSS', 'JavaScript'], maxTags: 3, onChanged: changes.add))),
      );
      await type(tester, 'css');
      await key(tester, LogicalKeyboardKey.enter);
      expect(tags(tester), ['CSS', 'JavaScript']);
      expect(text(tester), 'css');
      final danger = kakaoChipColors(chipSt, KakaoChipTone.danger).fill;
      expect(fill(tester, 'CSS'), danger);
      await tester.pump(const Duration(milliseconds: 950));
      expect(fill(tester, 'CSS'), chipSt.bg);

      await type(tester, 'HTML');
      await key(tester, LogicalKeyboardKey.enter);
      await type(tester, 'Dart');
      await key(tester, LogicalKeyboardKey.enter);
      expect(tags(tester), ['CSS', 'JavaScript', 'HTML']);
      expect(text(tester), 'Dart');
      expect(changes, [
        ['CSS', 'JavaScript', 'HTML'],
      ]);
    });

    testWidgets('allowDuplicates; onTagAdd false keeps the text', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(
        app(
          place(
            KakaoTagInput(
              allowDuplicates: true,
              delimiters: ';',
              values: const ['Smith, J.'],
              onTagAdd: (v) => !v.toLowerCase().startsWith('x'),
            ),
          ),
        ),
      );
      await type(tester, 'Smith, J.;');
      expect(tags(tester), ['Smith, J.', 'Smith, J.']);
      await type(tester, 'xray');
      await key(tester, LogicalKeyboardKey.enter);
      expect(tags(tester).length, 2);
      expect(text(tester), 'xray');
    });

    testWidgets('leaving the field adds the typed text', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(
        app(
          Column(
            children: [
              const SizedBox(width: 300, child: KakaoTagInput()),
              Focus(child: const SizedBox(width: 10, height: 10)),
            ],
          ),
        ),
      );
      await type(tester, 'left');
      await key(tester, LogicalKeyboardKey.tab);
      expect(tags(tester), ['left']);
      expect(inputFocused(tester), isFalse);
    });

    testWidgets('a new tag grows in from 85 %', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(app(place(const KakaoTagInput())));
      await tester.enterText(input, 'new');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      final scale = find.ancestor(of: chip('new'), matching: find.byType(Transform));
      expect(scale, findsOneWidget);
      expect(tester.widget<Transform>(scale).transform.storage[0], closeTo(.85, .02));
      await tester.pumpAndSettle();
      expect(find.ancestor(of: chip('new'), matching: find.byType(Transform)), findsNothing);
    });
  });

  group('KakaoTagInput removing and keys', () {
    testWidgets('Backspace selects the last tag, a second removes it; arrows, Home, End, typing', (tester) async {
      useScreen(tester);
      final changes = <List<String>>[];
      await tester.pumpWidget(app(place(KakaoTagInput(values: const ['a', 'b', 'c'], onChanged: changes.add))));
      await tester.tap(input);
      await tester.pumpAndSettle();
      await key(tester, LogicalKeyboardKey.backspace);
      expect(inputFocused(tester), isFalse);
      // The selected tag turns ink, its ✕ shows the outline.
      expect(fill(tester, 'c'), st.selectedBg);
      expect(tester.widget<KakaoChipView>(chip('c')).removeRing, isTrue);
      await key(tester, LogicalKeyboardKey.arrowLeft);
      expect(fill(tester, 'b'), st.selectedBg);
      expect(fill(tester, 'c'), chipSt.bg);
      await key(tester, LogicalKeyboardKey.home);
      expect(fill(tester, 'a'), st.selectedBg);
      await key(tester, LogicalKeyboardKey.arrowRight);
      await key(tester, LogicalKeyboardKey.arrowRight);
      await key(tester, LogicalKeyboardKey.arrowRight);
      expect(inputFocused(tester), isTrue);
      await key(tester, LogicalKeyboardKey.arrowLeft);
      await key(tester, LogicalKeyboardKey.backspace);
      expect(tags(tester), ['a', 'b']);
      expect(fill(tester, 'b'), st.selectedBg);
      await key(tester, LogicalKeyboardKey.home);
      await key(tester, LogicalKeyboardKey.delete);
      expect(tags(tester), ['b']);
      expect(fill(tester, 'b'), st.selectedBg);
      expect(changes, [
        ['a', 'b'],
        ['b'],
      ]);
      // Typing goes back to the text and types there.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyX, character: 'x');
      await tester.pumpAndSettle();
      expect(inputFocused(tester), isTrue);
      expect(text(tester), 'x');
      // Left in the middle of the text stays with the caret; End returns.
      await key(tester, LogicalKeyboardKey.arrowLeft);
      expect(inputFocused(tester), isTrue);
      await key(tester, LogicalKeyboardKey.arrowLeft);
      expect(inputFocused(tester), isFalse);
      await key(tester, LogicalKeyboardKey.end);
      expect(inputFocused(tester), isTrue);
    });

    testWidgets('a tap on the ✕ removes the tag; onTagRemove false keeps it', (tester) async {
      useScreen(tester);
      final handle = tester.ensureSemantics();
      final changes = <List<String>>[];
      await tester.pumpWidget(
        app(
          place(KakaoTagInput(values: const ['keep', 'go'], onTagRemove: (v) => v != 'keep', onChanged: changes.add)),
        ),
      );
      await tester.tap(remove('go'));
      await tester.pumpAndSettle();
      expect(tags(tester), ['keep']);
      // Focus moves on: no tag after it, so the text.
      expect(inputFocused(tester), isTrue);
      await tester.tap(remove('keep'));
      await tester.pumpAndSettle();
      expect(tags(tester), ['keep']);
      expect(changes, [
        ['keep'],
      ]);
      handle.dispose();
    });

    testWidgets('read only and disabled: no ✕; read only tags are still reached by keys', (tester) async {
      useScreen(tester);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(app(place(const KakaoTagInput(readOnly: true, values: ['Locked', 'Shown']))));
      expect(remove('Locked'), findsNothing);
      await tester.tap(input);
      await tester.pumpAndSettle();
      await key(tester, LogicalKeyboardKey.backspace);
      expect(fill(tester, 'Shown'), st.selectedBg);
      await key(tester, LogicalKeyboardKey.backspace);
      expect(tags(tester), ['Locked', 'Shown']);

      await tester.pumpWidget(app(place(const KakaoTagInput(disabled: true, values: ['One', 'Two']))));
      expect(remove('One'), findsNothing);
      expect(
        find.ancestor(of: field, matching: find.byType(Opacity)).evaluate().isEmpty &&
            find.descendant(of: field, matching: find.byType(Opacity)).evaluate().isNotEmpty,
        isTrue,
      );
      expect(
        tester.widget<Opacity>(find.descendant(of: field, matching: find.byType(Opacity)).first).opacity,
        st.disabledOpacity,
      );
      await tester.tap(box, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(inputFocused(tester), isFalse);
      handle.dispose();
    });
  });

  group('KakaoTagInput suggestions', () {
    testWidgets('typing opens the matches that are not tags yet; Down / Enter picks; Escape closes', (tester) async {
      useScreen(tester);
      final changes = <List<String>>[];
      await tester.pumpWidget(
        app(
          place(
            KakaoTagInput(values: const ['Design'], suggestions: labels, onChanged: changes.add, panelKey: panelKey),
          ),
        ),
      );
      await type(tester, 'e');
      expect(panel, findsOneWidget);
      // Design is a tag already.
      expect(rows(tester), ['Feature', 'Performance', 'Security']);
      expect(boxDecoration(tester).border, Border.all(color: st.focus));
      // Below the field, panel-offset away, as wide as the field.
      expect(tester.getTopLeft(panel).dy - tester.getBottomLeft(box).dy, st.panelOffset);
      expect(tester.getSize(panel).width, tester.getSize(box).width);
      await key(tester, LogicalKeyboardKey.arrowDown);
      await key(tester, LogicalKeyboardKey.arrowDown);
      await key(tester, LogicalKeyboardKey.enter);
      expect(tags(tester), ['Design', 'Performance']);
      expect(text(tester), '');
      expect(panel, findsNothing);
      expect(changes, [
        ['Design', 'Performance'],
      ]);

      await type(tester, 'sec');
      expect(rows(tester), ['Security']);
      await key(tester, LogicalKeyboardKey.escape);
      expect(panel, findsNothing);
      expect(text(tester), 'sec');
      // Nothing matches: no panel; free text still works.
      await type(tester, 'zzz');
      expect(panel, findsNothing);
      await key(tester, LogicalKeyboardKey.enter);
      expect(tags(tester), ['Design', 'Performance', 'zzz']);
      // Down on an empty field opens every suggestion left.
      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(rows(tester), ['Bug', 'Feature', 'Docs', 'Security']);
      // Up wraps to the last.
      await key(tester, LogicalKeyboardKey.arrowUp);
      await key(tester, LogicalKeyboardKey.enter);
      expect(tags(tester).last, 'Security');
    });

    testWidgets('a tap on a suggestion adds it and keeps focus in the text', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(app(place(const KakaoTagInput(suggestions: labels, panelKey: panelKey))));
      await type(tester, 'do');
      await tester.tap(find.descendant(of: panel, matching: find.text('Docs')));
      await tester.pumpAndSettle();
      expect(tags(tester), ['Docs']);
      expect(panel, findsNothing);
      expect(inputFocused(tester), isTrue);
    });
  });

  group('KakaoTagInput owner and API', () {
    testWidgets('controller calls report nothing; new values from the owner replace the tags', (tester) async {
      useScreen(tester);
      final changes = <List<String>>[];
      final c = KakaoTagInputController();
      await tester.pumpWidget(
        app(place(KakaoTagInput(controller: c, values: const ['alpha', 'beta'], maxTags: 4, onChanged: changes.add))),
      );
      expect(c.add('gamma'), isTrue);
      expect(c.add('ALPHA'), isFalse);
      await tester.pump();
      expect(tags(tester), ['alpha', 'beta', 'gamma']);
      expect(c.remove('Beta'), isTrue);
      expect(c.remove('nope'), isFalse);
      c.values = ['one', 'two'];
      await tester.pump();
      expect(c.values, ['one', 'two']);
      c.clear();
      await tester.pump();
      expect(tags(tester), isEmpty);
      expect(changes, isEmpty);

      await tester.pumpWidget(app(place(KakaoTagInput(controller: c, values: const ['x', 'y', 'x']))));
      expect(tags(tester), ['x', 'y']);
    });

    test('parse and join follow the value attribute', () {
      expect(KakaoTagInput.parse('design,  tokens , , theming'), ['design', 'tokens', 'theming']);
      expect(KakaoTagInput.parse('["Smith, J.", " Doe  A. "]'), ['Smith, J.', 'Doe A.']);
      expect(KakaoTagInput.parse(null), isEmpty);
      expect(KakaoTagInput.join(['a', 'b']), 'a,b');
      expect(KakaoTagInput.join(['Smith, J.', 'Doe']), '["Smith, J.","Doe"]');
    });
  });
}
