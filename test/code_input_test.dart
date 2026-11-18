// KakaoCodeInput (code-input.js).
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakao_components/kakao_components.dart';

Widget app(Widget child, {bool reduceMotion = false, double width = 360}) => WidgetsApp(
  color: const Color(0xFFFFFFFF),
  builder: (context, _) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
    child: KakaoTheme(
      data: KakaoThemeData.light,
      child: FocusScope(
        autofocus: true,
        child: ColoredBox(
          color: const Color(0xFFFFFFFF),
          child: Stack(
            children: [Positioned(left: 40, top: 40, width: width, child: child)],
          ),
        ),
      ),
    ),
  ),
);

final st = KakaoCodeInputSettings.of(KakaoThemeData.light.colors);
Finder get field => find.byType(KakaoCodeInput);
Finder get input => find.byType(EditableText);
Finder get boxes => find.descendant(of: field, matching: find.byType(AnimatedContainer));
Finder boxAt(int i) => boxes.at(i);
BoxDecoration deco(WidgetTester tester, int i) =>
    tester.widget<AnimatedContainer>(boxAt(i)).decoration! as BoxDecoration;
TextEditingController ctrl(WidgetTester tester) => tester.widget<EditableText>(input).controller;
String value(WidgetTester tester) => ctrl(tester).text;
bool focused(WidgetTester tester) => tester.widget<EditableText>(input).focusNode.hasFocus;

/// The characters drawn in the boxes ('' for an empty one, '•' for a dot).
List<String> drawn(WidgetTester tester) => [
  for (var i = 0; i < tester.widgetList(boxes).length; i++)
    () {
      final texts = find.descendant(of: boxAt(i), matching: find.byType(Text));
      if (texts.evaluate().isNotEmpty) return tester.widget<Text>(texts).data!;
      final dots = find.descendant(
        of: boxAt(i),
        matching: find.byWidgetPredicate(
          (w) => w is Container && (w.decoration as BoxDecoration?)?.shape == BoxShape.circle,
        ),
      );
      return dots.evaluate().isNotEmpty ? '•' : '';
    }(),
];

/// The box with the focus outline, or null.
int? active(WidgetTester tester) {
  final n = tester.widgetList(boxes).length;
  for (var i = 0; i < n; i++) {
    final rings = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.ancestor(of: boxAt(i), matching: find.byType(Stack)).first,
            matching: find.byType(DecoratedBox),
          ),
        )
        .where((d) => (d.decoration as BoxDecoration).border == Border.all(color: st.focus, width: st.focusWidth));
    if (rings.isNotEmpty) return i;
  }
  return null;
}

/// Types [text] as the platform would: it replaces the selection.
Future<void> type(WidgetTester tester, String text) async {
  final v = ctrl(tester).value;
  final s = v.selection;
  tester.testTextInput.updateEditingValue(
    TextEditingValue(
      text: v.text.replaceRange(s.start, s.end, text),
      selection: TextSelection.collapsed(offset: s.start + text.length),
    ),
  );
  await tester.pump();
}

Future<void> key(WidgetTester tester, LogicalKeyboardKey k) async {
  await tester.sendKeyEvent(k);
  await tester.pump();
}

