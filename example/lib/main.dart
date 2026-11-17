import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kakao_components/kakao_components.dart';

import 'build_info.dart';
import 'demo_content.dart';
import 'lookalike/lookalike_app.dart';
import 'updater/updater.dart';

void main() {
  // tool/lookalike opens the web build with ?lookalike=<case>.
  final lookalike = LookalikeApp.queryOf(Uri.base);
  runApp(lookalike != null ? LookalikeApp(query: lookalike) : const ShowcaseApp());
}

class ShowcaseApp extends StatefulWidget {
  const ShowcaseApp({super.key});

  @override
  State<ShowcaseApp> createState() => _ShowcaseAppState();
}

class _ShowcaseAppState extends State<ShowcaseApp> {
  final _navigator = GlobalKey<NavigatorState>();
  KakaoThemeData? _chosen; // null: follow the system, like the web without data-kakao-theme

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kakao showcase',
      navigatorKey: _navigator,
      debugShowCheckedModeBanner: false,
      builder: (context, navigator) {
        final system = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
        final theme = _chosen ?? (system ? KakaoThemeData.dark : KakaoThemeData.light);
        return KakaoTheme(
          data: theme,
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: theme.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
            child: Updater(
              navigatorKey: _navigator,
              child: _ThemeChoice(chosen: _chosen, onChoose: (t) => setState(() => _chosen = t), child: navigator!),
            ),
          ),
        );
      },
      home: const ShowcaseHome(),
    );
  }
}

/// Hands the theme choice down to the pages.
class _ThemeChoice extends InheritedWidget {
  const _ThemeChoice({required this.chosen, required this.onChoose, required super.child});

  final KakaoThemeData? chosen;
  final ValueChanged<KakaoThemeData?> onChoose;

  static _ThemeChoice of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_ThemeChoice>()!;

  @override
  bool updateShouldNotify(_ThemeChoice old) => old.chosen != chosen;
}

class ShowcaseHome extends StatefulWidget {
  const ShowcaseHome({super.key});

  @override
  State<ShowcaseHome> createState() => _ShowcaseHomeState();
}

class _ShowcaseHomeState extends State<ShowcaseHome> {
  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    final c = theme.colors;
    final choice = _ThemeChoice.of(context);

