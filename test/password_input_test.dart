// KakaoPasswordInput (password-input.js).
import 'dart:ui' show Tristate;

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
        child: Overlay(
          key: UniqueKey(),
          initialEntries: [
            OverlayEntry(
              builder: (_) => ColoredBox(
                color: const Color(0xFFFFFFFF),
                child: Stack(
                  children: [Positioned(left: 40, top: 40, width: width, child: child)],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);

Finder get field => find.byType(KakaoPasswordInput);
Finder get input => find.byType(EditableText);
Finder get box => find.descendant(of: field, matching: find.byType(AnimatedContainer)).first;
Finder get toggle => find.descendant(of: field, matching: find.byType(FocusableActionDetector));
Finder get progress => find.byType(KakaoProgress);
EditableText editable(WidgetTester tester) => tester.widget<EditableText>(input);
bool focused(WidgetTester tester) => editable(tester).focusNode.hasFocus;
final st = KakaoPasswordInputSettings.of(KakaoThemeData.light.colors);

Future<void> type(WidgetTester tester, String text) async {
  await tester.enterText(input, text);
  await tester.pump();
}

void main() {
  group('KakaoPasswordInput', () {
    testWidgets('label, dots, sizes; the toggle as far from the end as from the top', (tester) async {
      await tester.pumpWidget(
        app(const KakaoPasswordInput(label: 'Password', value: 'secret', hint: 'Case sensitive.')),
      );
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Case sensitive.'), findsOneWidget);
      expect(editable(tester).obscureText, isTrue);
      expect(editable(tester).keyboardType, TextInputType.visiblePassword);
      expect(editable(tester).autofillHints, [AutofillHints.password]);
      for (final (size, h, t, p) in [
        (KakaoPasswordInputSize.sm, 36.0, 26.0, 10.0),
        (KakaoPasswordInputSize.md, st.height, st.toggleSize, st.paddingX),
        (KakaoPasswordInputSize.lg, 52.0, st.toggleSize, 14.0),
      ]) {
        await tester.pumpWidget(app(KakaoPasswordInput(size: size, value: 'x')));
        await tester.pumpAndSettle();
        expect(tester.getSize(box).height, h);
        expect(tester.getSize(toggle).width, t);
        expect(tester.getTopLeft(input).dx - tester.getTopLeft(box).dx, p + 1);
        // margin-inline-end: -(padding-x - (height - toggle-size) / 2).
        expect(tester.getTopRight(box).dx - 1 - tester.getTopRight(toggle).dx, (h - t) / 2);
        expect(tester.getCenter(toggle).dy, tester.getCenter(box).dy);
      }
      await tester.pumpWidget(app(const KakaoPasswordInput(hideToggle: true)));
      expect(toggle, findsNothing);
      expect(tester.getTopRight(box).dx - tester.getTopRight(input).dx, st.paddingX + 1);
    });

    testWidgets('the toggle shows the text, keeps focus and caret, is a pressed button', (tester) async {
      final handle = tester.ensureSemantics();
      final toggled = <bool>[];
      await tester.pumpWidget(app(KakaoPasswordInput(label: 'Password', onToggled: toggled.add)));
      await tester.tap(input);
      await tester.pump();
      await type(tester, 'hunter2');
      editable(tester).controller.selection = const TextSelection.collapsed(offset: 3);
      await tester.pump();
      final button = find.bySemanticsLabel('Show password');
      expect(tester.getSemantics(button).getSemanticsData().flagsCollection.isToggled, Tristate.isFalse);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(editable(tester).obscureText, isFalse);
      expect(toggled, [true]);
      expect(focused(tester), isTrue);
      expect(editable(tester).controller.selection, const TextSelection.collapsed(offset: 3));
      expect(tester.getSemantics(button).getSemanticsData().flagsCollection.isToggled, Tristate.isTrue);
      await tester.tap(toggle);
      await tester.pump();
      expect(editable(tester).obscureText, isTrue);
      expect(toggled, [true, false]);
      handle.dispose();
    });

    testWidgets('visible from the owner; hide-toggle hides; disabled toggle does nothing', (tester) async {
      await tester.pumpWidget(app(const KakaoPasswordInput(visible: true)));
      expect(editable(tester).obscureText, isFalse);
      await tester.pumpWidget(app(const KakaoPasswordInput(visible: true, hideToggle: true)));
      expect(editable(tester).obscureText, isTrue);
      await tester.pumpWidget(app(const KakaoPasswordInput(disabled: true, value: 'secret')));
      await tester.tap(toggle, warnIfMissed: false);
      await tester.pump();
      expect(editable(tester).obscureText, isTrue);
      expect(tester.widget<Opacity>(find.byType(Opacity).first).opacity, st.disabledOpacity);
    });

    testWidgets('keyboard: Tab reaches the toggle, its outline, Space toggles', (tester) async {
      await tester.pumpWidget(app(const KakaoPasswordInput(label: 'Password')));
      await tester.tap(input);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(focused(tester), isFalse);
      final rings = tester
          .widgetList<DecoratedBox>(find.descendant(of: toggle, matching: find.byType(DecoratedBox)))
          .map((d) => d.decoration as BoxDecoration)
          .where((d) => d.border == Border.all(color: st.focus, width: st.focusWidth));
      expect(rings, hasLength(1));
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(editable(tester).obscureText, isFalse);
    });

    testWidgets('focus and error: border, outline, invalid; change on blur, Enter submits', (tester) async {
      final handle = tester.ensureSemantics();
      final changes = <String>[];
      final submits = <String>[];
      await tester.pumpWidget(
        app(KakaoPasswordInput(label: 'Password', onCommitted: changes.add, onSubmitted: submits.add)),
      );
      await tester.tap(find.text('Password'));
      await tester.pumpAndSettle();
      expect(focused(tester), isTrue);
      expect((tester.widget<AnimatedContainer>(box).decoration! as BoxDecoration).border, Border.all(color: st.focus));
      expect(tester.widget<AnimatedContainer>(box).duration, st.duration);
      await type(tester, 'abc');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(submits, ['abc']);
      expect(changes, ['abc']);
      await tester.pumpWidget(
        app(const KakaoPasswordInput(label: 'Password', value: 'hunter2', error: 'That password is not right.')),
      );
      await tester.pumpAndSettle();
      expect((tester.widget<AnimatedContainer>(box).decoration! as BoxDecoration).border, Border.all(color: st.danger));
      expect(tester.widget<Text>(find.text('That password is not right.')).style!.color, st.danger);
      final data = tester.getSemantics(input).getSemanticsData();
      expect(data.validationResult, SemanticsValidationResult.invalid);
      expect(data.label, contains('Password'));
      handle.dispose();
    });

    testWidgets('Caps Lock: shown while focused, at the end of the hint line, below a narrow hint', (tester) async {
      // 420 px: the test font draws every letter 1 em wide.
      await tester.pumpWidget(app(const KakaoPasswordInput(label: 'Password', hint: 'Case sensitive.'), width: 420));
      await tester.tap(input);
      await tester.pump();
      expect(find.text('Caps Lock is on'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.capsLock);
      await tester.pump();
      final caps = find.text('Caps Lock is on');
      expect(caps, findsOneWidget);
      expect(tester.widget<Text>(caps).style!.color, st.text);
      // One line with the hint, at the end of the field's width.
      expect(tester.getTopLeft(caps).dy, tester.getTopLeft(find.text('Case sensitive.')).dy);
      expect(tester.getTopRight(box).dx - tester.getTopRight(caps).dx, closeTo(0, .01));

      // Blur hides it.
      editable(tester).focusNode.unfocus();
      await tester.pump();
      await tester.pump();
      expect(caps, findsNothing);

      // 300 px: the hint would get less than 9rem, the warning goes below.
      await tester.pumpWidget(app(const KakaoPasswordInput(hint: 'Case sensitive.'), width: 300));
      await tester.tap(input);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pump();
      expect(caps, findsOneWidget);
      expect(tester.getTopLeft(caps).dy, greaterThan(tester.getBottomLeft(find.text('Case sensitive.')).dy));
      expect(tester.getTopRight(box).dx - tester.getTopRight(caps).dx, closeTo(0, .01));
      // Caps Lock off again.
      await tester.sendKeyEvent(LogicalKeyboardKey.capsLock);
      await tester.pump();
      expect(caps, findsNothing);
    });

    testWidgets('requirements: bar with a segment per requirement, list, events', (tester) async {
      final events = <KakaoPasswordRequirements>[];
      await tester.pumpWidget(
        app(KakaoPasswordInput(requirements: true, onRequirementsChanged: events.add), width: 400),
      );
      expect(editable(tester).autofillHints, [AutofillHints.newPassword]);
      for (final l in ['At least 8 characters', 'A lowercase letter', 'An uppercase letter', 'A number', 'A symbol']) {
        expect(find.text(l), findsOneWidget);
      }
      var bar = tester.widget<KakaoProgress>(progress);
      expect((bar.value, bar.max, bar.segments, bar.size), (0.0, 5.0, 5, KakaoProgressSize.sm));
      expect(tester.getTopLeft(progress).dy - tester.getBottomLeft(box).dy, st.strengthGap);
      // 400 px: two columns of at least 11rem (and the 1rem gap).
      double top(String t) => tester.getTopLeft(find.text(t)).dy;
      expect(top('A lowercase letter'), top('At least 8 characters'));
      expect(top('A number'), top('An uppercase letter'));
      expect(top('An uppercase letter'), greaterThan(top('A lowercase letter')));
      expect(tester.getTopLeft(find.text('A lowercase letter')).dx, greaterThan(tester.getCenter(box).dx));

      await tester.tap(input);
      await tester.pump();
      await type(tester, 'abc1');
      bar = tester.widget<KakaoProgress>(progress);
      expect((bar.value, bar.tone), (2.0, KakaoProgressTone.primary));
      expect(events.last.met, 2);
      expect(events.last.requirements.where((r) => r.met).map((r) => r.label), ['A lowercase letter', 'A number']);
      final count = events.length;
      await type(tester, 'abc2');
      expect(events, hasLength(count)); // the same set: no event
      await type(tester, 'Abcdefg1!');
      await tester.pumpAndSettle();
      bar = tester.widget<KakaoProgress>(progress);
      expect((bar.value, bar.tone), (5.0, KakaoProgressTone.success));
      await tester.pump(const Duration(seconds: 1));
      final met = tester.widget<Text>(find.text('A symbol')).style!.color;
      expect(met, st.text);
    });

    testWidgets('announces what changed once typing pauses', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(app(const KakaoPasswordInput(requirements: true)));
      await tester.tap(input);
      await tester.pump();
      await type(tester, 'a');
      await tester.pump(const Duration(milliseconds: 500));
      await type(tester, 'a1');
      await tester.pump(const Duration(milliseconds: 999));
      expect(find.bySemanticsLabel(RegExp('Met:')), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.bySemanticsLabel('Met: A lowercase letter, A number. 2 of 5 requirements met.'), findsOneWidget);
      expect(find.bySemanticsLabel('A number: met.'), findsOneWidget);
      expect(find.bySemanticsLabel('A symbol: not met.'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('own requirements, minLength, invalid patterns left out, required strength', (tester) async {
      await tester.pumpWidget(app(const KakaoPasswordInput(requirements: true, minLength: 12)));
      expect(find.text('At least 12 characters'), findsOneWidget);
      await tester.pumpWidget(
        app(
          KakaoPasswordInput(
            requirements: true,
            requirementList: [
              KakaoPasswordRequirement.pattern('At least 16 characters', '.{16,}'),
              KakaoPasswordRequirement.pattern('Broken', '('),
              KakaoPasswordRequirement(label: 'Not your username', test: (v) => v.toLowerCase() != 'ana'),
            ],
          ),
        ),
      );
      expect(find.text('Broken'), findsNothing);
      expect(tester.widget<KakaoProgress>(progress).segments, 2);
      // Without requirements: no bar, no list.
      await tester.pumpWidget(app(const KakaoPasswordInput()));
      expect(progress, findsNothing);
      // required-strength implies requirements.
      await tester.pumpWidget(app(const KakaoPasswordInput(requiredStrength: 4)));
      expect(progress, findsOneWidget);

      final four = KakaoPasswordInput.evaluate('abc', requiredStrength: 4);
      expect(four.strengthMessage, 'Meet at least 4 of the 5 password requirements (1 so far).');
      final all = KakaoPasswordInput.evaluate('abcABC12', requiredStrength: KakaoPasswordInput.allRequirements);
      expect(all.strengthMessage, 'Your password still needs: A symbol.');
      expect(KakaoPasswordInput.evaluate('', requiredStrength: 0).strengthMessage, isNull);
      expect(KakaoPasswordInput.evaluate('abcABC1!').strengthMessage, isNull);
      expect(KakaoPasswordInput.evaluate('Äbc', requiredStrength: 0).met, 2);
    });

    testWidgets('a new value from the owner shows without reporting; reduced motion', (tester) async {
      final inputs = <String>[];
      await tester.pumpWidget(app(KakaoPasswordInput(value: 'one', onChanged: inputs.add)));
      await tester.pumpWidget(app(KakaoPasswordInput(value: 'two', onChanged: inputs.add)));
      expect(editable(tester).controller.text, 'two');
      expect(inputs, isEmpty);
      await tester.pumpWidget(app(const KakaoPasswordInput(), reduceMotion: true));
      expect(tester.widget<AnimatedContainer>(box).duration, Duration.zero);
    });
  });
}