void main() {
  group('KakaoCodeInput', () {
    test('clean: separators dropped, rule, case switched, cut to length', () {
      expect(KakaoCodeInput.clean('123-456'), '123456');
      expect(KakaoCodeInput.clean('12 34 56 78'), '123456');
      expect(KakaoCodeInput.clean('1a2b3'), '123');
      expect(KakaoCodeInput.clean('ab12', type: KakaoCodeInputType.alphanumeric), 'ab12');
      expect(KakaoCodeInput.clean('äÖ1-x', type: KakaoCodeInputType.alphanumeric), 'äÖ1x');
      expect(KakaoCodeInput.clean('a1fz9', length: 4, pattern: '[0-9A-F]'), 'A1F9');
      // An invalid pattern falls back to the type's rule.
      expect(KakaoCodeInput.clean('1a', pattern: '['), '1');
      expect(KakaoCodeInput.clean('123456789', length: 20), '12345678');
      expect(KakaoCodeInput.clean('123456', length: 2), '1234');
    });

    test('groups: one size repeats, several in order', () {
      expect(KakaoCodeInput.groups(6, null), [6]);
      expect(KakaoCodeInput.groups(6, '3'), [3, 3]);
      expect(KakaoCodeInput.groups(8, '3'), [3, 3, 2]);
      expect(KakaoCodeInput.groups(8, '2-3-3'), [2, 3, 3]);
      expect(KakaoCodeInput.groups(6, '4-4'), [4, 2]);
      expect(KakaoCodeInput.groups(8, '2'), [2, 2, 2, 2]);
      expect(KakaoCodeInput.groups(6, 'x'), [6]);
    });

    testWidgets('boxes: count, size, gap, border, value drawn; sizes; label, hint', (tester) async {
      await tester.pumpWidget(app(const KakaoCodeInput(label: 'Code', value: '482', hint: 'Sent.')));
      expect(boxes, findsNWidgets(6));
      expect(tester.getSize(boxAt(0)), Size(st.boxWidth, st.height));
      expect(tester.getTopLeft(boxAt(1)).dx - tester.getTopRight(boxAt(0)).dx, st.gap);
      expect(deco(tester, 0).border, Border.all(color: st.border));
      expect(deco(tester, 0).color, st.bg);
      expect(deco(tester, 0).borderRadius, BorderRadius.circular(st.radius));
      expect(drawn(tester), ['4', '8', '2', '', '', '']);
      final style = tester.widget<Text>(find.descendant(of: boxAt(0), matching: find.text('4'))).style!;
      expect(style.fontSize, st.charSize);
      expect(style.fontWeight, FontWeight.w600);
      expect(style.fontFeatures, const [FontFeature.tabularFigures()]);
      expect(tester.getTopLeft(boxAt(0)).dy - tester.getBottomLeft(find.text('Code')).dy, st.labelGap);
      expect(tester.getTopLeft(find.text('Sent.')).dy - tester.getBottomLeft(boxAt(0)).dy, st.messageGap);
      expect(active(tester), isNull);

      for (final (size, h, w, gap, f) in [
        (KakaoCodeInputSize.sm, 36.0, 32.0, 6.0, 16.0),
        (KakaoCodeInputSize.lg, 52.0, 48.0, 10.0, 21.6),
      ]) {
        await tester.pumpWidget(app(KakaoCodeInput(size: size, length: 4, value: '1')));
        expect(boxes, findsNWidgets(4));
        expect(tester.getSize(boxAt(0)), Size(w, h));
        expect(tester.getTopLeft(boxAt(1)).dx - tester.getTopRight(boxAt(0)).dx, gap);
        expect(tester.widget<Text>(find.descendant(of: boxAt(0), matching: find.text('1'))).style!.fontSize, f);
      }

      // length is clamped to 4-8.
      await tester.pumpWidget(app(const KakaoCodeInput(length: 12)));
      expect(boxes, findsNWidgets(8));
      await tester.pumpWidget(app(const KakaoCodeInput(length: 1)));
      expect(boxes, findsNWidgets(4));
    });

    testWidgets('separator: a dash between groups, group-gap from the boxes; boxes shrink to fit', (tester) async {
      await tester.pumpWidget(app(const KakaoCodeInput(separator: '3')));
      final dash = find.descendant(
        of: field,
        matching: find.byWidgetPredicate((w) => w is Container && w.margin != null),
      );
      expect(dash, findsOneWidget);
      // The dash: 0.6em of the character size, 2 px, muted; group-gap each side.
      final dashBox = find.descendant(of: dash, matching: find.byType(DecoratedBox));
      expect(tester.getSize(dashBox), Size(st.charSize * .6, 2));
      expect(tester.getTopLeft(dashBox).dx - tester.getTopRight(boxAt(2)).dx, st.groupGap);
      expect(tester.getTopLeft(boxAt(3)).dx - tester.getTopRight(dashBox).dx, st.groupGap);
      expect(((tester.widget<DecoratedBox>(dashBox).decoration) as BoxDecoration).color, st.muted);

      // 8 boxes of 40 with 7 gaps of 8: 376 > 200, all shrink alike.
      await tester.pumpWidget(app(const KakaoCodeInput(length: 8), width: 200));
      final w = tester.getSize(boxAt(0)).width;
      expect(w, (200 - 7 * st.gap) / 8);
      expect(tester.getSize(boxAt(7)).width, w);
      expect(tester.getTopRight(boxAt(7)).dx, 240);
    });

    testWidgets('typing fills and moves on; overwrite; ignored characters; complete and change', (tester) async {
      final events = <String>[];
      await tester.pumpWidget(
        app(
          KakaoCodeInput(
            label: 'Code',
            onChanged: (v) => events.add('input $v'),
            onCompleted: (v) => events.add('complete $v'),
            onCommitted: (v) => events.add('change $v'),
          ),
        ),
      );
      await tester.tap(find.text('Code'));
      await tester.pump();
      expect(focused(tester), isTrue);
      expect(active(tester), 0);
      await type(tester, '1');
      expect(drawn(tester).first, '1');
      expect(active(tester), 1);
      await type(tester, 'x');
      expect(value(tester), '1');
      expect(active(tester), 1);
      for (final c in '23456'.split('')) {
        await type(tester, c);
      }
      expect(value(tester), '123456');
      expect(events, [
        'input 1',
        'input 12',
        'input 123',
        'input 1234',
        'input 12345',
        'input 123456',
        'complete 123456',
        'change 123456',
      ]);
      // On the last box, its character selected: typing overwrites it.
      expect(active(tester), 5);
      expect(ctrl(tester).selection, const TextSelection(baseOffset: 5, extentOffset: 6));
      events.clear();
      await type(tester, '9');
      expect(value(tester), '123459');
      expect(events, ['input 123459', 'complete 123459', 'change 123459']);

      // Overwrite in the middle.
      await key(tester, LogicalKeyboardKey.home);
      expect(active(tester), 0);
      await key(tester, LogicalKeyboardKey.arrowRight);
      await type(tester, '7');
      expect(value(tester), '173459');
      expect(active(tester), 2);

      // Leaving commits once more only when changed.
      events.clear();
      FocusManager.instance.primaryFocus!.unfocus();
      await tester.pump();
      expect(events, isEmpty);
      expect(active(tester), isNull);
    });

    testWidgets('pattern: the other case is taken; alphanumeric any letter', (tester) async {
      await tester.pumpWidget(app(const KakaoCodeInput(label: 'Hex', length: 4, pattern: '[0-9A-F]')));
      await tester.tap(find.text('Hex'));
      await tester.pump();
      await type(tester, 'a');
      await type(tester, 'g');
      await type(tester, '9');
      expect(value(tester), 'A9');
      final semantics = tester.ensureSemantics();
      expect(tester.getSemantics(input).getSemanticsData().hint, '4 characters');
      semantics.dispose();
    });

    testWidgets('Backspace clears the current box, on an empty box goes back; Delete', (tester) async {
      await tester.pumpWidget(app(const KakaoCodeInput(label: 'Code', value: '1234')));
      await tester.tap(find.text('Code'));
      await tester.pump();
      // focus(): the first empty box.
      expect(active(tester), 4);
      await key(tester, LogicalKeyboardKey.backspace);
      expect(value(tester), '123');
      expect(active(tester), 3);
      await key(tester, LogicalKeyboardKey.arrowLeft);
      await key(tester, LogicalKeyboardKey.arrowLeft);
      expect(active(tester), 1);
      await key(tester, LogicalKeyboardKey.backspace);
      // The value has no gaps: what follows moves up.
      expect(value(tester), '13');
      expect(active(tester), 1);
      await key(tester, LogicalKeyboardKey.delete);
      expect(value(tester), '1');
      expect(active(tester), 1);
    });

    testWidgets('arrows, Home / End, Up / Down stay within the filled boxes and the first empty one', (tester) async {
      await tester.pumpWidget(app(const KakaoCodeInput(label: 'Code', value: '12')));
      await tester.tap(find.text('Code'));
      await tester.pump();
      expect(active(tester), 2);
      await key(tester, LogicalKeyboardKey.arrowRight);
      expect(active(tester), 2);
      await key(tester, LogicalKeyboardKey.arrowUp);
      expect(active(tester), 0);
      await key(tester, LogicalKeyboardKey.arrowLeft);
      expect(active(tester), 0);
      await key(tester, LogicalKeyboardKey.end);
      expect(active(tester), 2);
      await key(tester, LogicalKeyboardKey.home);
      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(active(tester), 2);
    });

    testWidgets('a tap lands on its box, no further than the first empty one', (tester) async {
      await tester.pumpWidget(app(const KakaoCodeInput(value: '123')));
      await tester.tapAt(tester.getCenter(boxAt(1)));
      await tester.pump();
      expect(focused(tester), isTrue);
      expect(active(tester), 1);
      expect(ctrl(tester).selection, const TextSelection(baseOffset: 1, extentOffset: 2));
      // In the gap: the nearer box.
      await tester.tapAt(tester.getTopRight(boxAt(0)) + Offset(st.gap / 2 - 1, 10));
      await tester.pump();
      expect(active(tester), 0);
      await tester.tapAt(tester.getCenter(boxAt(5)));
      await tester.pump();
      expect(active(tester), 3);
    });

    testWidgets('paste: a whole code replaces, a shorter piece fills from the current box', (tester) async {
      final events = <String>[];
      await tester.pumpWidget(
        app(KakaoCodeInput(label: 'Code', value: '99', onCompleted: (v) => events.add('complete $v'))),
      );
      await tester.tap(find.text('Code'));
      await tester.pump();
      await key(tester, LogicalKeyboardKey.home);
      await type(tester, '12 3');
      expect(value(tester), '123');
      expect(active(tester), 3);
      await type(tester, '123-456');
      expect(value(tester), '123456');
      expect(events, ['complete 123456']);
      expect(active(tester), 5);

      // Select all (several characters): the boxes are tinted, no outline.
      ctrl(tester).selection = const TextSelection(baseOffset: 0, extentOffset: 6);
      await tester.pump();
      expect(active(tester), isNull);
      expect(deco(tester, 0).color, st.selectedBg);
      await tester.pumpAndSettle();
      await type(tester, '7');
      expect(value(tester), '7');
      expect(active(tester), 1);
      expect(deco(tester, 0).color, st.bg);
    });

    testWidgets('focus: the current box gets the focus border and outline; error: danger', (tester) async {
      await tester.pumpWidget(app(const KakaoCodeInput(label: 'Code', value: '12')));
      await tester.tap(find.text('Code'));
      await tester.pumpAndSettle();
      expect(deco(tester, 2).border, Border.all(color: st.focus));
      expect(deco(tester, 1).border, Border.all(color: st.border));

      await tester.pumpWidget(app(const KakaoCodeInput(label: 'Code', value: '12', error: 'Expired.', hint: 'H')));
      await tester.pumpAndSettle();
      expect(find.text('H'), findsNothing);
      expect(tester.widget<Text>(find.text('Expired.')).style!.color, st.danger);
      for (var i = 0; i < 6; i++) {
        expect(deco(tester, i).border, Border.all(color: st.danger));
      }
      final dangerRings = tester
          .widgetList<DecoratedBox>(find.descendant(of: field, matching: find.byType(DecoratedBox)))
          .where((d) => (d.decoration as BoxDecoration).border == Border.all(color: st.danger, width: st.focusWidth));
      expect(dangerRings, hasLength(1));
    });

    testWidgets('the caret in an empty current box blinks; steady with reduced motion; fade duration', (tester) async {
      double caretOpacity() =>
          tester.widget<Opacity>(find.descendant(of: boxAt(0), matching: find.byType(Opacity))).opacity;
      await tester.pumpWidget(app(const KakaoCodeInput(label: 'Code')));
      expect(tester.widget<AnimatedContainer>(boxAt(0)).duration, st.duration);
      expect(tester.widget<AnimatedContainer>(boxAt(0)).curve, st.ease);
      await tester.tap(find.text('Code'));
      await tester.pump();
      expect(caretOpacity(), 1);
      await tester.pump(const Duration(milliseconds: 540));
      expect(caretOpacity(), 0);
      await tester.pump(const Duration(milliseconds: 530));
      expect(caretOpacity(), 1);
      final caret = find.descendant(of: boxAt(0), matching: find.byType(Opacity));
      expect(tester.getSize(caret), Size(2, st.charSize * 1.1));

      await tester.pumpWidget(app(const KakaoCodeInput(label: 'Code'), reduceMotion: true));
      await tester.pump();
      expect(tester.widget<AnimatedContainer>(boxAt(0)).duration, Duration.zero);
      await tester.pump(const Duration(milliseconds: 540));
      expect(caretOpacity(), 1);
    });

    testWidgets('mask: dots, a password field', (tester) async {
      await tester.pumpWidget(app(const KakaoCodeInput(length: 4, mask: true, value: '12', autofillHints: [])));
      expect(drawn(tester), ['•', '•', '', '']);
      expect(find.descendant(of: boxAt(0), matching: find.text('1')), findsNothing);
      expect(tester.widget<EditableText>(input).obscureText, isTrue);
      expect(tester.widget<EditableText>(input).autofillHints, isNull);
      final dot = find.descendant(
        of: boxAt(0),
        matching: find.byWidgetPredicate(
          (w) => w is Container && (w.decoration as BoxDecoration?)?.shape == BoxShape.circle,
        ),
      );
      expect(tester.getSize(dot), Size.square(st.charSize * .5));
    });

    testWidgets('one text field in semantics: name, hint and count, invalid', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(app(const KakaoCodeInput(label: 'Verification code', hint: 'Sent.', error: 'Wrong.')));
      final data = tester.getSemantics(input).getSemanticsData();
      expect(data.label, contains('Verification code'));
      expect(data.hint, 'Sent. Wrong. 6 digits');
      expect(data.validationResult, SemanticsValidationResult.invalid);
      await tester.pumpWidget(app(const KakaoCodeInput()));
      expect(tester.getSemantics(input).getSemanticsData().label, contains('Code'));
      expect(tester.widget<EditableText>(input).keyboardType, TextInputType.number);
      expect(tester.widget<EditableText>(input).autofillHints, [AutofillHints.oneTimeCode]);
      await tester.pumpWidget(app(const KakaoCodeInput(semanticLabel: 'PIN', type: KakaoCodeInputType.alphanumeric)));
      expect(tester.getSemantics(input).getSemanticsData().label, contains('PIN'));
      expect(tester.widget<EditableText>(input).keyboardType, TextInputType.text);
      handle.dispose();
    });

    testWidgets('disabled: dimmed, not focusable; read only: focusable, not editable', (tester) async {
      final events = <String>[];
      await tester.pumpWidget(app(const KakaoCodeInput(label: 'Code', value: '12', disabled: true)));
      expect(find.byWidgetPredicate((w) => w is Opacity && w.opacity == st.disabledOpacity), findsOneWidget);
      await tester.tap(find.text('Code'));
      await tester.tapAt(tester.getCenter(boxAt(0)));
      await tester.pump();
      expect(focused(tester), isFalse);

      await tester.pumpWidget(
        app(KakaoCodeInput(label: 'Code', value: '12', readOnly: true, onChanged: (v) => events.add(v))),
      );
      await tester.tapAt(tester.getCenter(boxAt(0)));
      await tester.pump();
      expect(focused(tester), isTrue);
      expect(active(tester), 0);
      await key(tester, LogicalKeyboardKey.backspace);
      expect(value(tester), '12');
      expect(events, isEmpty);
    });

    testWidgets('controller: set text is filtered with no events; length change re-filters; Enter', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final events = <String>[];
      Widget build(int length) => app(
        KakaoCodeInput(
          label: 'Code',
          length: length,
          controller: controller,
          onChanged: (v) => events.add('input $v'),
          onCommitted: (v) => events.add('change $v'),
          onSubmitted: (v) => events.add('submit $v'),
        ),
      );
      await tester.pumpWidget(build(6));
      controller.text = '90-81-72-99';
      await tester.pump();
      expect(controller.text, '908172');
      expect(drawn(tester), ['9', '0', '8', '1', '7', '2']);
      await tester.pumpWidget(build(4));
      expect(controller.text, '9081');
      expect(events, isEmpty);

      await tester.tap(find.text('Code'));
      await tester.pump();
      controller.clear();
      await tester.pump();
      expect(active(tester), 0);
      await key(tester, LogicalKeyboardKey.enter);
      // Set from outside: the base of the next change, so Enter has nothing to commit.
      expect(events, ['submit ']);
      await type(tester, '5');
      await key(tester, LogicalKeyboardKey.enter);
      expect(events, ['submit ', 'input 5', 'change 5', 'submit 5']);
      expect(focused(tester), isTrue);
    });

    testWidgets('a new value from the owner replaces the code without events', (tester) async {
      final events = <String>[];
      await tester.pumpWidget(app(KakaoCodeInput(value: '12', onChanged: events.add)));
      await tester.pumpWidget(app(KakaoCodeInput(value: '34a5', onChanged: events.add)));
      expect(drawn(tester), ['3', '4', '5', '', '', '']);
      expect(events, isEmpty);
    });

    testWidgets('desktop: Ctrl+V pastes the clipboard; a tap on a box keeps focus, outside commits', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.getData') return {'text': ' 123 456 '};
        if (call.method == 'Clipboard.hasStrings') return {'value': true};
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      final events = <String>[];
      await tester.pumpWidget(app(KakaoCodeInput(label: 'Code', onCommitted: (v) => events.add('change $v'))));
      await tester.tapAt(tester.getCenter(boxAt(0)));
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(value(tester), '123456');
      expect(events, ['change 123456']);
      await key(tester, LogicalKeyboardKey.home);
      await key(tester, LogicalKeyboardKey.backspace);
      expect(value(tester), '23456');
      await tester.tapAt(tester.getCenter(boxAt(3)));
      await tester.pump();
      expect(focused(tester), isTrue);
      expect(active(tester), 3);
      await tester.tapAt(const Offset(5, 5));
      await tester.pump();
      expect(focused(tester), isFalse);
      expect(events, ['change 123456', 'change 23456']);
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