    return ColoredBox(
      color: c.page,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text('Kakao showcase', style: theme.step(theme.tokens.text2xl)),
            const SizedBox(height: 4),
            Text('Flutter twins of kakao-components', style: theme.step(theme.tokens.textLg, color: c.muted)),
            const SizedBox(height: 20),
            _Section(
              title: 'Theme',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Toggle buttons: the chosen theme shows by weight and
                  // opacity, not by an ink fill (ink is for actions).
                  KakaoButton(
                    label: 'System',
                    size: KakaoButtonSize.sm,
                    variant: KakaoButtonVariant.secondary,
                    toggle: true,
                    pressed: choice.chosen == null,
                    onPressed: () => choice.onChoose(null),
                  ),
                  for (final t in KakaoThemeData.all)
                    KakaoButton(
                      label: _themeName(t),
                      size: KakaoButtonSize.sm,
                      variant: KakaoButtonVariant.secondary,
                      toggle: true,
                      pressed: choice.chosen == t,
                      onPressed: () => choice.onChoose(t),
                    ),
                  // The theme picker (`<kakao-button theme-picker>`): the page
                  // follows the pointer down the list and the pick.
                  KakaoButton(
                    label: 'Theme',
                    size: KakaoButtonSize.sm,
                    variant: KakaoButtonVariant.secondary,
                    showSelected: true,
                    selected: (choice.chosen ?? theme.data).name,
                    menu: [for (final t in KakaoThemeData.all) KakaoButtonMenuItem(t.name, label: _themeName(t))],
                    onMenuHover: (i) => choice.onChoose(KakaoThemeData.all.firstWhere((t) => t.name == i.value)),
                    onSelect: (e) => choice.onChoose(KakaoThemeData.all.firstWhere((t) => t.name == e.value)),
                  ),
                ],
              ),
            ),
            _Section(
              title: 'Button · variants',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final v in KakaoButtonVariant.values)
                    KakaoButton(label: v.name[0].toUpperCase() + v.name.substring(1), variant: v, onPressed: () {}),
                ],
              ),
            ),
            _Section(
              title: 'Button · sizes',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final s in KakaoButtonSize.values)
                    KakaoButton(label: 'Size ${s.name}', size: s, onPressed: () {}),
                ],
              ),
            ),
            _Section(
              title: 'Button · icon, loading, disabled',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  KakaoButton(label: 'Add item', icon: const Icon(Icons.add), onPressed: () {}),
                  KakaoButton(
                    icon: const Icon(Icons.edit_outlined),
                    semanticLabel: 'Edit',
                    variant: KakaoButtonVariant.secondary,
                    onPressed: () {},
                  ),
                  KakaoButton(
                    label: 'Save',
                    onPressedAsync: () => Future<void>.delayed(const Duration(milliseconds: 1500)),
                  ),
                  KakaoButton(
                    label: 'Save (fails)',
                    variant: KakaoButtonVariant.secondary,
                    onPressedAsync: () async {
                      await Future<void>.delayed(const Duration(milliseconds: 1500));
                      throw StateError('demo failure');
                    },
                  ),
                  const KakaoButton(label: 'Disabled'),
                ],
              ),
            ),
            _Section(title: 'Button · menu', child: const _ButtonMenuExamples()),
            _Section(title: 'Button · toggle and segment', child: const _ToggleExamples()),
            const _Heading('Card'),
            const _CardExamples(),
            _Section(title: 'Combobox', child: const _ComboboxExamples()),
            _Section(title: 'Dialog', child: const _DialogExamples()),
            _Section(title: 'Menu', child: const _MenuExamples()),
            _Section(title: 'Popover', child: const _PopoverExamples()),
            _Section(title: 'Progress', child: const _ProgressExamples()),
            _Section(title: 'Select', child: const _SelectExamples()),
            _Section(
              title: 'About this build',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(BuildInfo.label, style: theme.text(color: c.textSoft)),
                  const SizedBox(height: 12),
                  KakaoButton(
                    label: 'Check for updates',
                    variant: KakaoButtonVariant.secondary,
                    size: KakaoButtonSize.sm,
                    onPressed: () => Updater.checkNow(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _themeName(KakaoThemeData t) => t.name[0].toUpperCase() + t.name.substring(1);

/// button/demo.html "Menu": any variant as a dropdown button.
class _ButtonMenuExamples extends StatefulWidget {
  const _ButtonMenuExamples();

  @override
  State<_ButtonMenuExamples> createState() => _ButtonMenuExamplesState();
}

class _ButtonMenuExamplesState extends State<_ButtonMenuExamples> {
  String _log = 'Pick something';

  void _select(KakaoButtonSelectEvent e) =>
      setState(() => _log = 'kakao-button-select · ${e.value}${e.previous == null ? '' : ' (was ${e.previous})'}');

  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            KakaoButton(
              label: 'Sort by',
              variant: KakaoButtonVariant.secondary,
              showSelected: true,
              selected: 'newest',
              menu: sortMenuItems,
              onSelect: _select,
              onMenuChanged: (open) => setState(() => _log = 'kakao-button-menu · open $open'),
            ),
            KakaoButton(
              label: 'Export',
              icon: const Icon(Icons.download),
              menu: const [
                KakaoButtonMenuItem('csv', label: 'CSV'),
                KakaoButtonMenuItem('xlsx', label: 'Excel'),
                KakaoButtonMenuItem('pdf', label: 'PDF'),
              ],
              onSelect: _select,
            ),
            KakaoButton(
              icon: const Icon(Icons.more_horiz),
              semanticLabel: 'More actions',
              variant: KakaoButtonVariant.ghost,
              noChevron: true,
              menu: const [
                KakaoButtonMenuItem('edit', label: 'Edit'),
                KakaoButtonMenuItem('duplicate', label: 'Duplicate'),
                KakaoButtonMenuItem('delete', label: 'Delete'),
              ],
              onSelect: _select,
            ),
            KakaoButton(
              icon: const Icon(Icons.more_vert),
              semanticLabel: 'More actions',
              variant: KakaoButtonVariant.ghost,
              menu: const [
                KakaoButtonMenuItem('rename', label: 'Rename'),
                KakaoButtonMenuItem('move', label: 'Move'),
                KakaoButtonMenuItem('archive', label: 'Archive'),
              ],
              onSelect: _select,
            ),
            KakaoButton(
              label: 'View',
              variant: KakaoButtonVariant.ghost,
              size: KakaoButtonSize.sm,
              showSelected: true,
              selected: 'list',
              menu: const [
                KakaoButtonMenuItem('list', label: 'List'),
                KakaoButtonMenuItem('grid', label: 'Grid'),
                KakaoButtonMenuItem('map', label: 'Map'),
              ],
              onSelect: _select,
            ),
            const KakaoButton(
              label: 'Disabled',
              variant: KakaoButtonVariant.secondary,
              menu: [KakaoButtonMenuItem('never')],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(_log, style: theme.text(color: theme.colors.textSoft)),
      ],
    );
  }
}

/// button/demo.html "Toggle": a single toggle and the exclusive segment.
class _ToggleExamples extends StatefulWidget {
  const _ToggleExamples();

  @override
  State<_ToggleExamples> createState() => _ToggleExamplesState();
}

class _ToggleExamplesState extends State<_ToggleExamples> {
  bool _bold = false;
  String _align = 'left';

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        KakaoButton(
          label: 'Bold',
          icon: const Icon(Icons.format_bold),
          variant: KakaoButtonVariant.secondary,
          toggle: true,
          pressed: _bold,
          onPressed: () => setState(() => _bold = !_bold),
        ),
        // Exclusive: pressing one releases the others (the demo's script).
        alignmentButtons(_align, (v) => setState(() => _align = v)),
      ],
    );
  }
}

