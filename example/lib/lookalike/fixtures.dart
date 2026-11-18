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
  // multi-dropdown/demo.html "Known date · year range", closed with every part set.
  'multi-dropdown-closed': (_) =>
      const KakaoMultiDropdown.date(label: 'Appointment', minYear: 2026, maxYear: 2030, value: '30.10.2026'),
  // multi-dropdown/demo.html `#dob` with its month list open.
  'multi-dropdown-open': (c) => _Dob(open: LookalikeApp.isOpen(c), panelKey: LookalikeApp.subjectOf(c)),
  // multi-dropdown/demo.html "Disabled".
  'multi-dropdown-disabled': (_) => const KakaoMultiDropdown.date(label: 'Locked', value: '01.01.2000', disabled: true),
  // select/demo.html "Single · child options": #s1, closed and opened.
  'select-closed': (_) => const _Countries(),
  'select-open': (c) => _Countries(open: LookalikeApp.isOpen(c), panelKey: LookalikeApp.subjectOf(c)),
  // select/demo.html "Disabled · error": display grid, gap 0.6rem.
  'select-states': (_) => const Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      KakaoSelect(
        disabled: true,
        label: 'Disabled',
        options: [KakaoSelectOption('One'), KakaoSelectOption('Two')],
        values: ['One'],
      ),
      SizedBox(height: 9.6),
      KakaoSelect(
        label: 'Plan',
        error: 'Pick a plan to continue.',
        options: [KakaoSelectOption('Free'), KakaoSelectOption('Pro'), KakaoSelectOption('Team')],
      ),
    ],
  ),
  // combobox/demo.html "Strict · only listed values": closed, with a value.
  'combobox-closed': (_) => const KakaoCombobox(
    label: 'Currency',
    strict: true,
    value: 'eur',
    hint: 'Unlisted text goes back to the last value.',
    options: comboCurrencies,
  ),
  // combobox/demo.html `#c1`, opened while filtering by "ch".
  'combobox-open': (c) => _ComboCountries(open: LookalikeApp.isOpen(c), panelKey: LookalikeApp.subjectOf(c)),
  // combobox/demo.html "Disabled · error": display grid, gap 0.6rem.
  'combobox-states': (_) => const Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      KakaoCombobox(
        disabled: true,
        label: 'Disabled',
        options: [KakaoComboboxOption('One'), KakaoComboboxOption('Two')],
        value: 'One',
      ),
      SizedBox(height: 9.6),
      KakaoCombobox(
        label: 'Plan',
        error: 'Pick or name a plan.',
        options: [KakaoComboboxOption('Free'), KakaoComboboxOption('Pro'), KakaoComboboxOption('Team')],
      ),
    ],
  ),
  // command-palette/demo.html `#main-palette`, opened from its button: with
  // all commands, after typing "fi", and after typing "xyz" (nothing found).
  'command-palette-open': (c) => _Palette(open: LookalikeApp.isOpen(c), panelKey: LookalikeApp.subjectOf(c)),
  'command-palette-filter': (c) =>
      _Palette(open: LookalikeApp.isOpen(c), panelKey: LookalikeApp.subjectOf(c), query: 'fi'),
  'command-palette-empty': (c) =>
      _Palette(open: LookalikeApp.isOpen(c), panelKey: LookalikeApp.subjectOf(c), query: 'xyz'),
};

void _noop() {}

/// The demo's hotkey palette on a page of its own (a navigator over the whole
/// screen, as the web palette covers the viewport); when [open], opened after
/// the first frame with [query] in the field, as the case's `open` click and
/// `type` do on the web.
class _Palette extends StatefulWidget {
  const _Palette({this.open = false, this.panelKey, this.query = ''});

  final bool open;
  final Key? panelKey;
  final String query;

  @override
  State<_Palette> createState() => _PaletteState();
}

class _PaletteState extends State<_Palette> {
  final _overlay = OverlayPortalController()..show();
  final _palette = KakaoCommandPaletteController();

