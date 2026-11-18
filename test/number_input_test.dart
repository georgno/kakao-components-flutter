// KakaoNumberInput (number-input.js).
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
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
                // The demo page's 16 px (font-size: inherit).
                child: DefaultTextStyle.merge(
                  style: const TextStyle(fontSize: 16),
                  child: Stack(children: [Positioned(left: 40, top: 40, width: 240, child: child)]),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);

Finder get field => find.byType(KakaoNumberInput);
Finder get input => find.byType(EditableText);
Finder get box => find.descendant(of: field, matching: find.byType(AnimatedContainer)).first;
BoxDecoration boxDecoration(WidgetTester tester) => tester.widget<AnimatedContainer>(box).decoration! as BoxDecoration;
String text(WidgetTester tester) => tester.widget<EditableText>(input).controller.text;
bool focused(WidgetTester tester) => tester.widget<EditableText>(input).focusNode.hasFocus;
final st = KakaoNumberInputSettings.of(KakaoThemeData.light.colors);

/// A desktop platform (a fine pointer): the stacked arrows unless asked
/// otherwise. flutter_test's default platform is Android, a touch one.
void desk(String name, WidgetTesterCallback body) =>
    testWidgets(name, body, variant: TargetPlatformVariant.only(TargetPlatform.linux));