/// select/demo.html: single, groups, multiple with select all, sizes,
/// disabled and error.
class _SelectExamples extends StatefulWidget {
  const _SelectExamples();

  @override
  State<_SelectExamples> createState() => _SelectExamplesState();
}

class _SelectExamplesState extends State<_SelectExamples> {
  String _log = 'Pick something';

  void _change(KakaoSelectChange e) =>
      setState(() => _log = 'select-change · ${e.value.isEmpty ? '(nothing)' : e.value} (was ${e.previous.join(',')})');

  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    Widget column(List<Widget> children) => SizedBox(
      width: 320,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 10), children[i]],
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 24,
          runSpacing: 24,
          children: [
            column([
              KakaoSelect(
                label: 'Country',
                hint: 'Type to filter: “osterr” finds Österreich.',
                options: countryOptions,
                values: const ['de'],
                onChanged: _change,
              ),
              KakaoSelect(label: 'City', placeholder: 'Choose a city', options: cityOptions, onChanged: _change),
              KakaoSelect(
                label: 'Genres',
                multiple: true,
                hint: 'Type “ma” and use “Select all N matches”: only the matches change.',
                options: genreOptions,
                values: const ['drama', 'comedy'],
                onChanged: _change,
              ),
            ]),
            column([
              const KakaoSelect(
                size: KakaoSelectSize.sm,
                label: 'Small',
                options: [KakaoSelectOption('36px'), KakaoSelectOption('Other')],
                values: ['36px'],
              ),
              const KakaoSelect(
                label: 'Medium',
                options: [KakaoSelectOption('44px'), KakaoSelectOption('Other')],
                values: ['44px'],
              ),
              const KakaoSelect(
                size: KakaoSelectSize.lg,
                label: 'Large',
                options: [KakaoSelectOption('52px'), KakaoSelectOption('Other')],
                values: ['52px'],
              ),
              const KakaoSelect(
                disabled: true,
                label: 'Disabled',
                options: [KakaoSelectOption('One'), KakaoSelectOption('Two')],
                values: ['One'],
              ),
              const KakaoSelect(
                label: 'Plan',
                error: 'Pick a plan to continue.',
                options: [KakaoSelectOption('Free'), KakaoSelectOption('Pro'), KakaoSelectOption('Team')],
              ),
            ]),
          ],
        ),
        const SizedBox(height: 8),
        Text(_log, style: theme.text(color: theme.colors.textSoft)),
      ],
    );
  }
}

