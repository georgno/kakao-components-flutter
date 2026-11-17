// The anchored panel (lib/src/internal) and KakaoPopover against popover.js,
// menu.js and select.js placement rules.
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakao_components/kakao_components.dart';
import 'package:kakao_components/src/internal/kakao_anchored_panel.dart';

const _screen = Size(400, 800);

Widget app(Widget child, {bool reduceMotion = false, bool highContrast = false}) => MediaQuery(
  data: MediaQueryData(size: _screen, disableAnimations: reduceMotion, highContrast: highContrast),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: KakaoTheme(
      data: KakaoThemeData.light,
      child: TapRegionSurface(
        // A page behind, so a pointer down anywhere lands somewhere.
        // A new overlay each time: initialEntries are read only once.
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

/// [child] with its top left corner at [at].
Widget at(Offset at, Widget child) => Stack(
  children: [Positioned(left: at.dx, top: at.dy, child: child)],
);

void useScreen(WidgetTester tester) {
  tester.view.physicalSize = _screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget popover({
  KakaoPopoverTrigger trigger = KakaoPopoverTrigger.click,
  KakaoPopoverPlacement placement = KakaoPopoverPlacement.bottom,
  KakaoPopoverController? controller,
  List<KakaoPopoverRow>? rows,
  bool disabled = false,
  bool header = true,
  void Function(int, KakaoPopoverRow)? onSelect,
  VoidCallback? onOpen,
  VoidCallback? onClose,
}) => KakaoPopover(
  trigger: trigger,
  placement: placement,
  controller: controller,
  disabled: disabled,
  rows: rows,
  onSelect: onSelect,
  onOpen: onOpen,
  onClose: onClose,
  header: header ? const Text('Account') : null,
  content: rows == null ? const SizedBox(key: Key('content'), width: 150, height: 40) : null,
  anchorBuilder: (context, p) => KakaoButton(label: 'Anchor', size: KakaoButtonSize.sm, onPressed: p.toggle),
);

Finder get surface => find.byType(IntrinsicWidth);

double opacity(WidgetTester tester) {
  // The panel paints last: the last opacity layer.
  double? alpha;
  void visit(Layer l) {
    if (l is OpacityLayer) alpha = l.alpha! / 255;
    if (l is ContainerLayer) {
      for (var c = l.firstChild; c != null; c = c.nextSibling) {
        visit(c);
      }
    }
  }

  visit(tester.layers.first);
  return alpha ?? 1;
}

void main() {
  group('anchored panel geometry', () {
    const p = KakaoPanelPlacement(offset: 8);
    const panel = Size(100, 200);

    test('below, centred, offset from the anchor', () {
      const anchor = Rect.fromLTWH(150, 100, 100, 30);
      expect(kakaoPanelSide(anchor, panel, _screen, p), KakaoPanelSide.bottom);
      expect(kakaoPanelPosition(anchor, panel, _screen, KakaoPanelSide.bottom, p), const Offset(150, 138));
    });

    test('popover rule: flips only when the other side fits', () {
      const low = Rect.fromLTWH(150, 700, 100, 30);
      expect(kakaoPanelSide(low, panel, _screen, p), KakaoPanelSide.top);
      // Neither side fits: stays, and is pushed inside the screen.
      const tall = Size(100, 500);
      const mid = Rect.fromLTWH(150, 380, 100, 30);
      expect(kakaoPanelSide(mid, tall, _screen, p), KakaoPanelSide.bottom);
      expect(kakaoPanelPosition(mid, tall, _screen, KakaoPanelSide.bottom, p).dy, 800 - 500 - 8);
    });

    test('menu rule: flips toward more room even when it does not fit there', () {
      const menu = KakaoPanelPlacement(offset: 6, flip: KakaoPanelFlip.towardMoreRoom, align: KakaoPanelAlign.start);
      const tall = Size(100, 500);
      const low = Rect.fromLTWH(150, 500, 100, 30);
      expect(kakaoPanelSide(low, tall, _screen, menu), KakaoPanelSide.top);
      expect(kakaoPanelSide(low, tall, _screen, p), KakaoPanelSide.bottom);
    });

    test('start / end alignment fall back to the other edge, then the margin', () {
      const start = KakaoPanelPlacement(align: KakaoPanelAlign.start);
      const end = KakaoPanelPlacement(align: KakaoPanelAlign.end);
      const right = Rect.fromLTWH(320, 100, 60, 30);
      expect(kakaoPanelPosition(right, panel, _screen, KakaoPanelSide.bottom, start).dx, 380 - 100);
      const left = Rect.fromLTWH(10, 100, 60, 30);
      expect(kakaoPanelPosition(left, panel, _screen, KakaoPanelSide.bottom, end).dx, 10);
      const wide = Size(390, 50);
      expect(kakaoPanelPosition(left, wide, _screen, KakaoPanelSide.bottom, start).dx, 8); // the margin wins
    });

    test('centred panels are kept 8 px inside sideways', () {
      const edge = Rect.fromLTWH(0, 100, 20, 30);
      expect(kakaoPanelPosition(edge, panel, _screen, KakaoPanelSide.bottom, p).dx, 8);
    });
  });

  group('KakaoAnchoredPanel', () {
    testWidgets('capToRoom caps the height to the room (not below 120); keepSide holds the side', (tester) async {
      useScreen(tester);
      final c = KakaoAnchoredPanelController();
      final height = ValueNotifier(400.0);
      await tester.pumpWidget(
        app(
          at(
            const Offset(20, 500),
            KakaoAnchoredPanel(
              controller: c,
              placement: const KakaoPanelPlacement(
                offset: 6,
                align: KakaoPanelAlign.start,
                flip: KakaoPanelFlip.towardMoreRoom,
                capToRoom: true,
                keepSide: true,
              ),
              motion: const KakaoPanelMotion(duration: Duration(milliseconds: 150), curve: Curves.linear, slide: 4),
              panelBuilder: (context, side) => ValueListenableBuilder(
                valueListenable: height,
                builder: (context, h, _) => SizedBox(key: const Key('panel'), width: 100, height: h),
              ),
              child: const SizedBox(width: 80, height: 40),
            ),
          ),
        ),
      );
      c.open();
      await tester.pumpAndSettle();
      // Room below: 800 - 540 - 6 - 8 = 246; above: 500 - 6 - 8 = 486. Goes up.
      final r = tester.getRect(find.byKey(const Key('panel')));
      expect(r.bottom, 500 - 6);
      expect(r.left, 20);
      // Shorter now: it would fit below, but the side stays.
      height.value = 100;
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(const Key('panel'))).bottom, 500 - 6);
    });

    testWidgets('slides in from the anchor side while it fades', (tester) async {
      useScreen(tester);
      final c = KakaoAnchoredPanelController();
      await tester.pumpWidget(
        app(
          at(
            const Offset(20, 100),
            KakaoAnchoredPanel(
              controller: c,
              placement: const KakaoPanelPlacement(offset: 6, align: KakaoPanelAlign.start),
              motion: const KakaoPanelMotion(duration: Duration(milliseconds: 100), curve: Curves.linear, slide: 4),
              panelBuilder: (context, side) => const SizedBox(width: 100, height: 50),
              child: const SizedBox(width: 80, height: 40),
            ),
          ),
        ),
      );
      c.open();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(opacity(tester), closeTo(.5, .02));
      await tester.pumpAndSettle();
      expect(opacity(tester), 1);
    });
  });

  group('KakaoPopover', () {
    testWidgets('click: the anchor toggles it; it sits 8 px below, centred, 120..280 wide', (tester) async {
      useScreen(tester);
      var opens = 0;
      var closes = 0;
      await tester.pumpWidget(app(at(const Offset(100, 100), popover(onOpen: () => opens++, onClose: () => closes++))));
      expect(find.text('Account'), findsNothing);
      await tester.tap(find.text('Anchor'));
      await tester.pumpAndSettle();
      expect(find.text('Account'), findsOneWidget);
      final anchor = tester.getRect(find.byType(KakaoButton));
      final s = tester.getRect(surface);
      expect(s.top, anchor.bottom + 8);
      expect(s.center.dx, closeTo(anchor.center.dx, .01));
      expect(s.width, inInclusiveRange(120, 280));
      await tester.tap(find.text('Anchor'));
      await tester.pumpAndSettle();
      expect(find.text('Account'), findsNothing);
      expect((opens, closes), (1, 1));
    });

    testWidgets('fades in over 150 ms, closes at once; reduced motion appears at once', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(app(at(const Offset(100, 100), popover())));
      await tester.tap(find.text('Anchor'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 75));
      expect(opacity(tester), closeTo(Curves.ease.transform(.5), .02));
      await tester.pump(const Duration(milliseconds: 80));
      expect(opacity(tester), 1);
      await tester.tap(find.text('Anchor'));
      await tester.pump();
      expect(find.text('Account'), findsNothing);

      await tester.pumpWidget(app(at(const Offset(100, 100), popover()), reduceMotion: true));
      await tester.tap(find.text('Anchor'));
      await tester.pump();
      expect(opacity(tester), 1);
    });

    testWidgets('a pointer down outside closes it; inside does not', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(app(at(const Offset(100, 100), popover())));
      await tester.tap(find.text('Anchor'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('content')), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Account'), findsOneWidget);
      await tester.tapAt(const Offset(380, 700));
      await tester.pumpAndSettle();
      expect(find.text('Account'), findsNothing);
    });

    testWidgets('the header close button closes it', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(app(at(const Offset(100, 100), popover())));
      await tester.tap(find.text('Anchor'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('✕'));
      await tester.pumpAndSettle();
      expect(find.text('Account'), findsNothing);
    });

    testWidgets('Escape closes it and focus goes back to the anchor', (tester) async {
      useScreen(tester);
      final rows = [const KakaoPopoverRow('Region', 'us-east-1'), const KakaoPopoverRow('Status', 'OK')];
      await tester.pumpWidget(app(at(const Offset(100, 100), popover(rows: rows))));
      await tester.tap(find.text('Anchor'));
      await tester.pumpAndSettle();
      // The first row took focus.
      expect(Focus.of(tester.element(find.text('Region'))).hasPrimaryFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Region'), findsNothing);
      final focused = FocusManager.instance.primaryFocus!;
      expect(focused.context!.findAncestorWidgetOfExactType<KakaoButton>(), isNotNull);
    });

    testWidgets('rows: arrows wrap, Home / End jump, Enter and taps select', (tester) async {
      useScreen(tester);
      final picked = <int>[];
      final rows = [
        for (final l in ['A', 'B', 'C']) KakaoPopoverRow(l, 'v$l'),
      ];
      await tester.pumpWidget(app(at(const Offset(100, 100), popover(rows: rows, onSelect: (i, r) => picked.add(i)))));
      await tester.tap(find.text('Anchor'));
      await tester.pumpAndSettle();
      bool focused(String l) => Focus.of(tester.element(find.text(l))).hasPrimaryFocus;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      expect(focused('C'), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      expect(focused('A'), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      expect(focused('C'), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.tap(find.text('B'));
      expect(picked, [2, 0, 1]);
      // Selecting does not close it.
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('no rows: "No data"', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(app(at(const Offset(100, 100), popover(rows: const []))));
      await tester.tap(find.text('Anchor'));
      await tester.pumpAndSettle();
      expect(find.text('No data'), findsOneWidget);
    });

    testWidgets('flips above near the bottom; left / right placements', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(app(at(const Offset(100, 740), popover())));
      await tester.tap(find.text('Anchor'));
      await tester.pumpAndSettle();
      final anchor = tester.getRect(find.byType(KakaoButton));
      expect(tester.getRect(surface).bottom, anchor.top - 8);

      await tester.pumpWidget(app(at(const Offset(20, 300), popover(placement: KakaoPopoverPlacement.right))));
      await tester.tap(find.text('Anchor'));
      await tester.pumpAndSettle();
      final a2 = tester.getRect(find.byType(KakaoButton));
      final s2 = tester.getRect(surface);
      expect(s2.left, a2.right + 8);
      expect(s2.center.dy, closeTo(a2.center.dy, .01));
    });

    testWidgets('hover: opens on enter, stays while the pointer moves in, closes 150 ms after leaving', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(app(at(const Offset(100, 100), popover(trigger: KakaoPopoverTrigger.hover))));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: const Offset(5, 5));
      await mouse.moveTo(tester.getCenter(find.text('Anchor')));
      await tester.pumpAndSettle();
      expect(find.text('Account'), findsOneWidget);
      await mouse.moveTo(tester.getCenter(find.byKey(const Key('content'))));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Account'), findsOneWidget);
      await mouse.moveTo(const Offset(390, 790));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Account'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('Account'), findsNothing);
    });

    testWidgets('manual: only the controller opens it; disabled blocks it', (tester) async {
      useScreen(tester);
      final c = KakaoPopoverController();
      await tester.pumpWidget(
        app(at(const Offset(100, 100), popover(trigger: KakaoPopoverTrigger.manual, controller: c))),
      );
      c.open();
      await tester.pumpAndSettle();
      expect(find.text('Account'), findsOneWidget);
      // Manual: an outside pointer down leaves it open.
      await tester.tapAt(const Offset(380, 700));
      await tester.pumpAndSettle();
      expect(find.text('Account'), findsOneWidget);
      c.close();
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        app(at(const Offset(100, 100), popover(trigger: KakaoPopoverTrigger.manual, controller: c, disabled: true))),
      );
      c.open();
      await tester.pumpAndSettle();
      expect(find.text('Account'), findsNothing);
      expect(c.isOpen, isFalse);
    });

    testWidgets('colours come from the theme roles, more contrast too', (tester) async {
      useScreen(tester);
      for (final more in [false, true]) {
        await tester.pumpWidget(app(at(const Offset(100, 100), popover()), highContrast: more));
        await tester.tap(find.text('Anchor'));
        await tester.pumpAndSettle();
        final colors = more ? KakaoThemeData.light.highContrast : KakaoThemeData.light.colors;
        final st = KakaoPopoverSettings.of(colors);
        expect(st.borderColor, colors.line);
        final header = tester.widget<Container>(
          find.ancestor(of: find.text('Account'), matching: find.byType(Container)).first,
        );
        expect((header.decoration! as BoxDecoration).color, colors.subtle);
        await tester.tap(find.text('Anchor'));
        await tester.pumpAndSettle();
      }
    });
  });
}
