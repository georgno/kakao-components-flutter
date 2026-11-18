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
  // text-input/demo.html "With label and hint": #t1.
  'text-input-basic': (_) => const KakaoTextInput(
    label: 'Email',
    type: KakaoTextInputType.email,
    placeholder: 'you@example.com',
    hint: 'We only use it for receipts.',
  ),
  // text-input/demo.html "Search · icon + clearable": #t2, its inline SVG
  // drawn the same.
  'text-input-search': (_) => const KakaoTextInput(
    type: KakaoTextInputType.search,
    label: 'Search',
    clearable: true,
    value: 'kakao',
    placeholder: 'Search components',
    icon: SearchGlyph(),
  ),
  // text-input/demo.html "Error".
  'text-input-error': (_) =>
      const KakaoTextInput(label: 'Workspace', value: 'acme', error: 'That name is already taken.'),
  // text-input/demo.html "Sizes" and "Disabled · readonly": display grid,
  // gap 0.6rem.
  'text-input-sizes': (_) => _fields(const [
    KakaoTextInput(size: KakaoTextInputSize.sm, label: 'Small', value: '36px'),
    KakaoTextInput(label: 'Medium', value: '44px'),
    KakaoTextInput(size: KakaoTextInputSize.lg, label: 'Large', value: '52px'),
  ]),
  'text-input-states': (_) => _fields(const [
    KakaoTextInput(disabled: true, label: 'Disabled', value: 'Not now'),
    KakaoTextInput(readOnly: true, label: 'Read only', value: 'Copied elsewhere'),
  ]),
  // textarea/demo.html "With label": #a1 (rows 4: Chromium sizes it by its
  // content, so the 88 px min-height).
  'textarea-basic': (_) => const KakaoTextarea(label: 'Message', placeholder: 'Write a message…'),
  // textarea/demo.html "Counter", "Auto-growing", "Error".
  'textarea-counter': (_) =>
      const KakaoTextarea(label: 'Bio', maxLength: 140, counter: true, value: 'Design systems, mostly.'),
  'textarea-autosize': (_) => const KakaoTextarea(label: 'Notes', autosize: true, hint: 'Grows with what you type.'),
  'textarea-error': (_) =>
      const KakaoTextarea(label: 'Reason', value: 'Too short', error: 'Please write at least 20 characters.'),
  // textarea/demo.html "Sizes · resize": display grid, gap .6rem.
  'textarea-sizes': (_) => _fields(const [
    KakaoTextarea(size: KakaoTextareaSize.sm, value: 'Small', semanticLabel: 'Small text area'),
    KakaoTextarea(
      size: KakaoTextareaSize.lg,
      resize: KakaoTextareaResize.none,
      value: 'Large, no resize',
      semanticLabel: 'Large text area',
    ),
  ]),
  // number-input/demo.html "Variants": the kakao-number-input in each card,
  // at the page's font-size (16px, inherited by the input).
  'number-input-default': (_) =>
      _page16(const KakaoNumberInput(value: 10, min: 0, max: 100, semanticLabel: 'Quantity')),
  'number-input-sm': (_) => _page16(
    const KakaoNumberInput(
      size: KakaoNumberInputSize.sm,
      value: 2.5,
      min: 0,
      max: 10,
      step: .5,
      semanticLabel: 'Hours',
    ),
  ),
  'number-input-touch': (_) =>
      _page16(const KakaoNumberInput(value: 10, min: 0, max: 100, touchSteppers: true, semanticLabel: 'Quantity')),
  'number-input-touch-left': (_) => _page16(
    const KakaoNumberInput(
      value: 10,
      touchSteppers: true,
      groupPosition: KakaoStepperSide.left,
      semanticLabel: 'Quantity',
    ),
  ),
  'number-input-touch-split': (_) => _page16(
    const KakaoNumberInput(
      value: 10,
      touchSteppers: true,
      grouped: false,
      plus: KakaoStepperSide.left,
      semanticLabel: 'Quantity',
    ),
  ),
  'number-input-touch-plus-only': (_) => _page16(
    const KakaoNumberInput(value: 10, touchSteppers: true, minus: KakaoStepperSide.none, semanticLabel: 'Quantity'),
  ),
  'number-input-disabled': (_) => _page16(const KakaoNumberInput(value: 42, disabled: true, semanticLabel: 'Locked')),
  // date-input/demo.html "Types" and "Today shortcut": the field in each
  // card (Chromium draws it in en-US in the look-alike run).
  'date-input-date': (_) => const KakaoDateInput(label: 'Start date', value: '2026-03-04', hint: 'Value 2026-03-04'),
  'date-input-time': (_) => const KakaoDateInput(
    type: KakaoDateInputType.time,
    label: 'Start time',
    value: '09:30',
    step: 900,
    hint: 'Picker in 15-minute steps (Chromium)',
  ),
  'date-input-datetime': (_) =>
      const KakaoDateInput(type: KakaoDateInputType.dateTimeLocal, label: 'Meeting', value: '2026-03-04T14:30'),
  'date-input-month': (_) => const KakaoDateInput(
    type: KakaoDateInputType.month,
    label: 'Billing month',
    value: '2026-03',
    hint: 'Firefox and desktop Safari have no month field: type YYYY-MM.',
  ),
  'date-input-week': (_) => const KakaoDateInput(
    type: KakaoDateInputType.week,
    label: 'Sprint week',
    value: '2026-W10',
    hint: 'Firefox and desktop Safari have no week field: type YYYY-Www.',
  ),
  'date-input-today': (_) => const KakaoDateInput(today: true, label: 'Entry date', hint: 'Today in one click'),
  // date-input/demo.html "Sizes", "Disabled · read only · error": .stack, gap .6rem.
  'date-input-sizes': (_) => _fields(const [
    KakaoDateInput(size: KakaoDateInputSize.sm, label: 'Small', value: '2026-03-04'),
    KakaoDateInput(label: 'Medium', value: '2026-03-04'),
    KakaoDateInput(size: KakaoDateInputSize.lg, label: 'Large', value: '2026-03-04'),
  ]),
  'date-input-states': (_) => _fields(const [
    KakaoDateInput(disabled: true, label: 'Disabled', value: '2026-03-04'),
    KakaoDateInput(readOnly: true, label: 'Read only', value: '2026-03-04'),
    KakaoDateInput(
      type: KakaoDateInputType.time,
      label: 'Check-in',
      error: 'Check-in starts at 15:00.',
      value: '11:00',
    ),
  ]),
  // time-input/demo.html "Basics" and "Now shortcut" (Chromium draws the
  // field in en-US in the look-alike run).
  'time-input-time': (_) =>
      const KakaoTimeInput(label: 'Start time', value: '14:30', hint: 'Value 14:30, drawn as 2:30 PM or 14:30'),
  'time-input-step': (_) => const KakaoTimeInput(
    label: 'Slot',
    value: '09:15',
    step: 900,
    hint: '15-minute steps: arrow keys and the picker (Chromium)',
  ),
  'time-input-seconds': (_) => const KakaoTimeInput(
    label: 'Lap time',
    value: '00:01:30',
    step: 1,
    hint: 'A step under a minute adds the seconds segment',
  ),
  'time-input-midnight': (_) => const KakaoTimeInput(
    label: 'Night shift starts',
    min: '22:00',
    max: '06:00',
    value: '23:30',
    hint: 'From 22:00 to 06:00',
  ),
  'time-input-now': (_) => const KakaoTimeInput(now: true, label: 'Logged at', hint: 'Now in one click'),
  // time-input/demo.html "Sizes", "Disabled · read only · error": .stack, gap .6rem.
  'time-input-sizes': (_) => _fields(const [
    KakaoTimeInput(size: KakaoTimeInputSize.sm, label: 'Small', value: '14:30'),
    KakaoTimeInput(label: 'Medium', value: '14:30'),
    KakaoTimeInput(size: KakaoTimeInputSize.lg, label: 'Large', value: '14:30'),
  ]),
  'time-input-states': (_) => _fields(const [
    KakaoTimeInput(disabled: true, now: true, label: 'Disabled', value: '14:30'),
    KakaoTimeInput(readOnly: true, now: true, label: 'Read only', value: '14:30'),
    KakaoTimeInput(label: 'Check-in', error: 'Check-in starts at 15:00.', value: '11:00'),
  ]),
  // password-input/demo.html "Basic · show / hide".
  'password-input-basic': (_) => const KakaoPasswordInput(label: 'Password', placeholder: 'Your password'),
  // password-input/demo.html "Hint · error", "Sizes", "Disabled · readonly ·
  // hide-toggle": .stack, display grid, gap .6rem.
  'password-input-hint-error': (_) => _fields(const [
    KakaoPasswordInput(label: 'Password', hint: 'Case sensitive.'),
    KakaoPasswordInput(label: 'Password', value: 'hunter2', error: 'That password is not right.'),
  ]),
  'password-input-sizes': (_) => _fields(const [
    KakaoPasswordInput(size: KakaoPasswordInputSize.sm, label: 'Small', value: '36px tall'),
    KakaoPasswordInput(label: 'Medium', value: '44px tall'),
    KakaoPasswordInput(size: KakaoPasswordInputSize.lg, label: 'Large', value: '52px tall'),
  ]),
  'password-input-states': (_) => _fields(const [
    KakaoPasswordInput(disabled: true, label: 'Disabled', value: 'secret'),
    KakaoPasswordInput(readOnly: true, label: 'Read only', value: 'secret'),
    KakaoPasswordInput(hideToggle: true, label: 'No toggle', value: 'secret'),
  ]),
  // password-input/demo.html "Default requirements" (#p1), "Own requirements".
  'password-input-requirements': (_) => const KakaoPasswordInput(label: 'New password', requirements: true),
  'password-input-list-data': (_) =>
      KakaoPasswordInput(label: 'Passphrase', requirements: true, requirementList: passphraseRequirements),
};

/// Fields in a column with the demo's `gap: .6rem`.
Widget _fields(List<Widget> children) => Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 9.6), children[i]],
  ],
);

/// The demo page's `font: 16px/1.5` (a number input's font-size inherits it).
Widget _page16(Widget child) => DefaultTextStyle.merge(style: const TextStyle(fontSize: 16), child: child);

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