/// combobox/demo.html: suggestions, groups, free text with the "Use" row,
/// inline completion, strict, a long list, sizes, disabled and error.
class _ComboboxExamples extends StatefulWidget {
  const _ComboboxExamples();

  @override
  State<_ComboboxExamples> createState() => _ComboboxExamplesState();
}

class _ComboboxExamplesState extends State<_ComboboxExamples> {
  String _log = 'Pick or type something';

  void _change(KakaoComboboxChange e) => setState(
    () => _log =
        'combobox-change · ${e.value.isEmpty ? '(empty)' : e.value}'
        '${e.option == null ? ' (free text)' : ''} (was ${e.previous.isEmpty ? 'empty' : e.previous})',
  );

  void _create(String value) => setState(() => _log = '$_log · combobox-create · $value');

  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    Widget column(List<Widget> children) => SizedBox(
      width: 320,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 10), children[i]],
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 24,
          runSpacing: 24,
          children: [
            column([
              KakaoCombobox(
                label: 'Country',
                placeholder: 'Pick or type a country',
                hint: '“osterr” finds Österreich. Any other text is kept too.',
                options: comboCountries,
                onChanged: _change,
                onCreate: _create,
              ),
              KakaoCombobox(
                label: 'City',
                placeholder: 'Pick or type a city',
                options: comboCities,
                onChanged: _change,
                onCreate: _create,
              ),
              KakaoCombobox(
                label: 'Tag',
                placeholder: 'Add a tag',
                createLabel: 'Create tag “{text}”',
                hint: 'Type “Release” to see the create row; picking it fires combobox-create.',
                options: comboTags,
                onChanged: _change,
                onCreate: _create,
              ),
              KakaoCombobox(
                label: 'Fruit',
                placeholder: 'Start typing',
                autocomplete: KakaoComboboxAutocomplete.both,
                hint: 'Type “ba”: the field completes to Banana, the added part selected.',
                options: comboFruits,
                onChanged: _change,
              ),
              KakaoCombobox(
                label: 'Currency',
                strict: true,
                value: 'eur',
                hint: 'Unlisted text goes back to the last value.',
                options: comboCurrencies,
                onChanged: _change,
              ),
              KakaoCombobox(
                label: 'Product',
                placeholder: 'Search or name a product',
                options: comboProducts,
                onChanged: _change,
                onCreate: _create,
              ),
            ]),
            column(const [
              KakaoCombobox(
                size: KakaoComboboxSize.sm,
                label: 'Small',
                options: [KakaoComboboxOption('36px'), KakaoComboboxOption('Other')],
                value: '36px',
              ),
              KakaoCombobox(
                label: 'Medium',
                options: [KakaoComboboxOption('44px'), KakaoComboboxOption('Other')],
                value: '44px',
              ),
              KakaoCombobox(
                size: KakaoComboboxSize.lg,
                label: 'Large',
                options: [KakaoComboboxOption('52px'), KakaoComboboxOption('Other')],
                value: '52px',
              ),
              KakaoCombobox(
                disabled: true,
                label: 'Disabled',
                options: [KakaoComboboxOption('One'), KakaoComboboxOption('Two')],
                value: 'One',
              ),
              KakaoCombobox(
                label: 'Plan',
                error: 'Pick or name a plan.',
                options: [KakaoComboboxOption('Free'), KakaoComboboxOption('Pro'), KakaoComboboxOption('Team')],
              ),
              KakaoCombobox(
                label: 'Postcode',
                noCreate: true,
                maxLength: 5,
                hint: 'At most five characters. Free text, no “Use” row.',
                options: [
                  KakaoComboboxOption('1010'),
                  KakaoComboboxOption('10115'),
                  KakaoComboboxOption('20095'),
                  KakaoComboboxOption('8001'),
                ],
              ),
            ]),
          ],
        ),
        const SizedBox(height: 8),
        Text(_log, style: theme.text(color: theme.colors.textSoft)),
      ],
    );
  }
}