void main() {
  group('KakaoNumberInput', () {
    desk('desktop: the input with its padding, the stacked arrow strip on the right', (tester) async {
      await tester.pumpWidget(app(const KakaoNumberInput(value: 10, min: 0, max: 100)));
      expect(text(tester), '10');
      // line-height 1.5 × 16 + padding 6 + 6 + border 2.
      expect(tester.getSize(box).height, 16 * 1.5 + st.inputPadding.vertical + 2);
      expect(boxDecoration(tester).border, Border.all(color: st.inputBorder));
      expect(boxDecoration(tester).color, st.inputBg);
      expect(boxDecoration(tester).borderRadius, BorderRadius.circular(st.inputRadius));
      expect(tester.getTopLeft(input).dx - tester.getTopLeft(box).dx, st.inputPadding.left + 1);
      expect(tester.getTopRight(box).dx - tester.getTopRight(input).dx, st.inputPaddingRight + 1);
      expect(find.text('▲'), findsOneWidget);
      expect(find.text('▼'), findsOneWidget);
      expect(tester.widget<Text>(find.text('▲')).style!.fontSize, st.arrowSize);
      expect(tester.widget<Text>(find.text('▲')).style!.color, st.arrowColor);
      // The strip: arrow-width wide, 1 px inside the border, up over down.
      final strip = tester.getRect(find.ancestor(of: find.text('▲'), matching: find.byType(Column)).first);
      expect(strip.width, st.arrowWidth - 1); // its border-left is outside the column
      expect(tester.getTopRight(box).dx - strip.right, 1);
      expect(tester.getCenter(find.text('▲')).dy, lessThan(tester.getCenter(find.text('▼')).dy));
      expect(find.text('+'), findsNothing);

      await tester.pumpWidget(app(const KakaoNumberInput(value: 2.5, step: .5, size: KakaoNumberInputSize.sm)));
      expect(tester.widget<EditableText>(input).style.fontSize, st.smFontSize);
      expect(tester.getSize(box).height, st.smFontSize * 1.5 + st.inputPadding.vertical + 2);
      expect(tester.getTopRight(box).dx - tester.getTopRight(input).dx, st.smInputPaddingRight + 1);
      expect(tester.widget<Text>(find.text('▼')).style!.fontSize, st.smArrowSize);
    });

    desk('a press steps at once, then repeats every 70 ms after 400 ms; clamps; input and change', (tester) async {
      final changed = <double?>[];
      final committed = <double?>[];
      await tester.pumpWidget(
        app(KakaoNumberInput(value: 97, max: 100, onChanged: changed.add, onCommitted: committed.add)),
      );
      final gesture = await tester.startGesture(tester.getCenter(find.text('▲')));
      await tester.pump();
      expect(text(tester), '98');
      expect(changed, [98]);
      expect(committed, [98]);
      await tester.pump(const Duration(milliseconds: 399));
      expect(text(tester), '98');
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 70));
      expect(text(tester), '99');
      await tester.pump(const Duration(milliseconds: 70));
      await tester.pump(const Duration(milliseconds: 70));
      expect(text(tester), '100'); // clamped to max
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 500));
      expect(changed.last, 100);
      final count = changed.length;
      await tester.pump(const Duration(milliseconds: 500));
      expect(changed.length, count); // stopped on pointerup
      // A press keeps focus where it is (here: nowhere).
      expect(focused(tester), isFalse);

      await tester.tap(find.text('▼'));
      expect(text(tester), '99');
    });

    desk('steps round to the decimals of step; empty counts as 0; min clamps', (tester) async {
      await tester.pumpWidget(app(const KakaoNumberInput(value: 2.5, step: .1, min: 2.4)));
      await tester.tap(find.text('▲'));
      expect(text(tester), '2.6');
      await tester.tap(find.text('▼'));
      await tester.tap(find.text('▼'));
      await tester.tap(find.text('▼'));
      expect(text(tester), '2.4');

      await tester.pumpWidget(app(const KakaoNumberInput()));
      await tester.tap(find.text('▼'));
      expect(text(tester), '-1');
      expect(KakaoNumberInput.format(3.0), '3');
      expect(KakaoNumberInput.parse('1e2'), 100);
      expect(KakaoNumberInput.parse('1e'), isNull);
      expect(KakaoNumberInput.parse(''), isNull);
    });

    desk('wheel over the arrows steps; Arrow Up / Down in the field step', (tester) async {
      await tester.pumpWidget(app(const KakaoNumberInput(value: 10)));
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(tester.getCenter(find.text('▲'))));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, -20)));
      expect(text(tester), '11');
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 20)));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 20)));
      expect(text(tester), '9');

      await tester.tap(input);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      expect(text(tester), '10');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      expect(text(tester), '8');
    });

    desk('typing: only number characters; input with the number, change on blur when changed', (tester) async {
      final changed = <double?>[];
      final committed = <double?>[];
      await tester.pumpWidget(app(KakaoNumberInput(onChanged: changed.add, onCommitted: committed.add)));
      await tester.tap(input);
      await tester.pump();
      expect(focused(tester), isTrue);
      expect(boxDecoration(tester).border, Border.all(color: st.focusColor));
      await tester.enterText(input, '12a');
      expect(text(tester), '12');
      expect(changed.last, 12);
      await tester.enterText(input, '1e');
      expect(changed.last, isNull);
      await tester.enterText(input, '1.5');
      expect(committed, isEmpty);
      tester.widget<EditableText>(input).focusNode.unfocus();
      await tester.pump();
      expect(committed, [1.5]);
    });

    desk('disabled: dimmed, no steps; readOnly: no steps', (tester) async {
      final changed = <double?>[];
      await tester.pumpWidget(app(KakaoNumberInput(value: 42, disabled: true, onChanged: changed.add)));
      expect(
        tester.widget<Opacity>(find.descendant(of: field, matching: find.byType(Opacity)).first).opacity,
        st.disabledOpacity,
      );
      await tester.tap(find.text('▲'), warnIfMissed: false);
      expect(text(tester), '42');

      await tester.pumpWidget(app(KakaoNumberInput(value: 42, readOnly: true, onChanged: changed.add)));
      await tester.tap(find.text('▲'));
      expect(text(tester), '42');
      expect(changed, isEmpty);
    });

    desk('a new value from the owner shows without reporting', (tester) async {
      final changed = <double?>[];
      await tester.pumpWidget(app(KakaoNumberInput(value: 1, onChanged: changed.add)));
      await tester.pumpWidget(app(KakaoNumberInput(value: 5, onChanged: changed.add)));
      expect(text(tester), '5');
      expect(changed, isEmpty);
    });

    desk('semantics: named, increase and decrease; the steppers are hidden', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(app(const KakaoNumberInput(value: 10, semanticLabel: 'Quantity')));
      final node = tester.getSemantics(find.byType(EditableText));
      expect(node.label, contains('Quantity'));
      expect(find.bySemanticsLabel('▲'), findsNothing);
      final data = tester.getSemantics(find.bySemanticsLabel(RegExp('Quantity'))).getSemanticsData();
      expect(data.increasedValue, '11');
      expect(data.decreasedValue, '9');
      handle.dispose();
    });

    group('touch layout', () {
      desk('default: one joined − + pair on the right, 44 px, touch radius, dividers', (tester) async {
        await tester.pumpWidget(app(const KakaoNumberInput(value: 10, touchSteppers: true)));
        expect(find.text('▲'), findsNothing);
        expect(tester.getSize(box).height, st.touchSize);
        expect(boxDecoration(tester).borderRadius, BorderRadius.circular(st.touchRadius));
        expect(tester.widget<EditableText>(input).style.fontSize, 16);
        final minus = tester.getRect(find.text('−'));
        final plus = tester.getRect(find.text('+'));
        expect(minus.center.dx, lessThan(plus.center.dx));
        expect(tester.widget<Text>(find.text('+')).style!.fontSize, st.touchGlyphSize);
        // Joined: the + button ends 1 px inside the border, the − right next to it.
        final buttons = tester.widgetList<Container>(
          find.ancestor(of: find.text('+'), matching: find.byType(Container)),
        );
        expect(buttons.first.constraints!.maxWidth, st.touchSize);
        final plusBox = tester.getRect(find.ancestor(of: find.text('+'), matching: find.byType(Container)).first);
        final minusBox = tester.getRect(find.ancestor(of: find.text('−'), matching: find.byType(Container)).first);
        expect(tester.getTopRight(box).dx - plusBox.right, 1);
        expect(plusBox.left, minusBox.right);
        expect(plusBox.height, st.touchSize - 2);
        expect((buttons.first.decoration! as BoxDecoration).border, Border(left: BorderSide(color: st.divider)));
        // Room for two buttons + 12 on the right, 12 on the left.
        expect(tester.getTopRight(box).dx - tester.getTopRight(input).dx, 2 * st.touchSize + 12 + 1);
        expect(tester.getTopLeft(input).dx - tester.getTopLeft(box).dx, 12 + 1);

        await tester.tap(find.text('+'));
        expect(text(tester), '11');
        await tester.tap(find.text('−'));
        await tester.tap(find.text('−'));
        expect(text(tester), '9');
      });

      desk('group on the left; split; one button; a touch platform uses it by default', (tester) async {
        await tester.pumpWidget(app(const KakaoNumberInput(touchSteppers: true, groupPosition: KakaoStepperSide.left)));
        expect(
          tester.getTopLeft(find.ancestor(of: find.text('−'), matching: find.byType(Container)).first).dx -
              tester.getTopLeft(box).dx,
          1,
        );
        expect(tester.getTopLeft(input).dx - tester.getTopLeft(box).dx, 2 * st.touchSize + 12 + 1);

        // Split: + left, − right, on the field's outer edges, dividers inside.
        await tester.pumpWidget(
          app(const KakaoNumberInput(touchSteppers: true, grouped: false, plus: KakaoStepperSide.left)),
        );
        final plusBox = tester.getRect(find.ancestor(of: find.text('+'), matching: find.byType(Container)).first);
        final minusBox = tester.getRect(find.ancestor(of: find.text('−'), matching: find.byType(Container)).first);
        expect(plusBox.left, tester.getTopLeft(box).dx);
        expect(minusBox.right, tester.getTopRight(box).dx);
        expect(
          (tester
                      .widget<Container>(find.ancestor(of: find.text('+'), matching: find.byType(Container)).first)
                      .decoration!
                  as BoxDecoration)
              .border,
          Border(right: BorderSide(color: st.divider)),
        );
        expect(tester.getTopLeft(input).dx - tester.getTopLeft(box).dx, st.touchSize + 12 + 1);

        // Two separate buttons on one side keep a 4 px gap.
        await tester.pumpWidget(app(const KakaoNumberInput(touchSteppers: true, grouped: false)));
        final a = tester.getRect(find.ancestor(of: find.text('−'), matching: find.byType(Container)).first);
        final b = tester.getRect(find.ancestor(of: find.text('+'), matching: find.byType(Container)).first);
        expect(b.left - a.right, 4);

        await tester.pumpWidget(app(const KakaoNumberInput(touchSteppers: true, minus: KakaoStepperSide.none)));
        expect(find.text('−'), findsNothing);
        expect(find.text('+'), findsOneWidget);
        expect(tester.getTopRight(box).dx - tester.getTopRight(input).dx, st.touchSize + 12 + 1);

        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        await tester.pumpWidget(app(const KakaoNumberInput(value: 1)));
        expect(find.text('+'), findsOneWidget);
        debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      });

      desk('with a mouse only the leaving out applies', (tester) async {
        await tester.pumpWidget(app(const KakaoNumberInput(plus: KakaoStepperSide.none)));
        expect(find.text('▲'), findsNothing);
        expect(find.text('▼'), findsOneWidget);
      });
    });

    desk('focus: border and outline; reduced motion fades at once', (tester) async {
      await tester.pumpWidget(app(const KakaoNumberInput(), reduceMotion: true));
      expect(tester.widget<AnimatedContainer>(box).duration, Duration.zero);
      await tester.tap(input);
      await tester.pump();
      final rings = tester
          .widgetList<DecoratedBox>(find.descendant(of: field, matching: find.byType(DecoratedBox)))
          .map((d) => d.decoration as BoxDecoration)
          .where((d) => d.border == Border.all(color: st.focusColor, width: st.focusWidth));
      expect(rings, hasLength(1));
    });
  });
}
