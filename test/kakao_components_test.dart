import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakao_components/kakao_components.dart';

Widget _host(Widget child, {KakaoThemeData theme = KakaoThemeData.light, bool highContrast = false}) => MediaQuery(
  data: MediaQueryData(highContrast: highContrast),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: KakaoTheme(
      data: theme,
      child: Center(child: child),
    ),
  ),
);

void main() {
  group('themes', () {
    test('every web theme is present', () {
      expect(
        KakaoThemeData.all.map((t) => t.name),
        containsAll(['light', 'beige', 'umber', 'dark', 'amoled', 'catppuccin', 'forest']),
      );
    });

    test('values match tokens.css and themes.css', () {
      expect(KakaoThemeData.light.colors.primary, const Color(0xFF4F46E5));
      expect(KakaoThemeData.dark.colors.border, const Color(0xFF71717A));
      expect(KakaoThemeData.dark.highContrast.border, const Color(0xFFA1A1AA));
      expect(KakaoThemeData.amoled.isDark, isTrue);
    });

    testWidgets('high contrast picks the stronger colours', (tester) async {
      late KakaoThemeValues seen;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (c) {
              seen = KakaoTheme.of(c);
              return const SizedBox();
            },
          ),
          theme: KakaoThemeData.dark,
          highContrast: true,
        ),
      );
      expect(seen.colors.border, const Color(0xFFA1A1AA));
    });
  });

  group('KakaoButton', () {
    testWidgets('md is 44 high and calls onPressed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(KakaoButton(label: 'Save', onPressed: () => taps++)));
      expect(tester.getSize(find.byType(AnimatedContainer)).height, 44);
      await tester.tap(find.text('Save'));
      expect(taps, 1);
    });

    testWidgets('sizes follow button.css', (tester) async {
      for (final (size, h) in [(KakaoButtonSize.sm, 36.0), (KakaoButtonSize.lg, 52.0)]) {
        await tester.pumpWidget(_host(KakaoButton(label: 'x', size: size, onPressed: () {})));
        await tester.pumpAndSettle();
        expect(tester.getSize(find.byType(AnimatedContainer)).height, h);
      }
    });

    testWidgets('disabled and loading buttons ignore taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(const KakaoButton(label: 'Off')));
      await tester.tap(find.text('Off'), warnIfMissed: false);
      await tester.pumpWidget(_host(KakaoButton(label: 'Busy', loading: true, onPressed: () => taps++)));
      await tester.tap(find.text('Busy'), warnIfMissed: false);
      expect(taps, 0);
    });

    testWidgets('hugs its label instead of filling the row', (tester) async {
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 400,
            child: Wrap(
              children: [KakaoButton(label: 'Hi', onPressed: () {})],
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(AnimatedContainer)).width, lessThan(120));
    });

    testWidgets('text has no fallback underline', (tester) async {
      await tester.pumpWidget(_host(KakaoButton(label: 'Plain', onPressed: () {})));
      final style = tester
          .widget<RichText>(find.descendant(of: find.text('Plain'), matching: find.byType(RichText)))
          .text
          .style!;
      expect(style.decoration, TextDecoration.none);
      final base = tester.widget<DefaultTextStyle>(find.byType(DefaultTextStyle).first).style;
      expect(base.decoration, TextDecoration.none);
    });

    testWidgets('squashes to 0.94 while pressed and springs back', (tester) async {
      await tester.pumpWidget(_host(KakaoButton(label: 'Press', onPressed: () {})));
      ScaleTransition scale() => tester.widget<ScaleTransition>(find.byType(ScaleTransition));
      final gesture = await tester.startGesture(tester.getCenter(find.text('Press')));
      await tester.pumpAndSettle();
      expect(scale().scale.value, closeTo(.94, .001));
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(scale().scale.value, greaterThan(.94));
      await tester.pumpAndSettle();
      expect(scale().scale.value, closeTo(1, .001));
    });

    testWidgets('async press: spinner, then the check, then the label', (tester) async {
      final done = Completer<void>();
      await tester.pumpWidget(_host(KakaoButton(label: 'Run', onPressedAsync: () => done.future)));
      await tester.tap(find.text('Run'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(RotationTransition), findsOneWidget); // spinner
      done.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(RotationTransition), findsNothing);
      expect(
        find.byWidgetPredicate((w) => w is CustomPaint && w.painter.runtimeType.toString() == '_CheckPainter'),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();
      final label = tester.widget<Opacity>(find.ancestor(of: find.text('Run'), matching: find.byType(Opacity)).first);
      expect(label.opacity, 1);
    });

    testWidgets('a failing async press goes straight back to the label', (tester) async {
      await tester.pumpWidget(_host(KakaoButton(label: 'Fail', onPressedAsync: () async => throw StateError('x'))));
      await tester.tap(find.text('Fail'));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate((w) => w is CustomPaint && w.painter.runtimeType.toString() == '_CheckPainter'),
        findsNothing,
      );
      final label = tester.widget<Opacity>(find.ancestor(of: find.text('Fail'), matching: find.byType(Opacity)).first);
      expect(label.opacity, 1);
    });
  });

  group('styleguide rules', () {
    testWidgets('toggle: off is 0.45 and weight 400, pressed is full and 600', (tester) async {
      Future<(double, List<FontVariation>?)> read(bool pressed) async {
        await tester.pumpWidget(_host(KakaoButton(label: 'T', toggle: true, pressed: pressed, onPressed: () {})));
        await tester.pumpAndSettle();
        final op = tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity).last).opacity;
        final style = tester
            .widget<RichText>(find.descendant(of: find.text('T'), matching: find.byType(RichText)))
            .text
            .style!;
        return (op, style.fontVariations);
      }

      final off = await read(false);
      expect(off.$1, .45);
      expect(off.$2, [const FontVariation.weight(400)]);
      final on = await read(true);
      expect(on.$1, 1);
      expect(on.$2, [const FontVariation.weight(600)]);
    });

    testWidgets('icon-only button names itself in a tooltip on long-press, and the tap is swallowed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Overlay(
            initialEntries: [
              OverlayEntry(
                builder: (_) => KakaoTheme(
                  data: KakaoThemeData.light,
                  child: Center(
                    child: KakaoButton(icon: const SizedBox(width: 10), semanticLabel: 'Edit', onPressed: () => taps++),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      expect(find.text('Edit'), findsNothing);
      await tester.longPress(find.byType(KakaoButton));
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);
      expect(taps, 0);
      await tester.pump(KakaoTooltip.touchHide);
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsNothing);
    });

    testWidgets('changing the theme cross-fades the colours', (tester) async {
      late KakaoThemeValues seen;
      Widget probe(KakaoThemeData t) => _host(
        Builder(
          builder: (c) {
            seen = KakaoTheme.of(c);
            return const SizedBox();
          },
        ),
        theme: t,
      );
      await tester.pumpWidget(probe(KakaoThemeData.light));
      await tester.pumpWidget(probe(KakaoThemeData.dark));
      await tester.pump(const Duration(milliseconds: 140));
      final mid = seen.colors.page;
      expect(mid, isNot(KakaoThemeData.light.colors.page));
      expect(mid, isNot(KakaoThemeData.dark.colors.page));
      await tester.pumpAndSettle();
      expect(seen.colors.page, KakaoThemeData.dark.colors.page);
    });
  });
}