/// A demo-page card: a `<kakao-card>` with the example's title in its header.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: KakaoCard(
        header: Text(title, style: theme.step(theme.tokens.textXl)),
        children: [child],
      ),
    );
  }
}

/// A heading above examples that are cards themselves (they stay bare, as on
/// the card's demo page).
class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
      child: Text(text, style: theme.step(theme.tokens.textXl)),
    );
  }
}

class _CardExamples extends StatefulWidget {
  const _CardExamples();

  @override
  State<_CardExamples> createState() => _CardExamplesState();
}

class _CardExamplesState extends State<_CardExamples> {
  bool _details = false;

  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    final soft = theme.text(color: theme.colors.textSoft, height: 1.5);
    final title = theme.step(theme.tokens.textXl);
    Widget gap() => const SizedBox(height: 16);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KakaoCard(
          header: Text('Upgrade to Pro', style: title),
          footer: [
            KakaoButton(label: 'Upgrade', onPressed: () {}),
            KakaoButton(label: 'Later', variant: KakaoButtonVariant.ghost, onPressed: () {}),
          ],
          children: [
            Text('Unlimited projects and priority support. The main button gives the card its glow.', style: soft),
          ],
        ),
        gap(),
        KakaoCard(
          header: Text('Delete project', style: title),
          footer: [
            KakaoButton(label: 'Delete', variant: KakaoButtonVariant.danger, onPressed: () {}),
            KakaoButton(label: 'Cancel', variant: KakaoButtonVariant.ghost, onPressed: () {}),
          ],
          children: [Text('A danger button glows in the danger colour.', style: soft)],
        ),
        gap(),
        KakaoCard(
          header: Text('No glow', style: title),
          footer: [KakaoButton(label: 'Dismiss', variant: KakaoButtonVariant.ghost, onPressed: () {})],
          children: [Text('A ghost button has no colour of its own, so the card stays quiet.', style: soft)],
        ),
        gap(),
        KakaoCard(
          header: Text('Height changes', style: title),
          footer: [
            KakaoButton(
              label: _details ? 'Fewer details' : 'More details',
              variant: KakaoButtonVariant.secondary,
              onPressed: () => setState(() => _details = !_details),
            ),
          ],
          children: [
            Text('When content comes or goes, the card glides to its new height.', style: soft),
            if (_details)
              Text(
                'This paragraph is new. The card took 280 ms on the resize curve to make room for it, '
                'instead of jumping.',
                style: soft,
              ),
          ],
        ),
        gap(),
      ],
    );
  }
}

class _DialogExamples extends StatefulWidget {
  const _DialogExamples();

  @override
  State<_DialogExamples> createState() => _DialogExamplesState();
}

class _DialogExamplesState extends State<_DialogExamples> {
  String _last = 'none yet';

  Future<void> _show(Future<String?> dialog) async {
    final r = await dialog;
    if (mounted) setState(() => _last = r ?? 'dismissed');
  }

