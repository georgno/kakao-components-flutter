// The option list (lib/src/internal) and KakaoMenu against menu.js.
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';

import 'dart:ui' show CheckedState, Tristate;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakao_components/kakao_components.dart';
import 'package:kakao_components/src/internal/kakao_option_list.dart';

const _screen = Size(400, 800);

/// A WidgetsApp (Tab, Enter and Space on buttons) with an overlay and the
/// light theme.
Widget app(Widget child, {bool reduceMotion = false, bool highContrast = false}) => WidgetsApp(
  color: const Color(0xFFFFFFFF),
  builder: (context, _) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion, highContrast: highContrast),
    child: KakaoTheme(
      data: KakaoThemeData.light,
      // A scope with focus, so Tab has somewhere to start.
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

const fileItems = <KakaoMenuEntry>[
  KakaoMenuItem('Rename', value: 'rename', shortcut: 'F2'),
  KakaoMenuItem('Duplicate', value: 'duplicate', shortcut: 'Mod+D'),
  KakaoMenuItem('Download', value: 'download'),
  KakaoMenuItem('Archive', value: 'archive', disabled: true),
  KakaoMenuSeparator(),
  KakaoMenuItem('Delete', value: 'delete', danger: true),
];

Widget menu({
  List<KakaoMenuEntry> items = fileItems,
  KakaoMenuPlacement placement = KakaoMenuPlacement.bottomStart,
  KakaoMenuController? controller,
  bool keepOpen = false,
  bool disabled = false,
  ValueChanged<KakaoMenuSelectEvent>? onSelect,
  VoidCallback? onOpen,
  VoidCallback? onClose,
}) => KakaoMenu(
  items: items,
  placement: placement,
  controller: controller,
  keepOpen: keepOpen,
  disabled: disabled,
  onSelect: onSelect,
  onOpen: onOpen,
  onClose: onClose,
  anchorBuilder: (context, m) =>
      KakaoButton(label: 'Actions', variant: KakaoButtonVariant.secondary, onPressed: m.toggle),
);

Finder get panel => find.byType(IntrinsicWidth);

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
      final text = find.descendant(of: find.byWidget(w), matching: find.byType(Text)).evaluate();
      final label = text.isEmpty ? null : (text.first.widget as Text).data;
      // A submenu's open item keeps its background too; the first such row.
      return label;
    }
  }
  return null;
}