  @override
  void initState() {
    super.initState();
    if (widget.open) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _palette.open(widget.query));
    }
  }

  @override
  void dispose() {
    _palette.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OverlayPortal(
    controller: _overlay,
    overlayChildBuilder: (context) => Navigator(
      onGenerateRoute: (_) => PageRouteBuilder<void>(
        pageBuilder: (context, _, _) => ColoredBox(
          color: KakaoTheme.of(context).colors.page,
          child: KakaoCommandPalette(
            commands: paletteCommands,
            controller: _palette,
            recent: 5,
            panelKey: widget.panelKey,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    ),
    child: const SizedBox(height: 1),
  );
}

/// combobox/demo.html `#c1`; when [open], focused after the first frame and
/// "ch" typed into it, as the case's `open` click and `type` do on the web.
class _ComboCountries extends StatefulWidget {
  const _ComboCountries({this.open = false, this.panelKey});

  final bool open;
  final Key? panelKey;

  @override
  State<_ComboCountries> createState() => _ComboCountriesState();
}

class _ComboCountriesState extends State<_ComboCountries> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    if (!widget.open) return;
    // Focus first (the first focus in a Flutter web view focuses the view
    // and moves focus to its first focusable widget), then type.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focus.requestFocus();
      Future<void>.delayed(const Duration(milliseconds: 200), _type);
    });
  }

  /// Types "ch" as the user would: through the field's editing state, so it
  /// filters as typing does.
  void _type() {
    if (!mounted) return;
    EditableTextState? editable;
    void visit(Element e) {
      if (e is StatefulElement && e.state is EditableTextState) editable = e.state as EditableTextState;
      if (editable == null) e.visitChildren(visit);
    }

    context.visitChildElements(visit);
    editable?.userUpdateTextEditingValue(
      const TextEditingValue(text: 'ch', selection: TextSelection.collapsed(offset: 2)),
      SelectionChangedCause.keyboard,
    );
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => KakaoCombobox(
    label: 'Country',
    placeholder: 'Pick or type a country',
    hint: '“osterr” finds Österreich. Any other text is kept too.',
    options: comboCountries,
    focusNode: _focus,
    panelKey: widget.panelKey,
  );
}

/// multi-dropdown/demo.html `#dob`; when [open], its month list opens after
/// the first frame, as the case's click does.
class _Dob extends StatefulWidget {
  const _Dob({this.open = false, this.panelKey});

  final bool open;
  final Key? panelKey;

  @override
  State<_Dob> createState() => _DobState();
}

class _DobState extends State<_Dob> {
  final _controller = KakaoMultiDropdownController();

  @override
  void initState() {
    super.initState();
    if (!widget.open) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 200), () => _controller.open('month'));
    });
  }

  @override
  Widget build(BuildContext context) => KakaoMultiDropdown.date(
    label: 'Date of birth',
    allowUnknown: const {'day', 'month'},
    value: '00.00.1990',
    controller: _controller,
    panelKey: widget.panelKey,
  );
}

/// select/demo.html `#s1`, opened after the first frame when [open].
class _Countries extends StatefulWidget {
  const _Countries({this.open = false, this.panelKey});

  final bool open;
  final Key? panelKey;

  @override
  State<_Countries> createState() => _CountriesState();
}

class _CountriesState extends State<_Countries> {
  final _controller = KakaoSelectController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    if (!widget.open) return;
    // Focus the field first, as the click on the web does: the first focus
    // in a Flutter web view focuses the view, which moves focus to its first
    // focusable widget and would take it from the search again.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focus.requestFocus();
      Future<void>.delayed(const Duration(milliseconds: 200), _controller.open);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => KakaoSelect(
    label: 'Country',
    hint: 'Type to filter: “osterr” finds Österreich.',
    options: countryOptions,
    values: const ['de'],
    controller: _controller,
    focusNode: _focus,
    panelKey: widget.panelKey,
  );
}

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