  Widget _close(String label, String value, {KakaoButtonVariant variant = KakaoButtonVariant.primary}) => Builder(
    builder: (c) => KakaoButton(label: label, variant: variant, onPressed: () => Navigator.pop(c, value)),
  );

  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    final soft = theme.text(color: theme.colors.textSoft, height: 1.5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            KakaoButton(
              label: 'Delete account',
              variant: KakaoButtonVariant.danger,
              onPressed: () => _show(
                showKakaoDialog<String>(
                  context,
                  header: const Text('Delete account?'),
                  footer: [
                    _close('Keep it', 'cancel', variant: KakaoButtonVariant.secondary),
                    _close('Delete', 'delete', variant: KakaoButtonVariant.danger),
                  ],
                  children: [Text('Your watch history and profiles will be gone.', style: soft)],
                ),
              ),
            ),
            KakaoButton(
              label: 'Buttons left',
              variant: KakaoButtonVariant.secondary,
              onPressed: () => _show(
                showKakaoDialog<String>(
                  context,
                  header: const Text('Rename file'),
                  buttonPosition: KakaoDialogButtonPosition.left,
                  footer: [
                    _close('Rename', 'rename'),
                    _close('Cancel', 'cancel', variant: KakaoButtonVariant.ghost),
                  ],
                  children: [Text('On the left, the main button comes first and takes the corner.', style: soft)],
                ),
              ),
            ),
            KakaoButton(
              label: 'Full width',
              variant: KakaoButtonVariant.secondary,
              onPressed: () => _show(
                showKakaoDialog<String>(
                  context,
                  header: const Text('Allow notifications?'),
                  fullWidth: true,
                  size: KakaoDialogSize.sm,
                  footer: [
                    _close('Not now', 'no', variant: KakaoButtonVariant.secondary),
                    _close('Allow', 'yes'),
                  ],
                  children: [Text('The buttons share the width; both corners hold one.', style: soft)],
                ),
              ),
            ),
            KakaoButton(
              label: 'No dismiss',
              variant: KakaoButtonVariant.secondary,
              onPressed: () => _show(
                showKakaoDialog<String>(
                  context,
                  header: const Text('Terms updated'),
                  dismissible: false,
                  footer: [_close('Accept', 'accepted')],
                  children: [Text('A tap outside or Escape does nothing here: only the button ends it.', style: soft)],
                ),
              ),
            ),
            KakaoButton(
              label: 'Long text',
              variant: KakaoButtonVariant.secondary,
              onPressed: () => _show(
                showKakaoDialog<String>(
                  context,
                  header: const Text('Release notes'),
                  footer: [_close('Close', 'close', variant: KakaoButtonVariant.secondary)],
                  children: [
                    for (var i = 1; i <= 12; i++)
                      Text('Paragraph $i. Only the body scrolls; the title and the buttons stay put.', style: soft),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text('Last result: $_last', style: theme.text(color: theme.colors.muted, tabular: true)),
      ],
    );
  }
}

class _ProgressExamples extends StatefulWidget {
  const _ProgressExamples();

  @override
  State<_ProgressExamples> createState() => _ProgressExamplesState();
}

class _ProgressExamplesState extends State<_ProgressExamples> {
  double _step = 1;

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 20);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KakaoProgress(value: _step, max: 4, label: 'Step ${_step.round()} of 4', showValue: true),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            KakaoButton(
              icon: const Icon(Icons.remove),
              semanticLabel: 'Back a step',
              size: KakaoButtonSize.sm,
              variant: KakaoButtonVariant.secondary,
              onPressed: _step > 0 ? () => setState(() => _step--) : null,
            ),
            KakaoButton(
              icon: const Icon(Icons.add),
              semanticLabel: 'Next step',
              size: KakaoButtonSize.sm,
              variant: KakaoButtonVariant.secondary,
              onPressed: _step < 4 ? () => setState(() => _step++) : null,
            ),
            KakaoButton(
              label: 'Fill',
              size: KakaoButtonSize.sm,
              variant: KakaoButtonVariant.secondary,
              onPressed: () => setState(() => _step = 4),
            ),
            KakaoButton(
              label: 'Reset',
              size: KakaoButtonSize.sm,
              variant: KakaoButtonVariant.ghost,
              onPressed: () => setState(() => _step = 0),
            ),
          ],
        ),
        gap,
        const KakaoProgress(value: 0.62, segments: 1, label: 'Storage', showValue: true, valueText: '62 of 100 GB'),
        gap,
        const KakaoProgress(value: 3, max: 8, segments: 8, label: 'Uploading 3 of 8', size: KakaoProgressSize.sm),
        gap,
        const KakaoProgress(value: 0.75, label: 'Backup', tone: KakaoProgressTone.success, size: KakaoProgressSize.lg),
        gap,
        const KakaoProgress(value: 0.5, label: 'Disk almost full', tone: KakaoProgressTone.warning),
        gap,
        const KakaoProgress(value: 0.25, label: 'Sync failed', tone: KakaoProgressTone.danger),
        gap,
        const KakaoProgress(label: 'Loading'),
      ],
    );
  }
}

