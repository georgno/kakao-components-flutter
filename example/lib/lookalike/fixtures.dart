import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:kakao_components/kakao_components.dart';

import '../demo_content.dart';
import 'lookalike_app.dart';

/// The Flutter side of each look-alike pair in tool/lookalike/cases.json: the
/// same content as the web demo element of the same id. Text, values and
/// layout follow the demo page; the layout literals name the demo CSS rule
/// they come from (shared/demo.css, or the page's own <style>).
final Map<String, WidgetBuilder> lookalikeFixtures = {
  'button-variants': (_) => _row([
    KakaoButton(label: 'Primary', onPressed: _noop),
    KakaoButton(label: 'Secondary', variant: KakaoButtonVariant.secondary, onPressed: _noop),
    KakaoButton(label: 'Ghost', variant: KakaoButtonVariant.ghost, onPressed: _noop),
    // fas fa-trash on the web; the showcase has no Font Awesome.
    KakaoButton(label: 'Danger', variant: KakaoButtonVariant.danger, icon: const Icon(Icons.delete), onPressed: _noop),
    const KakaoButton(label: 'Disabled'),
  ]),
  'button-sizes': (_) => _row([
    KakaoButton(label: 'Small', size: KakaoButtonSize.sm, onPressed: _noop),
    KakaoButton(label: 'Medium', onPressed: _noop),
    KakaoButton(label: 'Large', size: KakaoButtonSize.lg, onPressed: _noop),
  ]),
  // button/demo.html "Menu": #sort, closed and opened.
  'button-menu': (_) => _row([const _SortMenu(open: false)]),
  'button-menu-open': (c) => Align(
    alignment: Alignment.topLeft,
    child: _SortMenu(open: LookalikeApp.isOpen(c), menuKey: LookalikeApp.subjectOf(c)),
  ),
  // button/demo.html "Segment (exclusive)": Left pressed.
  'button-segment': (_) => _row([alignmentButtons('left', (_) {})]),
  'card-primary': (c) => _card(c, 'Upgrade to Pro', 'Unlimited projects, version history and priority support.', [
    KakaoButton(label: 'Upgrade', onPressed: _noop),
    KakaoButton(label: 'Later', variant: KakaoButtonVariant.ghost, onPressed: _noop),
  ]),
  'card-danger': (c) => _card(c, 'Delete project', 'This removes all files and cannot be undone.', [
    // fas fa-trash on the web.
    KakaoButton(label: 'Delete', variant: KakaoButtonVariant.danger, icon: const Icon(Icons.delete), onPressed: _noop),
    KakaoButton(label: 'Cancel', variant: KakaoButtonVariant.secondary, onPressed: _noop),
  ]),
  'card-single-button': (c) => _card(c, 'Invite your team', 'A single button can go straight into the footer.', [
    KakaoButton(label: 'Send invites', variant: KakaoButtonVariant.secondary, onPressed: _noop),
  ]),
  'progress-segments': (_) => _bars(const [
    KakaoProgress(label: 'One segment', segments: 1, value: 0.62, showValue: true),
    KakaoProgress(label: 'Step 2 of 3', segments: 3, value: 2, max: 3, showValue: true, valueText: '2 of 3'),
    KakaoProgress(label: 'Four segments (default)', value: 0.6, showValue: true),
    KakaoProgress(label: 'Eight segments', segments: 8, value: 5.5, max: 8, showValue: true),
  ]),
  'progress-sizes': (_) => _bars(const [
    KakaoProgress(size: KakaoProgressSize.sm, label: 'Small', value: 0.45, showValue: true),
    KakaoProgress(label: 'Medium (default)', value: 0.45, showValue: true),
    KakaoProgress(size: KakaoProgressSize.lg, label: 'Large', value: 0.45, showValue: true),
  ]),
  'progress-tones': (_) => _bars(const [
    KakaoProgress(label: 'Primary (default)', value: 0.7, showValue: true),
    KakaoProgress(tone: KakaoProgressTone.success, label: 'Success', value: 1, showValue: true),
    KakaoProgress(
      tone: KakaoProgressTone.warning,
      label: 'Warning',
      value: 0.85,
      showValue: true,
      valueText: '85 of 100 GB',
    ),
    KakaoProgress(tone: KakaoProgressTone.danger, label: 'Danger', value: 0.3, showValue: true),
  ]),
  'menu-icons': (c) => _OpenMenu(
    items: fileMenuItems(subject: LookalikeApp.subjectOf(c)),
    anchor: 'Actions',
  ),
  'menu-groups': (c) => _OpenMenu(
    items: accountMenuItems(subject: LookalikeApp.subjectOf(c)),
    anchor: 'Account',
  ),
  'popover-click': (_) =>
      _OpenPopover(header: const Text('Account'), content: const AccountDetails(), anchor: 'Account info'),
  'popover-list': (_) => const _OpenPopover(
    header: Text('Server status'),
    placement: KakaoPopoverPlacement.right,
    rows: [
      KakaoPopoverRow('Region', 'us-east-1'),
      KakaoPopoverRow('Status', 'Operational'),
      KakaoPopoverRow('Latency', '42ms'),
      KakaoPopoverRow('Uptime', '99.98%'),
    ],
    anchor: 'Server status',
  ),
};

