// KakaoTextInput (text-input.js).
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakao_components/kakao_components.dart';
import 'package:kakao_components/src/internal/kakao_field.dart';

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
              builder: (_) => ColoredBox(
                color: const Color(0xFFFFFFFF),
                child: Stack(children: [Positioned(left: 40, top: 40, width: 260, child: child)]),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);

Finder get field => find.byType(KakaoTextInput);
Finder get input => find.byType(EditableText);
Finder get box => find.descendant(of: field, matching: find.byType(AnimatedContainer)).first;
Finder get clear => find.byType(KakaoFieldButton);
BoxDecoration boxDecoration(WidgetTester tester) => tester.widget<AnimatedContainer>(box).decoration! as BoxDecoration;
String text(WidgetTester tester) => tester.widget<EditableText>(input).controller.text;
bool focused(WidgetTester tester) => tester.widget<EditableText>(input).focusNode.hasFocus;
final st = KakaoTextInputSettings.of(KakaoThemeData.light.colors);

Iterable<BoxDecoration> rings(WidgetTester tester, Color c) => tester
    .widgetList<DecoratedBox>(find.descendant(of: field, matching: find.byType(DecoratedBox)))
    .map((d) => d.decoration as BoxDecoration)
    .where((d) => d.border == Border.all(color: c, width: st.focusWidth));

