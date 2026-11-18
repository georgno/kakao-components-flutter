// KakaoTextarea (textarea.js).
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakao_components/kakao_components.dart';

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
                child: Stack(children: [Positioned(left: 40, top: 40, width: 300, child: child)]),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);

Finder get field => find.byType(KakaoTextarea);
Finder get input => find.byType(EditableText);
Finder get box => find.descendant(of: field, matching: find.byType(AnimatedContainer)).first;
BoxDecoration boxDecoration(WidgetTester tester) => tester.widget<AnimatedContainer>(box).decoration! as BoxDecoration;
String text(WidgetTester tester) => tester.widget<EditableText>(input).controller.text;
bool focused(WidgetTester tester) => tester.widget<EditableText>(input).focusNode.hasFocus;
final st = KakaoTextareaSettings.of(KakaoThemeData.light.colors);
String lines(int n) => List.generate(n, (i) => 'line $i').join('\n');

/// The field box's corner: the grip sits in it.
Offset grip(WidgetTester tester) => tester.getBottomRight(box) - const Offset(6, 6);

void main() {
  group('KakaoTextarea', () {
    testWidgets('label, value, hint; min-height, padding, font', (tester) async {
      await tester.pumpWidget(app(const KakaoTextarea(label: 'Message', value: 'Hi', hint: 'Be kind.')));
      expect(find.text('Message'), findsOneWidget);
      expect(text(tester), 'Hi');
      // .field: the textarea's 88 px and its 1 px border.
      expect(tester.getSize(box).height, st.minHeight + 2);
      expect(boxDecoration(tester).border, Border.all(color: st.border));
      expect(boxDecoration(tester).color, st.bg);
      expect(boxDecoration(tester).borderRadius, BorderRadius.circular(st.radius));
      expect(tester.getTopLeft(box).dy - tester.getBottomLeft(find.text('Message')).dy, st.labelGap);
      expect(tester.getTopLeft(find.text('Be kind.')).dy - tester.getBottomLeft(box).dy, st.messageGap);
      expect(tester.widget<Text>(find.text('Be kind.')).style!.color, st.muted);
      // --kakao-textarea-padding: 10px 12px, inside the border.
      expect(tester.getTopLeft(input) - tester.getTopLeft(box), const Offset(12 + 1, 10 + 1));
      final style = tester.widget<EditableText>(input).style;
      expect(style.fontSize, st.font.size);
      expect(style.height, st.font.lineHeight);
      expect(tester.widget<EditableText>(input).maxLines, isNull);
      expect(tester.widget<EditableText>(input).keyboardType, TextInputType.multiline);

      for (final (size, pad, f) in [
        (KakaoTextareaSize.sm, const Offset(10, 7), 14.0),
        (KakaoTextareaSize.lg, const Offset(14, 12), 16.0),
      ]) {
        await tester.pumpWidget(app(KakaoTextarea(size: size)));
        expect(tester.getSize(box).height, st.minHeight + 2);
        expect(tester.widget<EditableText>(input).style.fontSize, f);
        expect(tester.getTopLeft(input) - tester.getTopLeft(box), pad + const Offset(1, 1));
      }
    });

    testWidgets('grows with its text without a cap; autosize stops at max-height and scrolls', (tester) async {
      await tester.pumpWidget(app(KakaoTextarea(value: lines(20))));
      final grown = tester.getSize(box).height;
      expect(grown, greaterThan(400));
      expect(grown, closeTo(20 * st.font.size * st.font.lineHeight + 20 + 2, 20 * 0.5 + 1));

      await tester.pumpWidget(app(KakaoTextarea(autosize: true, value: lines(20))));
      expect(tester.getSize(box).height, st.maxHeight + 2);
      await tester.pumpWidget(app(KakaoTextarea(autosize: true, maxHeight: 120, value: lines(20))));
      expect(tester.getSize(box).height, 122);
      // The text scrolls inside the padding.
      expect(tester.getSize(input).height, 120 - 20);
    });

    testWidgets('a long placeholder makes it taller; rows sets a least height', (tester) async {
      await tester.pumpWidget(app(KakaoTextarea(placeholder: lines(6))));
      expect(tester.getSize(box).height, greaterThan(st.minHeight + 40));
      expect(tester.widget<Text>(find.text(lines(6))).style!.color, st.muted);
      // At the top, not centred.
      expect(tester.getTopLeft(find.text(lines(6))), tester.getTopLeft(input));

      await tester.pumpWidget(app(const KakaoTextarea(rows: 6)));
      expect(tester.getSize(box).height, closeTo(6 * st.font.size * st.font.lineHeight + 20 + 2, 1e-6));
      await tester.pumpWidget(app(const KakaoTextarea(rows: 2)));
      expect(tester.getSize(box).height, st.minHeight + 2);
    });

    testWidgets('the grip drags the height (not below min-height); the text then scrolls', (tester) async {
      await tester.pumpWidget(app(const KakaoTextarea(value: 'a')));
      await tester.dragFrom(grip(tester), const Offset(0, 60));
      await tester.pump();
      expect(tester.getSize(box).height, st.minHeight + 2 + 60);
      await tester.dragFrom(grip(tester), const Offset(0, -200));
      await tester.pump();
      expect(tester.getSize(box).height, st.minHeight + 2);
      // A fixed height now: more text scrolls instead of growing.
      await tester.enterText(input, lines(20));
      await tester.pump();
      expect(tester.getSize(box).height, st.minHeight + 2);

      await tester.pumpWidget(app(const KakaoTextarea(value: 'a', resize: KakaoTextareaResize.none)));
      await tester.dragFrom(grip(tester), const Offset(0, 60));
      await tester.pump();
      expect(tester.getSize(box).height, st.minHeight + 2);
    });

    testWidgets('focus: focus border and outline; error: danger border, message, invalid', (tester) async {
      await tester.pumpWidget(app(const KakaoTextarea(label: 'Reason', hint: 'Why?')));
      await tester.tap(find.text('Reason'));
      await tester.pumpAndSettle();
      expect(focused(tester), isTrue);
      expect(boxDecoration(tester).border, Border.all(color: st.focus));
      expect(
        find.descendant(
          of: field,
          matching: find.byWidgetPredicate(
            (w) =>
                w is DecoratedBox &&
                (w.decoration as BoxDecoration).border == Border.all(color: st.focus, width: st.focusWidth),
          ),
        ),
        findsOneWidget,
      );

      await tester.pumpWidget(app(const KakaoTextarea(label: 'Reason', hint: 'Why?', error: 'Too short.')));
      expect(find.text('Why?'), findsNothing);
      expect(tester.widget<Text>(find.text('Too short.')).style!.color, st.danger);
      expect(boxDecoration(tester).border, Border.all(color: st.danger));
      final node = tester.getSemantics(input);
      expect(node.validationResult, SemanticsValidationResult.invalid);
      expect(node.label, contains('Reason'));
    });

    testWidgets('a tap below the text focuses with the caret at the end', (tester) async {
      await tester.pumpWidget(app(const KakaoTextarea(value: 'one line')));
      await tester.tapAt(tester.getBottomLeft(box) + const Offset(40, -12));
      await tester.pump();
      expect(focused(tester), isTrue);
      expect(tester.widget<EditableText>(input).controller.selection, const TextSelection.collapsed(offset: 8));
      // A tap on the text places the caret there.
      await tester.tapAt(tester.getTopLeft(input) + const Offset(1, 8));
      await tester.pump();
      expect(tester.widget<EditableText>(input).controller.selection, const TextSelection.collapsed(offset: 0));
    });

    testWidgets('typing reports input; Enter is a new line; change on blur, only if changed', (tester) async {
      final events = <String>[];
      await tester.pumpWidget(
        app(KakaoTextarea(onChanged: (v) => events.add('input $v'), onCommitted: (v) => events.add('change $v'))),
      );
      await tester.tap(input);
      await tester.pump();
      await tester.enterText(input, 'a');
      await tester.testTextInput.receiveAction(TextInputAction.newline);
      await tester.pump();
      expect(events, ['input a']);
      expect(tester.widget<EditableText>(input).textInputAction, TextInputAction.newline);
      tester.widget<EditableText>(input).focusNode.unfocus();
      await tester.pump();
      expect(events, ['input a', 'change a']);
      await tester.tap(input);
      await tester.pump();
      tester.widget<EditableText>(input).focusNode.unfocus();
      await tester.pump();
      expect(events.length, 2);
    });

    testWidgets('counter: "n / max", danger past max; "n" alone; at the start without a hint', (tester) async {
      final c = TextEditingController(text: 'Design systems, mostly.');
      addTearDown(c.dispose);
      await tester.pumpWidget(app(KakaoTextarea(controller: c, label: 'Bio', maxLength: 140, counter: true)));
      expect(find.text('23 / 140'), findsOneWidget);
      expect(tester.widget<Text>(find.text('23 / 140')).style!.color, st.muted);
      expect(tester.getTopLeft(find.text('23 / 140')).dx, tester.getTopLeft(box).dx);
      expect(tester.getTopLeft(find.text('23 / 140')).dy - tester.getBottomLeft(box).dy, st.messageGap);
      c.text = 'x' * 141;
      await tester.pump();
      expect(tester.widget<Text>(find.text('141 / 140')).style!.color, st.danger);
      // maxlength limits typing.
      await tester.enterText(input, 'y' * 200);
      expect(c.text.length, 140);

      await tester.pumpWidget(app(const KakaoTextarea(value: 'abc', counter: true, hint: 'A hint')));
      expect(find.text('3'), findsOneWidget);
      // With a hint: the counter at the end, 12 px or more from it.
      expect(tester.getTopRight(find.text('3')).dx, tester.getTopRight(box).dx);
      expect(tester.getTopLeft(find.text('A hint')).dx, tester.getTopLeft(box).dx);
    });

    testWidgets('the name: label, else aria-label, else placeholder, else "Text"', (tester) async {
      for (final (w, name) in [
        (const KakaoTextarea(semanticLabel: 'Notes', placeholder: 'p'), 'Notes'),
        (const KakaoTextarea(placeholder: 'Write…'), 'Write…'),
        (const KakaoTextarea(), 'Text'),
      ]) {
        await tester.pumpWidget(app(w));
        expect(tester.getSemantics(input).label, contains(name));
      }
    });

    testWidgets('disabled: dimmed, not focusable, no drag; read only: focusable, not editable', (tester) async {
      await tester.pumpWidget(app(const KakaoTextarea(label: 'Off', value: 'x', disabled: true)));
      expect(
        tester.widget<Opacity>(find.descendant(of: field, matching: find.byType(Opacity)).first).opacity,
        st.disabledOpacity,
      );
      await tester.tap(find.text('Off'));
      await tester.tapAt(tester.getCenter(box));
      await tester.pump();
      expect(focused(tester), isFalse);
      await tester.dragFrom(grip(tester), const Offset(0, 60));
      await tester.pump();
      expect(tester.getSize(box).height, st.minHeight + 2);

      await tester.pumpWidget(app(const KakaoTextarea(value: 'x', readOnly: true)));
      await tester.tap(input);
      await tester.pump();
      expect(focused(tester), isTrue);
      expect(tester.widget<EditableText>(input).readOnly, isTrue);
    });

    testWidgets('a new value from the owner shows without reporting', (tester) async {
      final events = <String>[];
      await tester.pumpWidget(app(KakaoTextarea(value: 'a', onChanged: events.add)));
      await tester.pumpWidget(app(KakaoTextarea(value: 'b\nc', onChanged: events.add)));
      expect(text(tester), 'b\nc');
      expect(events, isEmpty);
    });

    testWidgets('the border fades over 150 ms; at once with reduced motion', (tester) async {
      await tester.pumpWidget(app(const KakaoTextarea()));
      expect(tester.widget<AnimatedContainer>(box).duration, const Duration(milliseconds: 150));
      await tester.pumpWidget(app(const KakaoTextarea(), reduceMotion: true));
      expect(tester.widget<AnimatedContainer>(box).duration, Duration.zero);
    });

    testWidgets('the grip: the resize cursor', (tester) async {
      await tester.pumpWidget(app(const KakaoTextarea()));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: grip(tester));
      await tester.pump();
      expect(RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.resizeUpDown);
      await mouse.moveTo(tester.getCenter(box));
      await tester.pump();
      expect(RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.text);
      await mouse.removePointer();
    });
  });
}
