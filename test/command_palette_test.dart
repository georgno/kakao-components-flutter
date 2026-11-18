// KakaoCommandPalette (command-palette.js).
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakao_components/kakao_components.dart';

// command-palette/demo.html `#main-palette`.
const commands = [
  KakaoCommand('New file', id: 'new-file', group: 'File', shortcut: 'Mod+N'),
  KakaoCommand('Open file…', id: 'open-file', group: 'File', shortcut: 'Mod+O'),
  KakaoCommand('Save', id: 'save', group: 'File', shortcut: 'Mod+S'),
  KakaoCommand('Export as PDF', id: 'export', group: 'File', keywords: ['download', 'print']),
  KakaoCommand('Share with team', id: 'share', group: 'File', disabled: true),
  KakaoCommand('Go to components', id: 'components', group: 'Navigation'),
  KakaoCommand('Go to style guide', id: 'styleguide', group: 'Navigation'),
  KakaoCommand('Change theme', id: 'theme', group: 'Preferences', keywords: ['dark', 'light', 'colours']),
  KakaoCommand('Change language', id: 'language', group: 'Preferences', keywords: ['locale']),
  KakaoCommand('Edit profile', id: 'profile', group: 'Account'),
  KakaoCommand('Sign out', id: 'sign-out', group: 'Account', keywords: ['logout', 'exit']),
];

final _button = FocusNode(debugLabel: 'page button');
final _panel = GlobalKey();

Widget app(Widget page, {bool reduceMotion = false, bool highContrast = false}) => WidgetsApp(
  color: const Color(0xFFFFFFFF),
  pageRouteBuilder: <T>(RouteSettings s, WidgetBuilder b) =>
      PageRouteBuilder<T>(settings: s, pageBuilder: (c, _, _) => b(c)),
  home: page,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion, highContrast: highContrast),
    child: KakaoTheme(data: KakaoThemeData.light, child: child!),
  ),
);

/// A page with a focusable "button" and a palette around it.
Widget page({
  KakaoCommandPaletteController? controller,
  List<KakaoCommand> list = commands,
  String? hotkey = 'Mod+K',
  int recent = 0,
  ValueChanged<KakaoCommandSelect>? onSelect,
  VoidCallback? onClose,
  Widget? extra,
}) => KakaoCommandPalette(
  commands: list,
  controller: controller,
  hotkey: hotkey,
  recent: recent,
  onSelect: onSelect,
  onClose: onClose,
  panelKey: _panel,
  child: ColoredBox(
    color: const Color(0xFFFFFFFF),
    child: Column(
      children: [
        Focus(focusNode: _button, child: const SizedBox(width: 100, height: 40)),
        ?extra,
      ],
    ),
  ),
);

void useScreen(WidgetTester tester, [Size size = const Size(1280, 900)]) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> ctrlK(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

Future<void> type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(EditableText), text);
  await tester.pumpAndSettle();
}

/// The labels of the rows in order.
List<String> rowLabels(WidgetTester tester) => [
  for (final e in tester.widgetList<Semantics>(
    find.descendant(of: find.byKey(_panel), matching: find.byType(Semantics)),
  ))
    if (e.properties.button == true && e.properties.label != null) e.properties.label!,
];

/// The text of a heading or row as drawn.
bool shown(String text) => find.descendant(of: find.byKey(_panel), matching: find.text(text)).evaluate().isNotEmpty;

KakaoCommandPaletteSettings settings({bool contrast = false}) =>
    KakaoCommandPaletteSettings.of(contrast ? KakaoThemeData.light.highContrast : KakaoThemeData.light.colors);

Color? activeBackground(WidgetTester tester, String label) {
  final row = find.ancestor(
    of: find.descendant(of: find.byKey(_panel), matching: find.text(label, findRichText: true)),
    matching: find.byType(AnimatedContainer),
  );
  final c = tester.widget<AnimatedContainer>(row.first);
  return (c.decoration! as BoxDecoration).color;
}