/// popover/demo.html: click with a header and slotted content, hover on top,
/// list-data on the right, disabled, and a manual one driven by buttons.
class _PopoverExamples extends StatefulWidget {
  const _PopoverExamples();

  @override
  State<_PopoverExamples> createState() => _PopoverExamplesState();
}

class _PopoverExamplesState extends State<_PopoverExamples> {
  final _manual = KakaoPopoverController();
  String _log = 'no events yet';

  static const _rows = [
    KakaoPopoverRow('Region', 'us-east-1'),
    KakaoPopoverRow('Status', 'Operational'),
    KakaoPopoverRow('Latency', '42ms'),
    KakaoPopoverRow('Uptime', '99.98%'),
  ];

  @override
  void dispose() {
    _manual.dispose();
    super.dispose();
  }

  void _note(String e) => setState(() => _log = e);

  Widget _anchor(String label, KakaoPopoverController p) =>
      KakaoButton(label: label, variant: KakaoButtonVariant.secondary, size: KakaoButtonSize.sm, onPressed: p.toggle);

  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            KakaoPopover(
              header: const Text('Account'),
              content: const AccountDetails(),
              onOpen: () => _note('open · Account info'),
              onClose: () => _note('close · Account info'),
              anchorBuilder: (context, p) => _anchor('Account info', p),
            ),
            KakaoPopover(
              trigger: KakaoPopoverTrigger.hover,
              placement: KakaoPopoverPlacement.top,
              content: const Text('This action can\u2019t be undone once confirmed.'),
              anchorBuilder: (context, p) => _anchor('Hover for a tip', p),
            ),
            KakaoPopover(
              header: const Text('Server status'),
              placement: KakaoPopoverPlacement.right,
              rows: _rows,
              onSelect: (i, r) => _note('item-select · ${r.label}: ${r.value}'),
              anchorBuilder: (context, p) => _anchor('Server status', p),
            ),
            KakaoPopover(
              disabled: true,
              content: const Text('You should never see this - the popover is disabled.'),
              anchorBuilder: (context, p) => _anchor('Does nothing', p),
            ),
            KakaoPopover(
              controller: _manual,
              trigger: KakaoPopoverTrigger.manual,
              header: const Text('Manual'),
              content: const Text('Opened only via the controller.'),
              anchorBuilder: (context, p) => KakaoButton(
                label: 'Anchor (no auto trigger)',
                variant: KakaoButtonVariant.secondary,
                size: KakaoButtonSize.sm,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (label, action) in [
              ('open()', _manual.open),
              ('close()', _manual.close),
              ('toggle()', _manual.toggle),
            ])
              KakaoButton(label: label, variant: KakaoButtonVariant.ghost, size: KakaoButtonSize.sm, onPressed: action),
          ],
        ),
        const SizedBox(height: 8),
        Text(_log, style: theme.text(color: theme.colors.textSoft)),
      ],
    );
  }
}