void main() {
  group('option list controller', () {
    List<KakaoOption> rows(List<String> labels, {Set<int> disabled = const {}}) => [
      for (var i = 0; i < labels.length; i++) KakaoOption(label: labels[i], disabled: disabled.contains(i)),
    ];

    Future<KakaoOptionListController> attach(
      WidgetTester tester,
      List<KakaoOptionEntry> entries, {
      void Function(int)? onActivate,
    }) async {
      final c = KakaoOptionListController();
      addTearDown(c.dispose);
      final st = KakaoMenuSettings.of(KakaoThemeData.light.colors);
      await tester.pumpWidget(
        app(
          KakaoOptionList(
            entries: entries,
            controller: c,
            onActivate: onActivate,
            style: KakaoOptionListStyle(
              text: const TextStyle(fontSize: 15, color: Color(0xFF000000)),
              rowMinHeight: st.itemHeight,
              rowPadding: EdgeInsets.zero,
              rowRadius: 6,
              gap: 8,
              trailingGap: 24,
              leadSize: 16,
              highlight: st.hoverBg,
              check: st.check,
              icon: st.icon,
              heading: const TextStyle(fontSize: 12),
              headingPadding: EdgeInsets.zero,
              separator: st.line,
              separatorMargin: 4,
              padding: const EdgeInsets.all(4),
              duration: Duration.zero,
              curve: Curves.linear,
            ),
          ),
        ),
      );
      return c;
    }

    testWidgets('arrows wrap and skip disabled rows; Home / End', (tester) async {
      final c = await attach(tester, rows(['A', 'B', 'C', 'D'], disabled: {1, 3}));
      c.move(1);
      expect(c.highlighted, 0);
      c.move(1);
      expect(c.highlighted, 2);
      c.move(1);
      expect(c.highlighted, 0, reason: 'wraps');
      c.move(-1);
      expect(c.highlighted, 2);
      c.first();
      expect(c.highlighted, 0);
      c.last();
      expect(c.highlighted, 2);
      expect(c.keyboard, isTrue);
    });

    testWidgets('from no highlight Up starts at the last row', (tester) async {
      final c = await attach(tester, rows(['A', 'B', 'C']));
      c.move(-1);
      expect(c.highlighted, 2);
    });

    testWidgets('type-ahead: one letter walks on, a word stays, the buffer resets', (tester) async {
      final c = await attach(tester, rows(['Rename', 'Duplicate', 'Download', 'Delete']));
      c.highlight(0);
      c.typeAhead('d');
      expect(c.highlighted, 1);
      c.typeAhead('d');
      expect(c.highlighted, 2);
      await tester.pump(kakaoTypeAheadReset);
      c.typeAhead('d');
      expect(c.highlighted, 3);
      c.typeAhead('u');
      expect(c.highlighted, 1, reason: '"du" from Delete finds Duplicate');
      await tester.pump(kakaoTypeAheadReset);
    });

    testWidgets('groups and separators: rows are numbered in order; pointer and Enter share the highlight', (
      tester,
    ) async {
      final picked = <int>[];
      final c = await attach(tester, [
        const KakaoOption(label: 'One'),
        const KakaoOptionSeparator(),
        const KakaoOptionGroup([KakaoOption(label: 'Two'), KakaoOption(label: 'Three')], label: 'Heading'),
      ], onActivate: picked.add);
      expect(find.text('Heading'), findsOneWidget);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: tester.getCenter(find.text('Three')));
      await mouse.moveTo(tester.getCenter(find.text('Three')) + const Offset(1, 0));
      await tester.pump();
      expect(c.highlighted, 2);
      expect(c.keyboard, isFalse);
      c.move(-1);
      expect(c.highlighted, 1);
      c.activate();
      expect(picked, [1]);
      await tester.tap(find.text('One'));
      expect(picked, [1, 0]);
    });
  });

  group('KakaoMenu', () {
    testWidgets('a tap on the trigger opens it under the trigger, start-aligned, offset away', (tester) async {
      useScreen(tester);
      var opened = 0;
      await tester.pumpWidget(app(at(const Offset(40, 40), menu(onOpen: () => opened++))));
      expect(panel, findsNothing);
      await tester.tap(find.text('Actions'));
      await tester.pumpAndSettle();
      expect(opened, 1);
      final trigger = tester.getRect(find.byType(KakaoButton));
      final r = tester.getRect(panel);
      final st = KakaoMenuSettings.of(KakaoThemeData.light.colors);
      expect(r.top, trigger.bottom + st.offset);
      expect(r.left, trigger.left);
      expect(r.width, greaterThanOrEqualTo(st.minWidth));
      // Item rows: item-height tall, touch-item-height on touch platforms
      // (`@media (pointer: coarse)`; tests run as Android).
      expect(
        tester.getSize(find.ancestor(of: find.text('Download'), matching: find.byType(AnimatedContainer))).height,
        st.touchItemHeight,
      );
      // Nothing highlighted when a pointer opened it.
      expect(highlighted(tester), isNull);
      await tester.tap(find.text('Actions'));
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
    });

    testWidgets('bottom-end lines up the end edges; near the bottom it flips above', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(app(at(const Offset(200, 740), menu(placement: KakaoMenuPlacement.bottomEnd))));
      await tester.tap(find.text('Actions'));
      await tester.pumpAndSettle();
      final trigger = tester.getRect(find.byType(KakaoButton));
      final r = tester.getRect(panel);
      expect(r.right, trigger.right);
      expect(r.bottom, trigger.top - KakaoMenuSettings.of(KakaoThemeData.light.colors).offset);
    });

    testWidgets('Down on the trigger opens on the first item; keys move; Escape closes, focus back', (tester) async {
      useScreen(tester);
      var closed = 0;
      await tester.pumpWidget(app(at(const Offset(40, 40), menu(onClose: () => closed++))));
      await key(tester, LogicalKeyboardKey.tab);
      final trigger = FocusManager.instance.primaryFocus;
      await key(tester, LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(highlighted(tester), 'Rename');
      await key(tester, LogicalKeyboardKey.arrowUp);
      expect(highlighted(tester), 'Delete', reason: 'wraps');
      await key(tester, LogicalKeyboardKey.arrowUp);
      expect(highlighted(tester), 'Download', reason: 'skips disabled Archive');
      await key(tester, LogicalKeyboardKey.home);
      expect(highlighted(tester), 'Rename');
      await key(tester, LogicalKeyboardKey.keyD);
      expect(highlighted(tester), 'Duplicate');
      await key(tester, LogicalKeyboardKey.keyD);
      expect(highlighted(tester), 'Download');
      await key(tester, LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      expect(closed, 1);
      expect(FocusManager.instance.primaryFocus, trigger);
    });

    testWidgets('Up on the trigger opens on the last item; Enter picks it', (tester) async {
      useScreen(tester);
      final picked = <Object>[];
      await tester.pumpWidget(app(at(const Offset(40, 40), menu(onSelect: (e) => picked.add(e.value)))));
      await key(tester, LogicalKeyboardKey.tab);
      await key(tester, LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(highlighted(tester), 'Delete');
      await key(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(picked, ['delete']);
      expect(panel, findsNothing);
    });

    testWidgets('Enter on the trigger opens on the first item', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(app(at(const Offset(40, 40), menu())));
      await key(tester, LogicalKeyboardKey.tab);
      await key(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(highlighted(tester), 'Rename');
    });

    testWidgets('a tap picks and closes; a disabled item does nothing; label is the default value', (tester) async {
      useScreen(tester);
      final picked = <Object>[];
      await tester.pumpWidget(
        app(
          at(
            const Offset(40, 40),
            menu(
              items: const [KakaoMenuItem('Name'), KakaoMenuItem('Size', disabled: true)],
              onSelect: (e) => picked.add(e.value),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Size'));
      await tester.pumpAndSettle();
      expect(picked, isEmpty);
      expect(panel, findsOneWidget);
      await tester.tap(find.text('Name'));
      await tester.pumpAndSettle();
      expect(picked, ['Name']);
      expect(panel, findsNothing);
    });

    testWidgets('a pointer down outside closes it', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(app(at(const Offset(40, 40), menu())));
      await tester.tap(find.text('Actions'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(350, 700));
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
    });

    testWidgets('Tab closes it and moves on', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(
        app(
          Column(
            children: [
              menu(),
              KakaoButton(label: 'Next', onPressed: () {}),
            ],
          ),
        ),
      );
      await key(tester, LogicalKeyboardKey.tab);
      await key(tester, LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await key(tester, LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      final focused = FocusManager.instance.primaryFocus!.context!;
      expect(
        find.ancestor(of: find.byElementPredicate((e) => e == focused), matching: find.byType(KakaoButton)),
        findsOneWidget,
      );
      expect(
        tester
            .widget<KakaoButton>(
              find.ancestor(of: find.byElementPredicate((e) => e == focused), matching: find.byType(KakaoButton)),
            )
            .label,
        'Next',
      );
    });

    testWidgets('checkbox and radio items: state, check marks, keep-open, cancel', (tester) async {
      useScreen(tester);
      final events = <(Object, bool?)>[];
      var cancel = false;
      const items = <KakaoMenuEntry>[
        KakaoMenuItem('Show sidebar', value: 'sidebar', type: KakaoMenuItemType.checkbox, checked: true),
        KakaoMenuSeparator(),
        KakaoMenuGroup(
          label: 'Density',
          items: [
            KakaoMenuItem('Compact', type: KakaoMenuItemType.radio),
            KakaoMenuItem('Comfortable', type: KakaoMenuItemType.radio, checked: true),
          ],
        ),
      ];
      await tester.pumpWidget(
        app(
          at(
            const Offset(40, 40),
            menu(
              items: items,
              keepOpen: true,
              onSelect: (e) {
                events.add((e.value, e.checked));
                if (cancel) e.preventDefault();
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Actions'));
      await tester.pumpAndSettle();
      bool? checkedOf(String label) =>
          tester.getSemantics(find.text(label)).getSemanticsData().flagsCollection.isChecked == CheckedState.isTrue;
      expect(checkedOf('Show sidebar'), isTrue);
      expect(checkedOf('Comfortable'), isTrue);
      await tester.tap(find.text('Compact'));
      await tester.pumpAndSettle();
      expect(panel, findsOneWidget, reason: 'keep-open');
      expect(checkedOf('Compact'), isTrue);
      expect(checkedOf('Comfortable'), isFalse);
      await tester.tap(find.text('Show sidebar'));
      await tester.pumpAndSettle();
      expect(checkedOf('Show sidebar'), isFalse);
      cancel = true;
      await tester.tap(find.text('Show sidebar'));
      await tester.pumpAndSettle();
      expect(checkedOf('Show sidebar'), isFalse, reason: 'cancelled: the check stays');
      expect(events, [('Compact', true), ('sidebar', false), ('sidebar', true)]);
      // The check mark is drawn for checked rows only.
      expect(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is KakaoCheckPainter), findsNWidgets(1));
    });

    testWidgets('a cancelled pick keeps the menu open', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(
        app(
          at(
            const Offset(40, 40),
            menu(
              onSelect: (e) {
                if (e.value == 'rename') e.preventDefault();
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      expect(panel, findsOneWidget);
    });

    const docItems = <KakaoMenuEntry>[
      KakaoMenuItem('Open', value: 'open'),
      KakaoMenuItem(
        'Share',
        children: [
          KakaoMenuItem('Copy link', value: 'share-link'),
          KakaoMenuItem('Email', value: 'share-email'),
        ],
      ),
      KakaoMenuItem('Delete', value: 'delete', danger: true),
    ];

    testWidgets('submenu: Right opens it on its first item, Left goes back, Escape closes it first', (tester) async {
      useScreen(tester);
      final picked = <Object>[];
      await tester.pumpWidget(
        app(at(const Offset(8, 40), menu(items: docItems, onSelect: (e) => picked.add(e.value)))),
      );
      await key(tester, LogicalKeyboardKey.tab);
      await key(tester, LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await key(tester, LogicalKeyboardKey.arrowDown);
      await key(tester, LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(panel, findsNWidgets(2));
      // Beside the parent menu, level with its item less the padding.
      final st = KakaoMenuSettings.of(KakaoThemeData.light.colors);
      final parent = tester.getRect(panel.first);
      final sub = tester.getRect(panel.last);
      final item = tester.getRect(find.ancestor(of: find.text('Share'), matching: find.byType(AnimatedContainer)));
      expect(sub.left, parent.right + st.subOffset);
      expect(sub.top, item.top - st.padding);
      expect(tester.getSemantics(find.text('Share')).getSemanticsData().flagsCollection.isExpanded, Tristate.isTrue);
      await key(tester, LogicalKeyboardKey.arrowDown);
      await key(tester, LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(panel, findsNWidgets(1));
      expect(highlighted(tester), 'Share');
      await key(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(panel, findsNWidgets(2), reason: 'Enter opens it too');
      await key(tester, LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(panel, findsNWidgets(1), reason: 'Escape closes the submenu first');
      await key(tester, LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await key(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(picked, ['share-link']);
      expect(panel, findsNothing, reason: 'a pick in a submenu closes the whole menu');
    });

    testWidgets('submenu: opens 140 ms after the pointer reaches its item; a tap inside does not close the menu', (
      tester,
    ) async {
      useScreen(tester);
      final picked = <Object>[];
      await tester.pumpWidget(
        app(at(const Offset(40, 40), menu(items: docItems, onSelect: (e) => picked.add(e.value)))),
      );
      await tester.tap(find.text('Actions'));
      await tester.pumpAndSettle();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: tester.getCenter(find.text('Share')));
      await mouse.moveTo(tester.getCenter(find.text('Share')) + const Offset(1, 0));
      await tester.pump(const Duration(milliseconds: 100));
      expect(panel, findsNWidgets(1));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpAndSettle();
      expect(panel, findsNWidgets(2));
      await mouse.moveTo(tester.getCenter(find.text('Email')));
      await tester.pumpAndSettle();
      await mouse.down(tester.getCenter(find.text('Email')));
      await mouse.up();
      await tester.pumpAndSettle();
      expect(picked, ['share-email']);
      expect(panel, findsNothing);
    });

    testWidgets('context menu: a secondary click opens it at the pointer; Shift+F10 under the child', (tester) async {
      useScreen(tester);
      var opened = 0;
      await tester.pumpWidget(
        app(
          at(
            const Offset(20, 20),
            KakaoMenu.context(
              items: fileItems,
              onOpen: () => opened++,
              child: const KakaoButton(label: 'Target', onPressed: _noop),
            ),
          ),
        ),
      );
      final where = tester.getTopLeft(find.text('Target')) + const Offset(10, 5);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
      addTearDown(mouse.removePointer);
      await mouse.down(where);
      await mouse.up();
      await tester.pumpAndSettle();
      expect(opened, 1);
      expect(tester.getTopLeft(panel), where);
      await key(tester, LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(panel, findsNothing);

      await key(tester, LogicalKeyboardKey.tab);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.f10);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(panel, findsOneWidget);
      expect(tester.getTopLeft(panel).dy, greaterThan(tester.getBottomLeft(find.byType(KakaoButton)).dy));
      expect(highlighted(tester), 'Rename');
    });

    testWidgets('context menu: a long touch press opens it', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(
        app(
          at(const Offset(20, 20), KakaoMenu.context(items: fileItems, child: const SizedBox(width: 200, height: 100))),
        ),
      );
      await tester.longPressAt(const Offset(60, 60));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(panel), const Offset(60, 60));
    });

    testWidgets('openAt by script: the corner on the point, flipped when it would leave the screen', (tester) async {
      useScreen(tester);
      final c = KakaoMenuController();
      addTearDown(c.dispose);
      await tester.pumpWidget(app(at(Offset.zero, menu(controller: c))));
      c.openAt(const Offset(120, 160));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(panel), const Offset(120, 160));
      c.openAt(const Offset(390, 790));
      await tester.pumpAndSettle();
      final r = tester.getRect(panel);
      expect(r.right, 390);
      expect(r.bottom, 790);
    });

    testWidgets('disabled: does not open', (tester) async {
      useScreen(tester);
      final c = KakaoMenuController();
      addTearDown(c.dispose);
      await tester.pumpWidget(app(at(Offset.zero, menu(controller: c, disabled: true))));
      c.open();
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
    });

    testWidgets('fades in with the slide; with reduced motion it appears at once', (tester) async {
      useScreen(tester);
      for (final reduce in [false, true]) {
        final c = KakaoMenuController();
        addTearDown(c.dispose);
        // No disabled rows: their opacity would be a layer too.
        await tester.pumpWidget(
          app(
            at(const Offset(40, 40), menu(controller: c, items: docItems)),
            reduceMotion: reduce,
          ),
        );
        c.open();
        await tester.pump();
        await tester.pump();
        final layer = tester.layers.whereType<OpacityLayer>().last;
        expect(layer.alpha, reduce ? 255 : lessThan(255));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('colours from the theme, more-contrast too; danger rows', (tester) async {
      useScreen(tester);
      for (final hc in [false, true]) {
        final c = KakaoMenuController();
        addTearDown(c.dispose);
        await tester.pumpWidget(app(at(const Offset(40, 40), menu(controller: c)), highContrast: hc));
        c.open();
        await tester.pumpAndSettle();
        final colors = hc ? KakaoThemeData.light.highContrast : KakaoThemeData.light.colors;
        final st = KakaoMenuSettings.of(colors);
        expect(tester.widget<Text>(find.text('Delete')).style!.color, st.danger);
        final box = tester.widget<DecoratedBox>(find.descendant(of: panel, matching: find.byType(DecoratedBox)).first);
        expect((box.decoration as BoxDecoration).color, st.bg);
      }
    });

    testWidgets('semantics: a menu of menu items, named by label', (tester) async {
      useScreen(tester);
      final c = KakaoMenuController();
      addTearDown(c.dispose);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        app(
          at(
            Offset.zero,
            KakaoMenu(items: fileItems, label: 'File', controller: c, anchorBuilder: (_, _) => const SizedBox()),
          ),
        ),
      );
      c.open();
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('File'), findsOneWidget);
      expect(tester.getSemantics(find.text('Rename')).getSemanticsData().role, SemanticsRole.menuItem);
      expect(tester.getSemantics(find.text('Archive')).getSemanticsData().flagsCollection.isEnabled, Tristate.isFalse);
      handle.dispose();
    });

    testWidgets('inline: always shown, one tab stop, picks keep it shown', (tester) async {
      useScreen(tester);
      final picked = <Object>[];
      await tester.pumpWidget(
        app(
          Align(
            alignment: Alignment.topLeft,
            child: KakaoMenu.inline(
              items: const [
                KakaoMenuItem('Reply', shortcut: 'R'),
                KakaoMenuItem('Forward', shortcut: 'F'),
              ],
              onSelect: (e) => picked.add(e.value),
            ),
          ),
        ),
      );
      expect(find.text('Reply'), findsOneWidget);
      expect(highlighted(tester), isNull);
      await key(tester, LogicalKeyboardKey.tab);
      expect(highlighted(tester), 'Reply');
      await key(tester, LogicalKeyboardKey.keyF);
      expect(highlighted(tester), 'Forward');
      await key(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(picked, ['Forward']);
      expect(find.text('Reply'), findsOneWidget);
    });
  });
}

void _noop() {}