void main() {
  setUp(() => _button.unfocus());

  testWidgets('Ctrl+K opens with focus in the field; Escape closes and gives focus back', (tester) async {
    useScreen(tester);
    var closed = 0;
    await tester.pumpWidget(app(page(onClose: () => closed++)));
    _button.requestFocus();
    await tester.pump();
    await ctrlK(tester);
    expect(find.byKey(_panel), findsOneWidget);
    final editable = tester.state<EditableTextState>(find.byType(EditableText));
    expect(editable.widget.focusNode.hasPrimaryFocus, isTrue);
    expect(editable.widget.controller.text, '');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(_panel), findsNothing);
    expect(_button.hasPrimaryFocus, isTrue);
    expect(closed, 1);
  });

  testWidgets('the hotkey closes it again; hotkey "none" opens nothing', (tester) async {
    useScreen(tester);
    await tester.pumpWidget(app(page()));
    await ctrlK(tester);
    expect(find.byKey(_panel), findsOneWidget);
    await ctrlK(tester);
    expect(find.byKey(_panel), findsNothing);

    await tester.pumpWidget(app(page(hotkey: 'none')));
    await ctrlK(tester);
    expect(find.byKey(_panel), findsNothing);
  });

  testWidgets('a hotkey without Ctrl, Meta or Alt does nothing while a text field has focus', (tester) async {
    useScreen(tester);
    final text = TextEditingController();
    final focus = FocusNode();
    addTearDown(text.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      app(
        page(
          hotkey: '/',
          extra: SizedBox(
            width: 200,
            height: 30,
            child: EditableText(
              controller: text,
              focusNode: focus,
              style: const TextStyle(fontSize: 14),
              cursorColor: const Color(0xFF000000),
              backgroundCursorColor: const Color(0xFF888888),
            ),
          ),
        ),
      ),
    );
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.slash);
    await tester.pumpAndSettle();
    expect(find.byKey(_panel), findsNothing);

    _button.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.slash);
    await tester.pumpAndSettle();
    expect(find.byKey(_panel), findsOneWidget);
  });

  testWidgets('groups in order under their headings; the first enabled row is active', (tester) async {
    useScreen(tester);
    final ctl = KakaoCommandPaletteController();
    await tester.pumpWidget(app(page(controller: ctl)));
    ctl.open();
    await tester.pumpAndSettle();
    expect(ctl.isOpen, isTrue);
    for (final h in ['File', 'Navigation', 'Preferences', 'Account']) {
      expect(shown(h), isTrue, reason: h);
    }
    expect(rowLabels(tester).take(3), ['New file', 'Open file…', 'Save']);
    expect(shown('Mod+N'), isTrue);
    final st = settings();
    expect(activeBackground(tester, 'New file'), st.hoverBg);
    expect(activeBackground(tester, 'Save'), st.hoverBg.withValues(alpha: 0));
  });

  testWidgets('search: substring with marks, letters in order, keywords, accents', (tester) async {
    useScreen(tester);
    final ctl = KakaoCommandPaletteController();
    await tester.pumpWidget(app(page(controller: ctl)));
    ctl.open();
    await tester.pumpAndSettle();

    await type(tester, 'nwf');
    expect(rowLabels(tester), ['New file']);
    final rich = tester.widget<RichText>(
      find.descendant(of: find.byKey(_panel), matching: find.textContaining('ew file', findRichText: true)).first,
    );
    final marked = <String>[];
    rich.text.visitChildren((s) {
      if (s is TextSpan && s.style?.color == settings().match) marked.add(s.text!);
      return true;
    });
    expect(marked, ['N', 'w', 'f']);

    await type(tester, 'logout');
    expect(rowLabels(tester), ['Sign out']);
    await type(tester, 'théme');
    expect(rowLabels(tester), ['Change theme']);
    await type(tester, 'set');
    expect(rowLabels(tester), isEmpty);
  });

  testWidgets('results: the group with the best match first; nothing found shows the empty text', (tester) async {
    useScreen(tester);
    final ctl = KakaoCommandPaletteController();
    await tester.pumpWidget(app(page(controller: ctl)));
    ctl.open('fi');
    await tester.pumpAndSettle();
    // "New file" matches at a word start (File), "Edit profile" inside a word (Account).
    final labels = rowLabels(tester);
    expect(labels.indexOf('New file'), lessThan(labels.indexOf('Edit profile')));

    await type(tester, 'zzz');
    expect(rowLabels(tester), isEmpty);
    expect(shown('No matching commands'), isTrue);
  });

  testWidgets('keys: Down skips the disabled row and wraps; Home / End; Page Down eight on', (tester) async {
    useScreen(tester);
    final ctl = KakaoCommandPaletteController();
    final picked = <String>[];
    await tester.pumpWidget(app(page(controller: ctl, onSelect: (e) => picked.add(e.id))));
    ctl.open('go to');
    await tester.pumpAndSettle();
    expect(rowLabels(tester), ['Go to components', 'Go to style guide']);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(activeBackground(tester, 'Go to components'), settings().hoverBg);

    await type(tester, '');
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pumpAndSettle();
    expect(activeBackground(tester, 'Sign out'), settings().hoverBg);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pumpAndSettle();
    // Eight enabled rows on from "New file", "Share with team" skipped.
    expect(activeBackground(tester, 'Edit profile'), settings().hoverBg);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(picked, ['profile']);
  });

  testWidgets('Enter runs: the palette closes, then onSelect gets id and value', (tester) async {
    useScreen(tester);
    final ctl = KakaoCommandPaletteController();
    final log = <String>[];
    await tester.pumpWidget(
      app(
        page(
          controller: ctl,
          list: const [
            KakaoCommand('New file', id: 'new'),
            KakaoCommand('Clear cache', value: 'all'),
          ],
          onSelect: (e) => log.add('select ${e.id} ${e.value} open=${ctl.isOpen}'),
          onClose: () => log.add('close'),
        ),
      ),
    );
    ctl.open();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(log, ['close', 'select new new open=false']);
    expect(find.byKey(_panel), findsNothing);

    ctl.open();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(log.last, 'select all all open=false');
  });

  testWidgets('pointer: hover makes a row active, a tap runs it, a disabled one does nothing', (tester) async {
    useScreen(tester);
    final ctl = KakaoCommandPaletteController();
    final picked = <String>[];
    await tester.pumpWidget(app(page(controller: ctl, onSelect: (e) => picked.add(e.id))));
    ctl.open();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share with team'));
    await tester.pumpAndSettle();
    expect(picked, isEmpty);
    expect(ctl.isOpen, isTrue);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(find.text('Save')));
    await mouse.moveTo(tester.getCenter(find.text('Save')));
    await tester.pumpAndSettle();
    expect(activeBackground(tester, 'Save'), settings().hoverBg);
    await mouse.removePointer();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(picked, ['save']);
    expect(ctl.isOpen, isFalse);
  });

  testWidgets('a tap on the scrim closes without running; Tab stays in the field', (tester) async {
    useScreen(tester);
    final ctl = KakaoCommandPaletteController();
    var closed = 0;
    final picked = <String>[];
    await tester.pumpWidget(app(page(controller: ctl, onClose: () => closed++, onSelect: (e) => picked.add(e.id))));
    ctl.open();
    await tester.pumpAndSettle();
    final field = tester.state<EditableTextState>(find.byType(EditableText)).widget.focusNode;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(field.hasPrimaryFocus, isTrue);

    await tester.tapAt(const Offset(10, 880));
    await tester.pumpAndSettle();
    expect(ctl.isOpen, isFalse);
    expect(closed, 1);
    expect(picked, isEmpty);
  });

  testWidgets('recent: the last run commands come first under "Recent"', (tester) async {
    useScreen(tester);
    final ctl = KakaoCommandPaletteController();
    await tester.pumpWidget(app(page(controller: ctl, recent: 5)));
    ctl.open('sign');
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(ctl.recentIds, ['sign-out']);

    ctl.open();
    await tester.pumpAndSettle();
    expect(shown('Recent'), isTrue);
    expect(rowLabels(tester).first, 'Sign out');
    expect(activeBackground(tester, 'Sign out'), settings().hoverBg);
  });

  testWidgets('placement: max width, top 12vh; a phone gets a full-width sheet at the top', (tester) async {
    useScreen(tester);
    final ctl = KakaoCommandPaletteController();
    await tester.pumpWidget(app(page(controller: ctl)));
    ctl.open();
    await tester.pumpAndSettle();
    final st = settings();
    var r = tester.getRect(find.byKey(_panel));
    expect(r.width, st.width);
    expect(r.top, 900 * .12);
    expect(r.center.dx, 640);
    expect(r.height, lessThanOrEqualTo(st.maxHeight));
    ctl.close();
    await tester.pumpAndSettle();

    useScreen(tester, const Size(390, 800));
    ctl.open();
    await tester.pumpAndSettle();
    r = tester.getRect(find.byKey(_panel));
    expect(r.left, 0);
    expect(r.top, 0);
    expect(r.width, 390);
    final box = tester.widget<Container>(find.byKey(_panel)).decoration! as BoxDecoration;
    expect((box.borderRadius! as BorderRadius).topLeft, Radius.zero);
  });

  testWidgets('motion: fades and drops in over the duration; at once with reduced motion', (tester) async {
    useScreen(tester);
    final ctl = KakaoCommandPaletteController();
    await tester.pumpWidget(app(page(controller: ctl)));
    ctl.open();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    final fade = tester.widget<FadeTransition>(
      find.ancestor(of: find.byKey(_panel), matching: find.byType(FadeTransition)).first,
    );
    expect(fade.opacity.value, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    ctl.close();
    await tester.pump();
    expect(find.byKey(_panel), findsNothing); // closes at once

    await tester.pumpWidget(app(page(controller: ctl), reduceMotion: true));
    ctl.open();
    await tester.pump();
    await tester.pump();
    expect(find.ancestor(of: find.byKey(_panel), matching: find.byType(FadeTransition)), findsNothing);
  });

  testWidgets('hints on a desktop, none on touch platforms; touch rows are taller', (tester) async {
    useScreen(tester);
    final ctl = KakaoCommandPaletteController();
    await tester.pumpWidget(app(page(controller: ctl)));
    ctl.open();
    await tester.pumpAndSettle();
    expect(shown('to move'), isFalse);
    expect(tester.getSize(find.text('Save')).height, lessThan(settings().touchOptionHeight));
    final touchRow = find.ancestor(of: find.text('Save'), matching: find.byType(AnimatedContainer)).first;
    expect(tester.getSize(touchRow).height, settings().touchOptionHeight);
    ctl.close();
    await tester.pumpAndSettle();

    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    ctl.open();
    await tester.pumpAndSettle();
    expect(shown('to move'), isTrue);
    expect(shown('Esc'), isTrue);
    final row = find.ancestor(of: find.text('Save'), matching: find.byType(AnimatedContainer)).first;
    expect(tester.getSize(row).height, settings().optionHeight);
    ctl.close();
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('more contrast: colours from the more-contrast theme', (tester) async {
    useScreen(tester);
    final ctl = KakaoCommandPaletteController();
    await tester.pumpWidget(app(page(controller: ctl), highContrast: true));
    ctl.open();
    await tester.pumpAndSettle();
    final st = settings(contrast: true);
    final box = tester.widget<Container>(find.byKey(_panel)).decoration! as BoxDecoration;
    expect(box.color, st.bg);
    expect(activeBackground(tester, 'New file'), st.hoverBg);
  });

  testWidgets('inline: in place, no hints; Escape clears the query; running clears it too', (tester) async {
    useScreen(tester);
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final picked = <String>[];
    await tester.pumpWidget(
      app(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 500,
            child: KakaoCommandPalette(
              inline: true,
              panelKey: _panel,
              emptyText: 'Nothing found, try “copy”',
              commands: const [
                KakaoCommand('Copy link', id: 'copy', group: 'Share', shortcut: 'Mod+Shift+C'),
                KakaoCommand('Rename', id: 'rename', group: 'Edit', shortcut: 'F2'),
              ],
              onSelect: (e) => picked.add(e.id),
            ),
          ),
        ),
      ),
    );
    expect(tester.getRect(find.byKey(_panel)).topLeft, Offset.zero);
    expect(shown('to move'), isFalse);
    await tester.tap(find.byType(EditableText));
    await type(tester, 'xyz');
    expect(shown('Nothing found, try “copy”'), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(rowLabels(tester), ['Copy link', 'Rename']);
    await type(tester, 'ren');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(picked, ['rename']);
    expect(tester.state<EditableTextState>(find.byType(EditableText)).widget.controller.text, '');
    expect(find.byKey(_panel), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}