void main() {
  group('KakaoTextInput', () {
    testWidgets('label, value, placeholder, hint; height and font per size', (tester) async {
      await tester.pumpWidget(app(const KakaoTextInput(label: 'Email', value: 'a@b.c', hint: 'Receipts only.')));
      expect(find.text('Email'), findsOneWidget);
      expect(text(tester), 'a@b.c');
      expect(tester.getSize(box).height, st.height);
      expect(boxDecoration(tester).border, Border.all(color: st.border));
      expect(boxDecoration(tester).color, st.bg);
      expect(boxDecoration(tester).borderRadius, BorderRadius.circular(st.radius));
      expect(tester.getTopLeft(box).dy - tester.getBottomLeft(find.text('Email')).dy, st.labelGap);
      expect(tester.getTopLeft(find.text('Receipts only.')).dy - tester.getBottomLeft(box).dy, st.messageGap);
      expect(tester.widget<Text>(find.text('Receipts only.')).style!.color, st.muted);
      // The text starts padding-x inside the 1 px border.
      expect(tester.getTopLeft(input).dx - tester.getTopLeft(box).dx, st.paddingX + 1);
      expect(tester.widget<EditableText>(input).style.fontSize, st.font.size);
      // No icon, no clear button: no space reserved.
      expect(clear, findsNothing);

      await tester.pumpWidget(app(const KakaoTextInput(placeholder: 'you@example.com')));
      expect(tester.widget<Text>(find.text('you@example.com')).style!.color, st.muted);

      for (final (size, h, f, p) in [
        (KakaoTextInputSize.sm, 36.0, 14.0, 10.0),
        (KakaoTextInputSize.lg, 52.0, 16.0, 14.0),
      ]) {
        await tester.pumpWidget(app(KakaoTextInput(size: size)));
        await tester.pumpAndSettle();
        expect(tester.getSize(box).height, h);
        expect(tester.widget<EditableText>(input).style.fontSize, f);
        expect(tester.getTopLeft(input).dx - tester.getTopLeft(box).dx, p + 1);
      }
    });

    testWidgets('focus: focus border and the 2 px outline; error: danger border, message, invalid', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(app(const KakaoTextInput(label: 'Workspace', hint: 'A hint')));
      await tester.tap(find.text('Workspace'));
      await tester.pumpAndSettle();
      expect(focused(tester), isTrue);
      expect(boxDecoration(tester).border, Border.all(color: st.focus));
      expect(
        rings(tester, st.focus).single.borderRadius,
        BorderRadius.circular(st.radius + st.focusOffset + st.focusWidth),
      );

      await tester.pumpWidget(app(const KakaoTextInput(label: 'Workspace', hint: 'A hint', error: 'Taken.')));
      await tester.pumpAndSettle();
      expect(find.text('A hint'), findsNothing);
      expect(tester.widget<Text>(find.text('Taken.')).style!.color, st.danger);
      expect(boxDecoration(tester).border, Border.all(color: st.danger));
      await tester.tap(input);
      await tester.pumpAndSettle();
      // :host([error]) wins over focus.
      expect(boxDecoration(tester).border, Border.all(color: st.danger));
      expect(rings(tester, st.danger), hasLength(1));
      final data = tester.getSemantics(input).getSemanticsData();
      expect(data.validationResult, SemanticsValidationResult.invalid);
      expect(data.hint, 'Taken.');
      expect(data.label, contains('Workspace'));
      handle.dispose();
    });

    testWidgets('the border fades over 150 ms; at once with reduced motion', (tester) async {
      await tester.pumpWidget(app(const KakaoTextInput(label: 'Name')));
      expect(tester.widget<AnimatedContainer>(box).duration, const Duration(milliseconds: 150));
      await tester.pumpWidget(app(const KakaoTextInput(label: 'Name'), reduceMotion: true));
      expect(tester.widget<AnimatedContainer>(box).duration, Duration.zero);
    });

    testWidgets('the name: label, else aria-label, else placeholder, else "Text"', (tester) async {
      final handle = tester.ensureSemantics();
      String name() => tester.getSemantics(input).getSemanticsData().label;
      await tester.pumpWidget(app(const KakaoTextInput(semanticLabel: 'Workspace')));
      expect(name(), contains('Workspace'));
      await tester.pumpWidget(app(const KakaoTextInput(placeholder: 'Search components')));
      expect(name(), contains('Search components'));
      await tester.pumpWidget(app(const KakaoTextInput()));
      expect(name(), contains('Text'));
      handle.dispose();
    });

    testWidgets('typing reports input; change when focus leaves or on Enter, only if changed', (tester) async {
      final inputs = <String>[];
      final changes = <String>[];
      await tester.pumpWidget(
        app(
          Column(
            children: [
              KakaoTextInput(label: 'Name', onChanged: inputs.add, onCommitted: changes.add),
              const KakaoTextInput(label: 'Other'),
            ],
          ),
        ),
      );
      await tester.tap(input.first);
      await tester.pump();
      await tester.enterText(input.first, 'ab');
      expect(inputs, ['ab']);
      expect(changes, isEmpty);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(changes, ['ab']);
      // Enter again without a change: nothing.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(changes, ['ab']);

      await tester.enterText(input.first, 'abc');
      await tester.tap(input.last);
      await tester.pump();
      expect(changes, ['ab', 'abc']);
      // Focus in and out without typing: no change.
      await tester.tap(input.first);
      await tester.pump();
      await tester.tap(input.last);
      await tester.pump();
      expect(changes, ['ab', 'abc']);
    });

    testWidgets('clearable: the button shows with a value; a tap empties, focuses and reports', (tester) async {
      final inputs = <String>[];
      final changes = <String>[];
      final clears = <KakaoTextInputClear>[];
      await tester.pumpWidget(
        app(
          KakaoTextInput(
            label: 'Search',
            clearable: true,
            value: 'kakao',
            onChanged: inputs.add,
            onCommitted: changes.add,
            onCleared: clears.add,
          ),
        ),
      );
      expect(clear, findsOneWidget);
      expect(tester.getSize(clear), Size.square(st.clearSize));
      final deco = tester.widget<Container>(find.descendant(of: clear, matching: find.byType(Container))).decoration;
      expect((deco! as BoxDecoration).color, st.hoverBg);
      // The button ends padding-x from the edge, padding-x * 0.6 after the text.
      expect(tester.getTopRight(box).dx - tester.getTopRight(clear).dx, st.paddingX + 1);
      expect(tester.getTopLeft(clear).dx - tester.getTopRight(input).dx, closeTo(st.paddingX * .6, 1e-9));

      await tester.tap(clear);
      await tester.pumpAndSettle();
      expect(text(tester), '');
      expect(focused(tester), isTrue);
      expect(inputs, ['']);
      expect(changes, ['']);
      expect(clears.single.previous, 'kakao');
      expect(clears.single.value, '');
      expect(clear, findsNothing);

      // Leaving now is no second change.
      tester.widget<EditableText>(input).focusNode.unfocus();
      await tester.pump();
      expect(changes, ['']);

      await tester.enterText(input, 'x');
      await tester.pump();
      expect(clear, findsOneWidget);
    });

    testWidgets('the clear button: muted, the text colour under the pointer; not in the focus order', (tester) async {
      await tester.pumpWidget(app(const KakaoTextInput(clearable: true, value: 'x')));
      Color glyph() => DefaultTextStyle.of(tester.element(find.text('✕'))).style.color!;
      expect(glyph(), st.muted);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: tester.getCenter(clear));
      await tester.pump();
      expect(glyph(), st.text);
      expect(find.descendant(of: clear, matching: find.byType(Focus)), findsNothing);
    });

    testWidgets('a leading icon: muted, icon-size, in a box 1.2 em wide', (tester) async {
      const iconKey = Key('icon');
      await tester.pumpWidget(
        app(
          const KakaoTextInput(
            icon: SizedBox(key: iconKey),
            label: 'Email',
          ),
        ),
      );
      final theme = IconTheme.of(tester.element(find.byKey(iconKey)));
      expect(theme.color, st.muted);
      expect(theme.size, st.iconSize);
      expect(
        tester.getTopLeft(input).dx - tester.getTopLeft(box).dx,
        closeTo(1 + st.paddingX + st.iconSize * 1.2 + st.paddingX * .6, 1e-9),
      );
    });

    testWidgets('disabled: dimmed, not focusable, the clear button does nothing', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        app(KakaoTextInput(disabled: true, clearable: true, value: 'Not now', focusNode: node, label: 'Disabled')),
      );
      expect(
        tester.widget<Opacity>(find.ancestor(of: box, matching: find.byType(Opacity)).first).opacity,
        st.disabledOpacity,
      );
      node.requestFocus();
      await tester.pump();
      expect(node.hasFocus, isFalse);
      await tester.tap(clear, warnIfMissed: false);
      await tester.pump();
      expect(text(tester), 'Not now');
    });

    testWidgets('read only: focusable with the outline, not editable', (tester) async {
      await tester.pumpWidget(app(const KakaoTextInput(readOnly: true, value: 'Copied elsewhere', label: 'Read only')));
      await tester.tap(find.text('Read only'));
      await tester.pumpAndSettle();
      expect(focused(tester), isTrue);
      expect(tester.widget<EditableText>(input).readOnly, isTrue);
      expect(rings(tester, st.focus), hasLength(1));
    });

    testWidgets('type: password shows dots; email, url, tel pick the keyboard; maxlength', (tester) async {
      await tester.pumpWidget(app(const KakaoTextInput(type: KakaoTextInputType.password)));
      expect(tester.widget<EditableText>(input).obscureText, isTrue);
      for (final (type, keyboard) in [
        (KakaoTextInputType.email, TextInputType.emailAddress),
        (KakaoTextInputType.url, TextInputType.url),
        (KakaoTextInputType.tel, TextInputType.phone),
      ]) {
        await tester.pumpWidget(app(KakaoTextInput(type: type)));
        expect(tester.widget<EditableText>(input).keyboardType, keyboard);
        expect(tester.widget<EditableText>(input).obscureText, isFalse);
      }
      await tester.pumpWidget(app(const KakaoTextInput(maxLength: 3)));
      await tester.enterText(input, 'abcdef');
      expect(text(tester), 'abc');
    });

    testWidgets('a new value from the owner shows without reporting; a controller holds the text', (tester) async {
      final inputs = <String>[];
      await tester.pumpWidget(app(KakaoTextInput(value: 'a', onChanged: inputs.add)));
      await tester.pumpWidget(app(KakaoTextInput(value: 'hello', onChanged: inputs.add)));
      expect(text(tester), 'hello');
      expect(inputs, isEmpty);

      final controller = TextEditingController(text: 'held');
      addTearDown(controller.dispose);
      await tester.pumpWidget(app(KakaoTextInput(controller: controller, clearable: true)));
      expect(text(tester), 'held');
      controller.text = '';
      await tester.pump();
      expect(clear, findsNothing);
    });

    testWidgets('more contrast: the field takes the high-contrast roles', (tester) async {
      await tester.pumpWidget(app(const KakaoTextInput(), highContrast: true));
      final hc = KakaoTextInputSettings.of(KakaoThemeData.light.highContrast);
      expect(boxDecoration(tester).border, Border.all(color: hc.border));
    });
  });

  group('KakaoFieldText on several lines', () {
    testWidgets('a textarea: multiline keyboard and new line, the placeholder at the top', (tester) async {
      final controller = TextEditingController();
      final node = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(node.dispose);
      await tester.pumpWidget(
        app(
          SizedBox(
            height: 88,
            child: KakaoFieldText(
              controller: controller,
              focusNode: node,
              style: const TextStyle(fontSize: 15, height: 1.5),
              placeholder: 'Write something',
              placeholderColor: const Color(0xFF888888),
              cursorColor: const Color(0xFF000000),
              selectionColor: const Color(0x40000000),
              maxLines: null,
              minLines: 3,
            ),
          ),
        ),
      );
      final editable = tester.widget<EditableText>(input);
      expect(editable.keyboardType, TextInputType.multiline);
      expect(editable.textInputAction, TextInputAction.newline);
      expect(tester.getTopLeft(find.text('Write something')).dy, tester.getTopLeft(input).dy);
    });
  });
}