void _noop() {}

/// button/demo.html `#sort`: a secondary show-selected dropdown, opened
/// after the first frame when the case is an `open` one.
class _SortMenu extends StatefulWidget {
  const _SortMenu({required this.open, this.menuKey});

  final bool open;
  final Key? menuKey;

  @override
  State<_SortMenu> createState() => _SortMenuState();
}

class _SortMenuState extends State<_SortMenu> {
  final _controller = KakaoButtonMenuController();

  @override
  void initState() {
    super.initState();
    if (widget.open) WidgetsBinding.instance.addPostFrameCallback((_) => _controller.open());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => KakaoButton(
    label: 'Sort by',
    variant: KakaoButtonVariant.secondary,
    showSelected: true,
    selected: 'newest',
    menu: sortMenuItems,
    onSelect: (_) {},
    menuController: _controller,
    menuKey: widget.menuKey,
  );
}

/// popover/demo.html: a small secondary button and its popover, opened
/// after the first frame when the case is an `open` one.
class _OpenPopover extends StatefulWidget {
  const _OpenPopover({
    required this.header,
    this.content,
    this.rows,
    this.placement = KakaoPopoverPlacement.bottom,
    required this.anchor,
  });

  final Widget header;
  final Widget? content;
  final List<KakaoPopoverRow>? rows;
  final KakaoPopoverPlacement placement;
  final String anchor;

  @override
  State<_OpenPopover> createState() => _OpenPopoverState();
}

class _OpenPopoverState extends State<_OpenPopover> {
  final _controller = KakaoPopoverController();
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started || !LookalikeApp.isOpen(context)) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _controller.open());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The subject: the header, inside the panel.
    final header = KeyedSubtree(key: LookalikeApp.subjectOf(context), child: widget.header);
    return Align(
      alignment: Alignment.topLeft,
      child: KakaoPopover(
        controller: _controller,
        placement: widget.placement,
        header: header,
        content: widget.content,
        rows: widget.rows,
        anchorBuilder: (context, p) => KakaoButton(
          label: widget.anchor,
          variant: KakaoButtonVariant.secondary,
          size: KakaoButtonSize.sm,
          onPressed: p.toggle,
        ),
      ),
    );
  }
}

/// menu/demo.html: a secondary button and its menu, opened after the first
/// frame when the case is an `open` one. The subject key sits on an icon in
/// the panel (see demo_content.dart).
class _OpenMenu extends StatefulWidget {
  const _OpenMenu({required this.items, required this.anchor});

  final List<KakaoMenuEntry> items;
  final String anchor;

  @override
  State<_OpenMenu> createState() => _OpenMenuState();
}

class _OpenMenuState extends State<_OpenMenu> {
  final _controller = KakaoMenuController();
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started || !LookalikeApp.isOpen(context)) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _controller.open());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: KakaoMenu(
        controller: _controller,
        items: widget.items,
        anchorBuilder: (context, m) =>
            KakaoButton(label: widget.anchor, variant: KakaoButtonVariant.secondary, onPressed: m.toggle),
      ),
    );
  }
}

// demo.css `.row`: flex, wrap, gap 0.5rem, items centred.
Widget _row(List<Widget> children) =>
    Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: children);

// progress/demo.html `.bars`: grid, gap 1.25rem.
Widget _bars(List<Widget> children) => Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 20), children[i]],
  ],
);

// card/demo.html: `kakao-card h3[slot="header"] { font-size: 1.05rem;
// letter-spacing: -0.01em }` on the browser's bold h3; `kakao-card p` in
// --muted; body text 16px / 1.5 (demo.css `body`).
Widget _card(BuildContext context, String title, String text, List<Widget> footer) {
  final theme = KakaoTheme.of(context);
  return KakaoCard(
    header: Text(title, style: theme.text(size: 16.8, weight: 700, tracking: -0.01, height: 1.5)),
    footer: footer,
    children: [Text(text, style: theme.text(size: 16, color: theme.colors.muted, height: 1.5))],
  );
}