/// menu/demo.html: icons and shortcuts, placements, groups, check and radio
/// items, submenus, a context menu, opened by script, and inline.
class _MenuExamples extends StatefulWidget {
  const _MenuExamples();

  @override
  State<_MenuExamples> createState() => _MenuExamplesState();
}

class _MenuExamplesState extends State<_MenuExamples> {
  final _api = KakaoMenuController();
  String _log = 'no events yet';

  static const _profile = [KakaoMenuItem('Profile'), KakaoMenuItem('Settings'), KakaoMenuItem('Sign out')];

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  void _note(String e) => setState(() => _log = e);

  void _select(KakaoMenuSelectEvent e) {
    if (e.value == 'stay') e.preventDefault(); // the menu stays open
    _note('menu-select · ${e.value}${e.checked == null ? '' : ' · checked ${e.checked}'}');
  }

  Widget _trigger(String label, KakaoMenuController m) =>
      KakaoButton(label: label, variant: KakaoButtonVariant.secondary, onPressed: m.toggle);

  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    final c = theme.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            KakaoMenu(
              items: fileMenuItems(),
              onSelect: _select,
              onOpen: () => _note('menu-open'),
              onClose: () => _note('menu-close'),
              anchorBuilder: (context, m) => _trigger('Actions', m),
            ),
            KakaoMenu(
              items: accountMenuItems(),
              onSelect: _select,
              anchorBuilder: (context, m) => _trigger('Account', m),
            ),
            KakaoMenu(
              items: viewMenuItems,
              keepOpen: true,
              onSelect: _select,
              anchorBuilder: (context, m) => _trigger('View', m),
            ),
            KakaoMenu(items: docMenuItems, onSelect: _select, anchorBuilder: (context, m) => _trigger('Document', m)),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (label, p) in [
              ('Bottom start', KakaoMenuPlacement.bottomStart),
              ('Top start', KakaoMenuPlacement.topStart),
              ('Bottom end', KakaoMenuPlacement.bottomEnd),
            ])
              KakaoMenu(
                items: _profile,
                placement: p,
                onSelect: _select,
                anchorBuilder: (context, m) => _trigger(label, m),
              ),
            KakaoMenu(
              items: const [KakaoMenuItem('Never shown')],
              disabled: true,
              anchorBuilder: (context, m) => _trigger('Disabled', m),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // menu/demo.html `.target`: dashed border, muted text, centred.
        KakaoMenu.context(
          items: canvasMenuItems,
          label: 'Canvas',
          onSelect: _select,
          child: Focus(
            child: Container(
              height: 128,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: c.border),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Right-click, long-press, or focus and press Shift+F10',
                textAlign: TextAlign.center,
                style: theme.text(color: c.muted),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            KakaoMenu(
              controller: _api,
              label: 'Insert',
              items: const [
                KakaoMenuItem('Table', value: 'table'),
                KakaoMenuItem('Image', value: 'image'),
                KakaoMenuItem('Keep open', value: 'stay'),
              ],
              onSelect: _select,
              anchorBuilder: (context, m) =>
                  KakaoButton(label: 'open()', variant: KakaoButtonVariant.secondary, onPressed: m.open),
            ),
            KakaoButton(
              label: 'openAt(120, 40)',
              variant: KakaoButtonVariant.secondary,
              onPressed: () => _api.openAt(const Offset(120, 40)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        KakaoMenu.inline(items: messageMenuItems, label: 'Message', onSelect: _select),
        const SizedBox(height: 8),
        Text(_log, style: theme.text(color: c.textSoft)),
      ],
    );
  }
}
