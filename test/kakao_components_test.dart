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
  });
}
