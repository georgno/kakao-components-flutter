// KakaoButton's menu form (button.js list-data) and the segmented group
// (button.css .kakao-button-segment).
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakao_components/kakao_components.dart';
import 'package:kakao_components/src/internal/kakao_option_list.dart';

const _screen = Size(400, 800);

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
              builder: (_) => ColoredBox(color: const Color(0xFFFFFFFF), child: child),
            ),
          ],
        ),
      ),
    ),
  ),
);

Widget at(Offset at, Widget child) => Stack(
  children: [Positioned(left: at.dx, top: at.dy, child: child)],
);

void useScreen(WidgetTester tester) {
  tester.view.physicalSize = _screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

const sortItems = [
  KakaoButtonMenuItem('newest', label: 'Newest first'),
  KakaoButtonMenuItem('oldest', label: 'Oldest first'),
  KakaoButtonMenuItem('name', label: 'Name'),
  KakaoButtonMenuItem('size', label: 'Size', disabled: true),
];

const menuKey = Key('menu');
Finder get panel => find.byKey(menuKey);
final st = KakaoButtonSettings.of(KakaoThemeData.light.colors);

Widget sort({
  List<KakaoButtonMenuItem> items = sortItems,
  String? selected = 'newest',
  bool showSelected = true,
  ValueChanged<KakaoButtonSelectEvent>? onSelect,
  ValueChanged<bool>? onMenuChanged,
  ValueChanged<KakaoButtonMenuItem>? onMenuHover,
  KakaoButtonMenuController? controller,
  bool enabled = true,
}) => KakaoButton(
  label: 'Sort by',
  variant: KakaoButtonVariant.secondary,
  menu: items,
  selected: selected,
  showSelected: showSelected,
  onSelect: enabled ? (onSelect ?? (_) {}) : null,
  onMenuChanged: onMenuChanged,
  onMenuHover: onMenuHover,
  menuController: controller,
  menuKey: menuKey,
);

Future<void> key(WidgetTester tester, LogicalKeyboardKey k) async {
  await tester.sendKeyEvent(k);
  await tester.pump();
}

/// The highlighted row's label, from its background.
String? highlighted(WidgetTester tester) {
  for (final e
      in find.descendant(of: find.byType(KakaoOptionList), matching: find.byType(AnimatedContainer)).evaluate()) {
    final w = e.widget as AnimatedContainer;
    final d = w.decoration as BoxDecoration?;
    if (d?.color != null && d!.color!.a > 0) {
      return (find.descendant(of: find.byWidget(w), matching: find.byType(Text)).evaluate().first.widget as Text).data;
    }
  }
  return null;
}

/// Whether the highlighted row shows the keyboard focus ring.
bool ring(WidgetTester tester) => find
    .descendant(of: find.byType(KakaoOptionList), matching: find.byType(AnimatedContainer))
    .evaluate()
    .any((e) => (e.widget as AnimatedContainer).foregroundDecoration != null);

double chevronTurns(WidgetTester tester) => tester.widget<AnimatedRotation>(find.byType(AnimatedRotation)).turns;

void main() {
  group('KakaoButton menu', () {
    testWidgets('a tap opens it below, start-aligned, menu-offset away, on the checked item', (tester) async {
      useScreen(tester);
      final changes = <bool>[];
      await tester.pumpWidget(app(at(const Offset(40, 40), sort(onMenuChanged: changes.add))));
      expect(panel, findsNothing);
      expect(chevronTurns(tester), 0);
      await tester.tap(find.byType(KakaoButton));
      await tester.pumpAndSettle();
      expect(changes, [true]);
      final button = tester.getRect(find.byType(KakaoButton));
      final r = tester.getRect(panel);
      expect(r.top, button.bottom + st.menuOffset);
      expect(r.left, button.left);
      expect(r.width, greaterThanOrEqualTo(st.menuMinWidth));
      expect(
        tester.getSize(find.ancestor(of: find.text('Name'), matching: find.byType(AnimatedContainer))).height,
        st.menuItemHeight,
      );
      // The checked item has the focus background, no ring (opened by pointer).
      expect(highlighted(tester), 'Newest first');
      expect(ring(tester), isFalse);
      expect(chevronTurns(tester), .5);
      await tester.tap(find.byType(KakaoButton));
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      expect(changes, [true, false]);
      expect(chevronTurns(tester), 0);
    });

    testWidgets('at least as wide as the button', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(
        app(
          at(
            const Offset(8, 40),
            KakaoButton(
              label: 'Wide dropdown',
              menu: const [KakaoButtonMenuItem('a')],
              onSelect: (_) {},
              menuKey: menuKey,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(KakaoButton));
      await tester.pumpAndSettle();
      expect(tester.getSize(panel).width, tester.getSize(find.byType(KakaoButton)).width);
    });

    testWidgets('show-selected: the label, the accessible name; a tap picks, closes, reports', (tester) async {
      useScreen(tester);
      final handle = tester.ensureSemantics();
      final picked = <KakaoButtonSelectEvent>[];
      await tester.pumpWidget(app(at(const Offset(40, 40), sort(onSelect: picked.add))));
      expect(find.text('Newest first'), findsOneWidget);
      expect(find.text('Sort by'), findsNothing);
      expect(find.bySemanticsLabel('Sort by: Newest first'), findsOneWidget);
      await tester.tap(find.byType(KakaoButton));
      await tester.pumpAndSettle();
      // The disabled item does nothing.
      await tester.tap(find.text('Size'));
      await tester.pumpAndSettle();
      expect(picked, isEmpty);
      expect(panel, findsOneWidget);
      final name = tester.getCenter(find.text('Name'));
      await tester.tapAt(name);
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      expect(picked.single.value, 'name');
      expect(picked.single.label, 'Name');
      expect(picked.single.previous, 'newest');
      expect(picked.single.position, name);
      expect(find.text('Name'), findsOneWidget);
      expect(find.bySemanticsLabel('Sort by: Name'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a new selected from the owner wins', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(app(at(const Offset(40, 40), sort())));
      await tester.pumpWidget(app(at(const Offset(40, 40), sort(selected: 'oldest'))));
      expect(find.text('Oldest first'), findsOneWidget);
    });

    testWidgets('Down opens on the checked item with the ring; keys move, skip disabled, jump; Enter picks', (
      tester,
    ) async {
      useScreen(tester);
      final picked = <KakaoButtonSelectEvent>[];
      await tester.pumpWidget(app(at(const Offset(40, 40), sort(selected: 'oldest', onSelect: picked.add))));
      await key(tester, LogicalKeyboardKey.tab);
      final button = FocusManager.instance.primaryFocus;
      await key(tester, LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(highlighted(tester), 'Oldest first');
      expect(ring(tester), isTrue);
      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(highlighted(tester), 'Name');
      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(highlighted(tester), 'Newest first', reason: 'skips disabled Size, wraps');
      await key(tester, LogicalKeyboardKey.end);
      expect(highlighted(tester), 'Name');
      await key(tester, LogicalKeyboardKey.keyO);
      expect(highlighted(tester), 'Oldest first');
      await key(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      expect(picked.single.value, 'oldest');
      expect(FocusManager.instance.primaryFocus, button);
      // Keyboard picks report the item's middle.
      expect(picked.single.position, isNot(Offset.zero));
    });

    testWidgets('Up opens on the last enabled item; Enter on the button opens on the checked one', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(app(at(const Offset(40, 40), sort())));
      await key(tester, LogicalKeyboardKey.tab);
      await key(tester, LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(highlighted(tester), 'Name');
      await key(tester, LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      await key(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(highlighted(tester), 'Newest first');
      expect(ring(tester), isTrue);
    });

    testWidgets('Escape closes with focus back; Tab closes and moves on; a pointer down outside closes', (
      tester,
    ) async {
      useScreen(tester);
      final changes = <bool>[];
      await tester.pumpWidget(
        app(
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sort(onMenuChanged: changes.add),
              KakaoButton(label: 'Next', onPressed: () {}),
            ],
          ),
        ),
      );
      await key(tester, LogicalKeyboardKey.tab);
      final button = FocusManager.instance.primaryFocus;
      await key(tester, LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await key(tester, LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      expect(FocusManager.instance.primaryFocus, button);

      await key(tester, LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await key(tester, LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      expect(FocusManager.instance.primaryFocus, isNot(button));
      expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<KakaoButton>()?.label, 'Next');

      await tester.tap(find.byType(KakaoButton).first);
      await tester.pumpAndSettle();
      expect(panel, findsOneWidget);
      await tester.tapAt(const Offset(390, 790));
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      expect(changes, [true, false, true, false, true, false]);
    });

    testWidgets('no room below: it opens above; no room on the right: lined up with the right edge', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(app(at(const Offset(220, 740), sort(showSelected: false))));
      await tester.tap(find.byType(KakaoButton));
      await tester.pumpAndSettle();
      final button = tester.getRect(find.byType(KakaoButton));
      final r = tester.getRect(panel);
      expect(r.bottom, button.top - st.menuOffset);
      expect(r.right, button.right);
    });

    testWidgets('chevron: an icon-only dropdown is a pill; with no-chevron it stays round', (tester) async {
      useScreen(tester);
      Widget more({required bool noChevron}) => KakaoButton(
        icon: const Icon(Icons.more_horiz),
        semanticLabel: 'More actions',
        variant: KakaoButtonVariant.ghost,
        noChevron: noChevron,
        menu: const [KakaoButtonMenuItem('edit', label: 'Edit')],
        onSelect: (_) {},
      );
      await tester.pumpWidget(app(at(const Offset(40, 40), more(noChevron: true))));
      expect(find.byType(AnimatedRotation), findsNothing);
      expect(tester.getSize(find.byType(KakaoButton)), Size.square(st.mdHeight));
      await tester.pumpWidget(app(at(const Offset(40, 40), more(noChevron: false))));
      await tester.pumpAndSettle();
      expect(find.byType(AnimatedRotation), findsOneWidget);
      final size = tester.getSize(find.byType(KakaoButton));
      expect(size.height, st.mdHeight);
      expect(size.width, greaterThan(st.mdHeight));
      // Round ends: radius half the height.
      final box = tester.widget<AnimatedContainer>(
        find.descendant(of: find.byType(KakaoButton), matching: find.byType(AnimatedContainer)).first,
      );
      expect((box.decoration as BoxDecoration).borderRadius, BorderRadius.circular(st.mdHeight / 2));
      // The pill: 0.95em before, 0.85em after (less the chevron's -0.2em pull).
      expect(box.padding, EdgeInsets.only(left: .95 * st.mdFontSize, right: .85 * st.mdFontSize));
    });

    testWidgets('without onSelect it is disabled and does not open', (tester) async {
      useScreen(tester);
      final c = KakaoButtonMenuController();
      addTearDown(c.dispose);
      await tester.pumpWidget(app(at(const Offset(40, 40), sort(enabled: false, controller: c))));
      await tester.tap(find.byType(KakaoButton));
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      c.open();
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
    });

    testWidgets('the controller opens and closes it', (tester) async {
      useScreen(tester);
      final c = KakaoButtonMenuController();
      addTearDown(c.dispose);
      await tester.pumpWidget(app(at(const Offset(40, 40), sort(controller: c))));
      c.open();
      await tester.pumpAndSettle();
      expect(panel, findsOneWidget);
      c.close();
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
    });

    testWidgets('the mouse reports each item it moves onto, once, not disabled ones', (tester) async {
      useScreen(tester);
      final hovered = <String>[];
      await tester.pumpWidget(app(at(const Offset(40, 40), sort(onMenuHover: (i) => hovered.add(i.value)))));
      await tester.tap(find.byType(KakaoButton));
      await tester.pumpAndSettle();
      expect(hovered, isEmpty, reason: 'opening is not a hover');
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: const Offset(390, 790));
      await mouse.moveTo(tester.getCenter(find.text('Oldest first')));
      await tester.pump();
      await mouse.moveTo(tester.getCenter(find.text('Oldest first')) + const Offset(2, 1));
      await tester.pump();
      await mouse.moveTo(tester.getCenter(find.text('Size')));
      await tester.pump();
      await mouse.moveTo(tester.getCenter(find.text('Name')));
      await tester.pump();
      // Off the menu and back onto the same item: reported again.
      await mouse.moveTo(const Offset(390, 790));
      await tester.pump();
      await mouse.moveTo(tester.getCenter(find.text('Name')));
      await tester.pump();
      expect(hovered, ['oldest', 'name', 'name']);
    });

    testWidgets('enters with fade, slide and 97 % scale; with reduced motion at once', (tester) async {
      useScreen(tester);
      for (final reduce in [false, true]) {
        await tester.pumpWidget(
          app(
            // No disabled items: their opacity would be a layer too.
            at(const Offset(40, 40), sort(items: sortItems.sublist(0, 3), selected: null)),
            reduceMotion: reduce,
          ),
        );
        await tester.tap(find.byType(KakaoButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 20));
        final layer = tester.layers.whereType<OpacityLayer>().last;
        expect(layer.alpha, reduce ? 255 : lessThan(255));
        expect(tester.layers.whereType<TransformLayer>().length, reduce ? lessThanOrEqualTo(1) : greaterThan(1));
        await tester.pumpAndSettle();
        expect(
          tester.widget<AnimatedRotation>(find.byType(AnimatedRotation)).duration,
          reduce ? Duration.zero : st.transition,
        );
      }
    });

    testWidgets('menu colours from the theme, more-contrast too; checked item', (tester) async {
      useScreen(tester);
      for (final hc in [false, true]) {
        await tester.pumpWidget(app(at(const Offset(40, 40), sort()), highContrast: hc));
        await tester.tap(find.byType(KakaoButton));
        await tester.pumpAndSettle();
        final s = KakaoButtonSettings.of(hc ? KakaoThemeData.light.highContrast : KakaoThemeData.light.colors);
        final box = tester.widget<Container>(find.descendant(of: panel, matching: find.byType(Container)).first);
        final d = box.decoration! as BoxDecoration;
        expect(d.color, s.menuBg);
        expect(d.border, Border.all(color: s.menuBorder));
        expect(d.borderRadius, BorderRadius.circular(s.menuRadius));
        final painter = tester.widgetList<CustomPaint>(find.descendant(of: panel, matching: find.byType(CustomPaint)));
        expect(painter.map((p) => p.painter).whereType<KakaoCheckPainter>().single.color, s.menuCheck);
        await tester.tapAt(const Offset(390, 790));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('semantics: an expanded button; a menu of radio items named by label', (tester) async {
      useScreen(tester);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(app(at(const Offset(40, 40), sort())));
      await tester.tap(find.byType(KakaoButton));
      await tester.pumpAndSettle();
      expect(tester.getSemantics(find.text('Name')).getSemanticsData().role, SemanticsRole.menuItemRadio);
      expect(find.bySemanticsLabel('Sort by'), findsOneWidget);
      handle.dispose();
    });
  });

  group('KakaoButtonSegment', () {
    Widget segment(String pressed, {ValueChanged<String>? onPress}) => KakaoButtonSegment(
      semanticLabel: 'Alignment',
      children: [
        for (final (v, icon) in [
          ('left', Icons.format_align_left),
          ('center', Icons.format_align_center),
          ('right', Icons.format_align_right),
        ])
          KakaoButton(
            icon: Icon(icon),
            semanticLabel: v,
            toggle: true,
            pressed: pressed == v,
            onPressed: () => onPress?.call(v),
          ),
      ],
    );

    BoxDecoration itemBox(WidgetTester tester, int i) =>
        tester
                .widget<AnimatedContainer>(
                  find.descendant(of: find.byType(KakaoButton).at(i), matching: find.byType(AnimatedContainer)),
                )
                .decoration!
            as BoxDecoration;

    testWidgets('a tray of items; pressed on the raised colour, others transparent', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(app(at(const Offset(40, 40), segment('left'))));
      final tray = tester.widget<DecoratedBox>(
        find.descendant(of: find.byType(KakaoButtonSegment), matching: find.byType(DecoratedBox)).first,
      );
      expect((tray.decoration as BoxDecoration).color, st.segmentBg);
      expect((tray.decoration as BoxDecoration).borderRadius, BorderRadius.circular(st.segmentRadius));
      expect(tester.getSize(find.byType(KakaoButton).first), Size(st.mdHeight, st.segmentItemSize));
      expect(
        tester.getSize(find.byType(KakaoButtonSegment)),
        Size(3 * st.mdHeight + 2 * st.segmentGap + 2 * st.segmentPadding, st.segmentItemSize + 2 * st.segmentPadding),
      );
      expect(itemBox(tester, 0).color, st.segmentPressedBg);
      expect(itemBox(tester, 0).borderRadius, BorderRadius.circular(st.segmentItemRadius));
      expect(itemBox(tester, 1).color!.a, 0);
      expect(itemBox(tester, 0).boxShadow, isEmpty);
      // Icons in ink.
      expect(IconTheme.of(tester.element(find.byIcon(Icons.format_align_center))).color, st.ink);
    });

    testWidgets('hover on a primary item: the dark hover background with light ink', (tester) async {
      useScreen(tester);
      // Hover highlights show with a mouse (traditional highlight mode).
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
      await tester.pumpWidget(app(at(const Offset(40, 40), segment('left', onPress: (_) {}))));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.byType(KakaoButton).at(1)));
      await tester.pumpAndSettle();
      expect(itemBox(tester, 1).color, st.primaryHoverBg);
      expect(IconTheme.of(tester.element(find.byIcon(Icons.format_align_center))).color, st.primaryText);
    });

    testWidgets('a newly pressed item shows the settle shadow once; none with reduced motion', (tester) async {
      useScreen(tester);
      for (final reduce in [false, true]) {
        var pressed = 'left';
        await tester.pumpWidget(
          app(
            StatefulBuilder(
              builder: (context, setState) =>
                  at(const Offset(40, 40), segment(pressed, onPress: (v) => setState(() => pressed = v))),
            ),
            reduceMotion: reduce,
          ),
        );
        await tester.tap(find.byType(KakaoButton).at(2));
        await tester.pump();
        // A quarter in: the peak.
        await tester.pump(st.segmentSettleDuration * .25);
        List<BoxShadow>? settle() {
          final boxes = find.descendant(of: find.byType(KakaoButton).at(2), matching: find.byType(DecoratedBox));
          for (final e in boxes.evaluate()) {
            final d = (e.widget as DecoratedBox).decoration;
            if (d is BoxDecoration && d.color == null && (d.boxShadow?.isNotEmpty ?? false)) return d.boxShadow;
          }
          return null;
        }

        if (reduce) {
          expect(settle(), isNull);
        } else {
          final peak = settle()!.single;
          final want = st.segmentPressedShadow.single;
          expect(peak.blurRadius, closeTo(want.blurRadius, .01));
          expect(peak.color.a, closeTo(want.color.a, .01));
        }
        await tester.pumpAndSettle();
        expect(settle(), isNull, reason: 'no shadow at rest');
        expect(itemBox(tester, 2).color, st.segmentPressedBg);
      }
    });

    testWidgets('semantics: a named group of toggles', (tester) async {
      useScreen(tester);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(app(at(const Offset(40, 40), segment('center', onPress: (_) {}))));
      expect(find.bySemanticsLabel('Alignment'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(KakaoButton).at(1)).getSemanticsData().flagsCollection.isToggled,
        isNotNull,
      );
      handle.dispose();
    });
  });
}
