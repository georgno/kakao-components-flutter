// KakaoCard, KakaoDialog and KakaoProgress against their web twins' rules.
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakao_components/kakao_components.dart';

Widget app(Widget child, {bool reduceMotion = false}) => MediaQuery(
  data: MediaQueryData(size: const Size(400, 800), disableAnimations: reduceMotion),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: KakaoTheme(data: KakaoThemeData.light, child: child),
  ),
);

final _home = GlobalKey();

/// A navigator to show dialogs from; its page's context is [_home].
Widget navigatorApp() => app(
  Navigator(
    onGenerateRoute: (_) => PageRouteBuilder<void>(pageBuilder: (_, _, _) => SizedBox.expand(key: _home)),
  ),
);

void main() {
  group('KakaoCard', () {
    testWidgets('content sits 1px border + 1.25rem padding in; body children 0.75rem apart', (tester) async {
      await tester.pumpWidget(
        app(
          const Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              child: KakaoCard(
                children: [
                  SizedBox(key: Key('a'), height: 10),
                  SizedBox(key: Key('b'), height: 10),
                ],
              ),
            ),
          ),
        ),
      );
      final card = tester.getTopLeft(find.byType(KakaoCard));
      final a = tester.getTopLeft(find.byKey(const Key('a')));
      final b = tester.getTopLeft(find.byKey(const Key('b')));
      expect(a - card, const Offset(21, 21));
      expect(b.dy - a.dy, 10 + 12);
    });

    testWidgets('glow follows the first footer button: filled yes, ghost no, no-glow no', (tester) async {
      final ink = KakaoThemeData.light.colors.ink;
      Color? glowOf(List<Widget> footer) => KakaoCard.glowColorFor(
        footer.first,
        KakaoThemeValues(data: KakaoThemeData.light, colors: KakaoThemeData.light.colors),
      );
      expect(glowOf([KakaoButton(label: 'Go', onPressed: () {})]), ink);
      expect(
        glowOf([KakaoButton(label: 'Go', variant: KakaoButtonVariant.danger, onPressed: () {})]),
        KakaoThemeData.light.colors.danger,
      );
      expect(glowOf([KakaoButton(label: 'Go', variant: KakaoButtonVariant.ghost, onPressed: () {})]), isNull);

      await tester.pumpWidget(
        app(
          KakaoCard(
            footer: [KakaoButton(label: 'Go', onPressed: () {})],
            children: const [Text('x')],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ImageFiltered), findsOneWidget);
      await tester.pumpWidget(
        app(
          KakaoCard(
            noGlow: true,
            footer: [KakaoButton(label: 'Go', onPressed: () {})],
            children: const [Text('x')],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ImageFiltered), findsNothing);
    });
  });

  group('KakaoDialog', () {
    Future<Future<String?>> open(WidgetTester tester, {bool dismissible = true, List<Widget>? footer}) async {
      if (_home.currentContext == null) await tester.pumpWidget(navigatorApp());
      final ctx = _home.currentContext!;
      final result = showKakaoDialog<String>(
        ctx,
        header: const Text('Delete account?'),
        dismissible: dismissible,
        footer:
            footer ??
            [
              Builder(
                builder: (c) => KakaoButton(
                  label: 'Keep it',
                  variant: KakaoButtonVariant.secondary,
                  onPressed: () => Navigator.pop(c, 'cancel'),
                ),
              ),
              Builder(
                builder: (c) => KakaoButton(
                  label: 'Delete',
                  variant: KakaoButtonVariant.danger,
                  onPressed: () => Navigator.pop(c, 'delete'),
                ),
              ),
            ],
        children: const [Text('Gone for good.')],
      );
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('a footer button closes it with its value', (tester) async {
      final result = await open(tester);
      expect(find.text('Delete account?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(await result, 'delete');
      expect(find.text('Delete account?'), findsNothing);
    });

    testWidgets('a tap on the covered page dismisses it with null', (tester) async {
      final result = await open(tester);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('Delete account?'), findsNothing);
      expect(await result, isNull);
    });

    testWidgets('Escape dismisses it with null', (tester) async {
      final result = await open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Delete account?'), findsNothing);
      expect(await result, isNull);
    });

    testWidgets('no-dismiss: the covered page and Escape do nothing', (tester) async {
      await open(tester, dismissible: false);
      await tester.tapAt(const Offset(5, 5));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Delete account?'), findsOneWidget);
    });

    testWidgets('title is 18 / 600 / -0.01em; the corner with a filled button is 14 + 20', (tester) async {
      await open(
        tester,
        footer: [
          KakaoButton(label: 'Later', variant: KakaoButtonVariant.ghost, onPressed: () {}),
          KakaoButton(label: 'OK', onPressed: () {}),
        ],
      );
      final style = tester
          .widget<RichText>(find.descendant(of: find.text('Delete account?'), matching: find.byType(RichText)))
          .text
          .style!;
      expect(style.fontSize, 18);
      expect(style.fontVariations, [const FontVariation.weight(600)]);
      expect(style.letterSpacing, closeTo(-0.18, 1e-9));
      final box = tester.widget<Container>(
        find.descendant(of: find.byType(KakaoDialog), matching: find.byType(Container)).first,
      );
      final radius = (box.decoration! as BoxDecoration).borderRadius! as BorderRadius;
      expect(radius.bottomRight, const Radius.circular(34));
      expect(radius.bottomLeft, const Radius.circular(14));
    });

    testWidgets('a ghost button in the corner keeps the dialog radius', (tester) async {
      expect(
        KakaoDialog.cornerFor(
          KakaoButton(label: 'x', variant: KakaoButtonVariant.ghost, onPressed: () {}),
          KakaoButtonSettings.of(KakaoThemeData.light.colors),
          20,
        ),
        isNull,
      );
    });
  });

  group('KakaoProgress', () {
    testWidgets('a segment pops once when the fill completes it, and not going down', (tester) async {
      final completed = <int>[];
      Widget bar(double v) => app(
        Padding(
          padding: const EdgeInsets.all(8),
          child: KakaoProgress(
            value: v,
            label: 'Uploading',
            showValue: true,
            onSegmentComplete: (i, _) => completed.add(i),
          ),
        ),
      );
      await tester.pumpWidget(bar(0.1));
      await tester.pumpAndSettle();
      expect(completed, isEmpty);
      await tester.pumpWidget(bar(0.6)); // completes segments 0 and 1
      await tester.pumpAndSettle();
      expect(completed, [0, 1]);
      expect(find.text('60%'), findsOneWidget);
      await tester.pumpWidget(bar(0.3)); // going down: no pop
      await tester.pumpAndSettle();
      expect(completed, [0, 1]);
      await tester.pumpWidget(bar(0.6)); // segment 1 emptied-from-start? no: 0.3 > 0.25, stays disarmed
      await tester.pumpAndSettle();
      expect(completed, [0, 1]);
      await tester.pumpWidget(bar(0.2)); // drops to/below segment 1's start: rearmed
      await tester.pumpAndSettle();
      await tester.pumpWidget(bar(0.6));
      await tester.pumpAndSettle();
      expect(completed, [0, 1, 1]);
    });

    testWidgets('segments full on the first build never pop', (tester) async {
      final completed = <int>[];
      await tester.pumpWidget(app(KakaoProgress(value: 1, onSegmentComplete: (i, _) => completed.add(i))));
      await tester.pumpAndSettle();
      expect(completed, isEmpty);
    });

    testWidgets('indeterminate keeps sweeping; reduced motion completes at once', (tester) async {
      await tester.pumpWidget(app(const KakaoProgress(label: 'Loading')));
      await tester.pump(const Duration(milliseconds: 800));
      expect(tester.hasRunningAnimations, isTrue);

      final completed = <int>[];
      Widget bar(double v) =>
          app(KakaoProgress(value: v, onSegmentComplete: (i, _) => completed.add(i)), reduceMotion: true);
      await tester.pumpWidget(bar(0));
      await tester.pumpWidget(bar(1));
      expect(completed, [0, 1, 2, 3]); // same frame, no fill animation
    });
  });
}
