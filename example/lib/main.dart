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
            _Section(title: 'Code input', child: const _CodeInputExamples()),
            _Section(title: 'Combobox', child: const _ComboboxExamples()),
            _Section(title: 'Command palette', child: const _CommandPaletteExamples()),
            _Section(title: 'Date input', child: const _DateInputExamples()),
            _Section(title: 'Dialog', child: const _DialogExamples()),
            _Section(title: 'Menu', child: const _MenuExamples()),
            _Section(title: 'Multi dropdown', child: const _MultiDropdownExamples()),
            _Section(title: 'Number input', child: const _NumberInputExamples()),
            _Section(title: 'Password input', child: const _PasswordInputExamples()),
            _Section(title: 'Popover', child: const _PopoverExamples()),
            _Section(title: 'Progress', child: const _ProgressExamples()),
            _Section(title: 'Select', child: const _SelectExamples()),
            _Section(title: 'Tag input', child: const _TagInputExamples()),
            _Section(title: 'Text input', child: const _TextInputExamples()),
            _Section(title: 'Textarea', child: const _TextareaExamples()),
            _Section(title: 'Time input', child: const _TimeInputExamples()),
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

/// multi-dropdown/demo.html: dates (unknown parts, every part unknown, a
/// year range, disabled), custom segments (variant, time) and the playground.
class _MultiDropdownExamples extends StatefulWidget {
  const _MultiDropdownExamples();

  @override
  State<_MultiDropdownExamples> createState() => _MultiDropdownExamplesState();
}

class _MultiDropdownExamplesState extends State<_MultiDropdownExamples> {
  final _dob = KakaoMultiDropdownController();
  String _log = 'Pick a part';

  void _change(KakaoMultiDropdownChange e) => setState(
    () => _log =
        'dropdown-change · ${e.complete ? e.value : '(incomplete)'}'
        '${e.unknown.isEmpty ? '' : ' · unknown: ${e.unknown.join(', ')}'}',
  );

  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 32,
          runSpacing: 24,
          children: [
            KakaoMultiDropdown.date(
              label: 'Date of birth',
              allowUnknown: const {'day', 'month'},
              value: '00.00.1990',
              controller: _dob,
              onChanged: _change,
            ),
            KakaoMultiDropdown.date(label: 'First visit', allowUnknown: const {}, onChanged: _change),
            KakaoMultiDropdown.date(
              label: 'Appointment',
              minYear: 2026,
              maxYear: 2030,
              value: '30.10.2026',
              onChanged: _change,
            ),
            const KakaoMultiDropdown.date(label: 'Locked', value: '01.01.2000', disabled: true),
            KakaoMultiDropdown(
              label: 'Variant',
              separator: ' / ',
              allowUnknown: const {'color'},
              segments: variantSegments,
              onChanged: _change,
            ),
            KakaoMultiDropdown(
              label: 'Reminder',
              separator: ':',
              segments: timeSegments,
              value: '09:30',
              onChanged: _change,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            KakaoButton(
              label: 'value = "29.02.2024"',
              variant: KakaoButtonVariant.secondary,
              size: KakaoButtonSize.sm,
              onPressed: () => setState(() => _dob.value = '29.02.2024'),
            ),
            KakaoButton(
              label: 'setPart("month", "04")',
              variant: KakaoButtonVariant.secondary,
              size: KakaoButtonSize.sm,
              onPressed: () => _dob.setPart('month', '04'),
            ),
            KakaoButton(
              label: 'setPart("day", "00")',
              variant: KakaoButtonVariant.secondary,
              size: KakaoButtonSize.sm,
              onPressed: () => _dob.setPart('day', '00'),
            ),
            KakaoButton(
              label: 'clear()',
              variant: KakaoButtonVariant.secondary,
              size: KakaoButtonSize.sm,
              onPressed: _dob.clear,
            ),
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
class _CommandPaletteExamples extends StatefulWidget {
  const _CommandPaletteExamples();

  @override
  State<_CommandPaletteExamples> createState() => _CommandPaletteExamplesState();
}

class _CommandPaletteExamplesState extends State<_CommandPaletteExamples> {
  final _main = KakaoCommandPaletteController();
  final _admin = KakaoCommandPaletteController();
  String _log = 'Press Ctrl+K (Command+K on a Mac) anywhere, or a button';

  void _say(String text) => setState(() => _log = text);

  void _select(KakaoCommandSelect e) => _say('command-select · ${e.id} (value ${e.value})');

  @override
  void dispose() {
    _main.dispose();
    _admin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    final soft = theme.text(color: theme.colors.textSoft, height: 1.5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Groups, keywords, shortcuts and recent commands. Try “nwf” (letters in order), '
          '“logout” (a keyword) or “théme” (accents are ignored).',
          style: soft,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // The hotkey palette: Mod+K, remembers the last five commands.
            KakaoCommandPalette(
              commands: paletteCommands,
              controller: _main,
              recent: 5,
              onSelect: _select,
              onOpen: () => _say('command-palette-open'),
              child: KakaoButton(label: 'Open palette', variant: KakaoButtonVariant.secondary, onPressed: _main.open),
            ),
            // Another key: Mod+Shift+P, its own label and placeholder.
            KakaoCommandPalette(
              commands: paletteEditorCommands,
              hotkey: 'Mod+Shift+P',
              label: 'Editor commands',
              placeholder: 'Run an editor command…',
              onSelect: _select,
              child: Text('Ctrl+Shift+P: editor commands', style: soft),
            ),
            // From script: icons, open(query), no hotkey.
            KakaoCommandPalette(
              commands: paletteAdminCommands,
              controller: _admin,
              hotkey: null,
              label: 'Admin',
              onSelect: _select,
              child: Wrap(
                spacing: 8,
                children: [
                  KakaoButton(label: 'open()', variant: KakaoButtonVariant.secondary, onPressed: _admin.open),
                  KakaoButton(
                    label: "open('user')",
                    variant: KakaoButtonVariant.secondary,
                    onPressed: () => _admin.open('user'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Inline: always open, no scrim and no hotkey; Esc clears the field.', style: soft),
        const SizedBox(height: 8),
        SizedBox(
          width: 480,
          child: KakaoCommandPalette(
            inline: true,
            commands: paletteInlineCommands,
            emptyText: 'Nothing found, try “copy”',
            onSelect: _select,
          ),
        ),
        const SizedBox(height: 12),
        Text(_log, style: theme.text(size: 14, color: theme.colors.muted)),
      ],
    );
  }
}

/// text-input/demo.html: label and hint, search with icon and clear button,
/// icons, error, sizes, disabled and read only, a password, and the
/// playground's script calls with the event log.
class _TextInputExamples extends StatefulWidget {
  const _TextInputExamples();

  @override
  State<_TextInputExamples> createState() => _TextInputExamplesState();
}

class _TextInputExamplesState extends State<_TextInputExamples> {
  final _t1 = TextEditingController();
  final _t1Focus = FocusNode();
  String? _t1Error;
  final _log = <String>[];

  void _event(String e) => setState(() {
    _log.insert(0, e);
    if (_log.length > 6) _log.removeLast();
  });

  @override
  void dispose() {
    _t1.dispose();
    _t1Focus.dispose();
    super.dispose();
  }

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
              KakaoTextInput(
                controller: _t1,
                focusNode: _t1Focus,
                label: 'Email',
                type: KakaoTextInputType.email,
                placeholder: 'you@example.com',
                hint: 'We only use it for receipts.',
                error: _t1Error,
                autofillHints: const [AutofillHints.email],
                onChanged: (v) => _event('input · $v'),
                onCommitted: (v) => _event('change · $v'),
              ),
              KakaoTextInput(
                type: KakaoTextInputType.search,
                label: 'Search',
                clearable: true,
                value: 'kakao',
                placeholder: 'Search components',
                icon: const SearchGlyph(),
                onCleared: (e) => _event('text-input-clear · was ${e.previous}'),
              ),
              // fas fa-at / fa-globe on the web; the showcase has no Font Awesome.
              const KakaoTextInput(
                type: KakaoTextInputType.email,
                label: 'Email · icon',
                placeholder: 'you@example.com',
                icon: Icon(Icons.alternate_email),
              ),
              const KakaoTextInput(
                type: KakaoTextInputType.url,
                label: 'Website · icon',
                placeholder: 'example.com',
                icon: Icon(Icons.language),
              ),
              const KakaoTextInput(label: 'Workspace', value: 'acme', error: 'That name is already taken.'),
            ]),
            column(const [
              KakaoTextInput(size: KakaoTextInputSize.sm, label: 'Small', value: '36px'),
              KakaoTextInput(label: 'Medium', value: '44px'),
              KakaoTextInput(size: KakaoTextInputSize.lg, label: 'Large', value: '52px'),
              KakaoTextInput(disabled: true, label: 'Disabled', value: 'Not now'),
              KakaoTextInput(readOnly: true, label: 'Read only', value: 'Copied elsewhere'),
              KakaoTextInput(type: KakaoTextInputType.password, label: 'Password', maxLength: 64),
            ]),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            KakaoButton(
              label: 'focus()',
              variant: KakaoButtonVariant.secondary,
              size: KakaoButtonSize.sm,
              onPressed: _t1Focus.requestFocus,
            ),
            KakaoButton(
              label: 'value = "hello"',
              variant: KakaoButtonVariant.secondary,
              size: KakaoButtonSize.sm,
              onPressed: () => _t1.text = 'hello',
            ),
            KakaoButton(
              label: 'value = ""',
              variant: KakaoButtonVariant.secondary,
              size: KakaoButtonSize.sm,
              onPressed: () => _t1.text = '',
            ),
            KakaoButton(
              label: 'toggle error',
              variant: KakaoButtonVariant.secondary,
              size: KakaoButtonSize.sm,
              onPressed: () => setState(() => _t1Error = _t1Error == null ? 'Something is wrong.' : null),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _log.isEmpty ? 'Type in the email field to see its events.' : _log.join('\n'),
          style: theme.text(size: 14, color: theme.colors.muted),
        ),
      ],
    );
  }
}

/// number-input/demo.html: the variants (default, small with step 0.5, the
/// touch layout and its options, disabled) and the playground (size,
/// disabled, the change log).
class _NumberInputExamples extends StatefulWidget {
  const _NumberInputExamples();

  @override
  State<_NumberInputExamples> createState() => _NumberInputExamplesState();
}

class _NumberInputExamplesState extends State<_NumberInputExamples> {
  bool _small = false;
  bool _disabled = false;
  final _log = <String>[];

  void _event(String e) => setState(() {
    _log.insert(0, e);
    if (_log.length > 6) _log.removeLast();
  });

  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    Widget example(String caption, Widget child) => SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(caption, style: theme.text(size: 14, weight: 600)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 24,
          runSpacing: 20,
          children: [
            example('Default', const KakaoNumberInput(value: 10, min: 0, max: 100, semanticLabel: 'Quantity')),
            example(
              'Small · step 0.5',
              const KakaoNumberInput(
                size: KakaoNumberInputSize.sm,
                value: 2.5,
                min: 0,
                max: 10,
                step: .5,
                semanticLabel: 'Hours',
              ),
            ),
            example(
              'Touch layout · touchSteppers',
              const KakaoNumberInput(
                value: 10,
                min: 0,
                max: 100,
                touchSteppers: true,
                semanticLabel: 'Quantity (touch)',
              ),
            ),
            example(
              'Pair on the left · groupPosition: left',
              const KakaoNumberInput(
                value: 10,
                min: 0,
                max: 100,
                touchSteppers: true,
                groupPosition: KakaoStepperSide.left,
                semanticLabel: 'Quantity, buttons on the left',
              ),
            ),
            example(
              'Split · grouped: false, plus: left',
              const KakaoNumberInput(
                value: 10,
                min: 0,
                max: 100,
                touchSteppers: true,
                grouped: false,
                plus: KakaoStepperSide.left,
                semanticLabel: 'Quantity, split buttons',
              ),
            ),
            example(
              'One button · minus: none',
              const KakaoNumberInput(
                value: 10,
                min: 0,
                max: 100,
                touchSteppers: true,
                minus: KakaoStepperSide.none,
                semanticLabel: 'Quantity, plus only',
              ),
            ),
            example('Disabled', const KakaoNumberInput(value: 42, disabled: true, semanticLabel: 'Locked')),
          ],
        ),
        const SizedBox(height: 20),
        Text('Playground', style: theme.text(size: 14, weight: 600)),
        const SizedBox(height: 8),
        SizedBox(
          width: 220,
          child: KakaoNumberInput(
            value: 10,
            min: 0,
            max: 100,
            size: _small ? KakaoNumberInputSize.sm : KakaoNumberInputSize.md,
            disabled: _disabled,
            semanticLabel: 'Quantity',
            onCommitted: (v) => _event('change · ${v == null ? '""' : KakaoNumberInput.format(v)}'),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            KakaoButton(
              label: 'size sm',
              variant: KakaoButtonVariant.secondary,
              size: KakaoButtonSize.sm,
              toggle: true,
              pressed: _small,
              onPressed: () => setState(() => _small = !_small),
            ),
            KakaoButton(
              label: 'disabled',
              variant: KakaoButtonVariant.secondary,
              size: KakaoButtonSize.sm,
              toggle: true,
              pressed: _disabled,
              onPressed: () => setState(() => _disabled = !_disabled),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _log.isEmpty ? 'Step or type in the field to see its change events.' : _log.join('\n'),
          style: theme.text(size: 14, color: theme.colors.muted),
        ),
      ],
    );
  }
}

/// textarea/demo.html: label, counter, auto-growing, error, sizes and
/// resize, required in a form (the owner sets the error), and the
/// playground's script calls with the event log.
/// date-input/demo.html: the types, min / max, the today tag (with an out
/// of range tag, a locale and an own label), beside the select and
/// combobox, sizes, states, and the playground (next type, showPicker,
/// value, disabled, today; the event log).
class _DateInputExamples extends StatefulWidget {
  const _DateInputExamples();

  @override
  State<_DateInputExamples> createState() => _DateInputExamplesState();
}

class _DateInputExamplesState extends State<_DateInputExamples> {
  final _picker = KakaoDateInputController();
  var _type = KakaoDateInputType.date;
  var _value = '2026-03-04';
  bool _disabled = false;
  bool _today = false;
  final _log = <String>[];

  /// A week from today: the out-of-range field's min.
  final _nextWeek = () {
    final d = DateTime.now().add(const Duration(days: 7));
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }();

  @override
  void dispose() {
    _picker.dispose();
    super.dispose();
  }

  void _event(String e) => setState(() {
    _log.insert(0, e);
    if (_log.length > 6) _log.removeLast();
  });

  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    Widget example(String caption, Widget child) => SizedBox(
      width: 280,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(caption, style: theme.text(size: 14, weight: 600)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
    Widget stack(List<Widget> children) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 10), children[i]],
      ],
    );
    Widget button(String label, VoidCallback onPressed, {bool? pressed}) => KakaoButton(
      label: label,
      variant: KakaoButtonVariant.secondary,
      size: KakaoButtonSize.sm,
      toggle: pressed != null,
      pressed: pressed ?? false,
      onPressed: onPressed,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 24,
          runSpacing: 20,
          children: [
            example(
              'Date (default)',
              const KakaoDateInput(label: 'Start date', value: '2026-03-04', hint: 'Value 2026-03-04'),
            ),
            example(
              'Time · step 900',
              const KakaoDateInput(
                type: KakaoDateInputType.time,
                label: 'Start time',
                value: '09:30',
                step: 900,
                hint: 'Picker in 15-minute steps',
              ),
            ),
            example(
              'Date and time',
              const KakaoDateInput(type: KakaoDateInputType.dateTimeLocal, label: 'Meeting', value: '2026-03-04T14:30'),
            ),
            example(
              'Month',
              const KakaoDateInput(type: KakaoDateInputType.month, label: 'Billing month', value: '2026-03'),
            ),
            example(
              'Week',
              const KakaoDateInput(type: KakaoDateInputType.week, label: 'Sprint week', value: '2026-W10'),
            ),
            example(
              'Min · max',
              const KakaoDateInput(
                label: 'Delivery',
                min: '2026-11-16',
                max: '2026-11-27',
                value: '2026-11-30',
                hint: 'Weekdays from 16 to 27 November',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Today shortcut · today', style: theme.text(size: 14, weight: 600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 24,
          runSpacing: 20,
          children: [
            example('Date', const KakaoDateInput(today: true, label: 'Entry date', hint: 'Today in one click')),
            example(
              'Time · step 900',
              const KakaoDateInput(
                today: true,
                type: KakaoDateInputType.time,
                step: 900,
                label: 'Started at',
                hint: 'Now, to the nearest quarter hour',
              ),
            ),
            example(
              'Month · week',
              stack(const [
                KakaoDateInput(today: true, type: KakaoDateInputType.month, label: 'Billing month'),
                KakaoDateInput(today: true, type: KakaoDateInputType.week, label: 'Sprint week'),
              ]),
            ),
            example(
              'Out of range · disabled tag',
              KakaoDateInput(today: true, min: _nextWeek, label: 'Delivery', hint: 'Earliest date is next week'),
            ),
            example(
              'Locale · today-label',
              stack(const [
                KakaoDateInput(today: true, locale: Locale('de', 'AT'), label: 'Datum'),
                KakaoDateInput(today: true, todayLabel: 'Use today', label: 'Custom label'),
              ]),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 24,
          runSpacing: 20,
          children: [
            example(
              'Beside the other fields',
              stack(const [
                KakaoSelect(
                  label: 'Room',
                  values: ['b'],
                  options: [
                    KakaoSelectOption('a', label: 'Room A'),
                    KakaoSelectOption('b', label: 'Room B'),
                  ],
                ),
                KakaoCombobox(
                  label: 'Host',
                  value: 'Ana',
                  options: [KakaoComboboxOption('Ana'), KakaoComboboxOption('Ben'), KakaoComboboxOption('Chiara')],
                ),
                KakaoDateInput(label: 'Day', value: '2026-03-04'),
                KakaoDateInput(type: KakaoDateInputType.time, label: 'Time', value: '14:30'),
              ]),
            ),
            example(
              'Sizes',
              stack(const [
                KakaoDateInput(size: KakaoDateInputSize.sm, label: 'Small', value: '2026-03-04'),
                KakaoDateInput(label: 'Medium', value: '2026-03-04'),
                KakaoDateInput(size: KakaoDateInputSize.lg, label: 'Large', value: '2026-03-04'),
              ]),
            ),
            example(
              'Disabled · read only · error',
              stack(const [
                KakaoDateInput(disabled: true, label: 'Disabled', value: '2026-03-04'),
                KakaoDateInput(readOnly: true, label: 'Read only', value: '2026-03-04'),
                KakaoDateInput(
                  type: KakaoDateInputType.time,
                  label: 'Check-in',
                  error: 'Check-in starts at 15:00.',
                  value: '11:00',
                ),
              ]),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Playground', style: theme.text(size: 14, weight: 600)),
        const SizedBox(height: 8),
        SizedBox(
          width: 320,
          child: KakaoDateInput(
            label: 'Playground · ${_type.name}',
            type: _type,
            value: _value,
            disabled: _disabled,
            today: _today,
            controller: _picker,
            onChanged: (v) => _event('input · ${v.isEmpty ? '""' : v}'),
            onCommitted: (v) => _event('change · ${v.isEmpty ? '""' : v}'),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            button('value = "2026-12-24"', () {
              setState(() {
                _type = KakaoDateInputType.date;
                _value = '2026-12-24';
              });
            }),
            button('showPicker()', _picker.open),
            button('next type', () {
              setState(() {
                _type = KakaoDateInputType.values[(_type.index + 1) % KakaoDateInputType.values.length];
                _value = '';
              });
            }),
            button('disabled', () => setState(() => _disabled = !_disabled), pressed: _disabled),
            button('today', () => setState(() => _today = !_today), pressed: _today),
          ],
        ),
        const SizedBox(height: 8),
        for (final e in _log) Text(e, style: theme.text(size: 13, color: theme.colors.muted, tabular: true)),
      ],
    );
  }
}

class _TimeInputExamples extends StatefulWidget {
  const _TimeInputExamples();

  @override
  State<_TimeInputExamples> createState() => _TimeInputExamplesState();
}

class _TimeInputExamplesState extends State<_TimeInputExamples> {
  final _picker = KakaoTimeInputController();
  var _value = '14:30';
  bool _seconds = false;
  bool _disabled = false;
  bool _now = false;
  final _log = <String>[];

  /// A one-hour window starting two hours from now, so the tag is always off
  /// (the demo's script).
  final _window = () {
    final h = (DateTime.now().hour + 2) % 24;
    String at(int x) => '${(x % 24).toString().padLeft(2, '0')}:00';
    return (min: at(h), max: at(h + 1));
  }();

  @override
  void dispose() {
    _picker.dispose();
    super.dispose();
  }

  void _event(String e) => setState(() {
    _log.insert(0, e);
    if (_log.length > 6) _log.removeLast();
  });

  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    Widget example(String caption, Widget child) => SizedBox(
      width: 280,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(caption, style: theme.text(size: 14, weight: 600)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
    Widget stack(List<Widget> children) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 10), children[i]],
      ],
    );
    Widget button(String label, VoidCallback onPressed, {bool? pressed}) => KakaoButton(
      label: label,
      variant: KakaoButtonVariant.secondary,
      size: KakaoButtonSize.sm,
      toggle: pressed != null,
      pressed: pressed ?? false,
      onPressed: onPressed,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 24,
          runSpacing: 20,
          children: [
            example(
              'Time',
              const KakaoTimeInput(label: 'Start time', value: '14:30', hint: 'Value 14:30, drawn as 2:30 PM or 14:30'),
            ),
            example(
              'Step · step 900',
              const KakaoTimeInput(
                label: 'Slot',
                value: '09:15',
                step: 900,
                hint: '15-minute steps: arrow keys and the picker',
              ),
            ),
            example(
              'Seconds · step 1',
              const KakaoTimeInput(
                label: 'Lap time',
                value: '00:01:30',
                step: 1,
                hint: 'A step under a minute adds the seconds segment',
              ),
            ),
            example(
              'Min · max',
              const KakaoTimeInput(
                label: 'Check-in',
                min: '15:00',
                max: '22:00',
                value: '11:00',
                hint: 'Between 15:00 and 22:00',
              ),
            ),
            example(
              'Over midnight · min after max',
              const KakaoTimeInput(
                label: 'Night shift starts',
                min: '22:00',
                max: '06:00',
                value: '23:30',
                hint: 'From 22:00 to 06:00',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Now shortcut · now', style: theme.text(size: 14, weight: 600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 24,
          runSpacing: 20,
          children: [
            example('To the minute', const KakaoTimeInput(now: true, label: 'Logged at', hint: 'Now in one click')),
            example(
              'Quarter hours · step 900',
              const KakaoTimeInput(now: true, step: 900, label: 'Started at', hint: 'Now, to the nearest quarter hour'),
            ),
            example('Seconds · step 1', const KakaoTimeInput(now: true, step: 1, label: 'Stamp')),
            example(
              'Out of range · disabled tag',
              KakaoTimeInput(
                now: true,
                min: _window.min,
                max: _window.max,
                label: 'Delivery window',
                hint: 'Always a window that excludes now',
              ),
            ),
            example(
              'Locale · now-label',
              stack(const [
                KakaoTimeInput(now: true, locale: Locale('de', 'AT'), label: 'Uhrzeit'),
                KakaoTimeInput(now: true, nowLabel: 'Use current time', label: 'Custom label'),
              ]),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 24,
          runSpacing: 20,
          children: [
            example(
              'Beside the other fields',
              stack(const [
                KakaoSelect(
                  label: 'Room',
                  values: ['b'],
                  options: [
                    KakaoSelectOption('a', label: 'Room A'),
                    KakaoSelectOption('b', label: 'Room B'),
                  ],
                ),
                KakaoDateInput(label: 'Day', value: '2026-03-04'),
                KakaoTimeInput(label: 'Time', value: '14:30'),
              ]),
            ),
            example(
              '12 or 24 hours',
              stack(const [
                KakaoTimeInput(locale: Locale('en', 'US'), label: 'en-US', value: '14:30'),
                KakaoTimeInput(locale: Locale('de', 'AT'), label: 'de-AT', value: '14:30'),
              ]),
            ),
            example(
              'Sizes',
              stack(const [
                KakaoTimeInput(size: KakaoTimeInputSize.sm, label: 'Small', value: '14:30'),
                KakaoTimeInput(label: 'Medium', value: '14:30'),
                KakaoTimeInput(size: KakaoTimeInputSize.lg, label: 'Large', value: '14:30'),
              ]),
            ),
            example(
              'Disabled · read only · error',
              stack(const [
                KakaoTimeInput(disabled: true, now: true, label: 'Disabled', value: '14:30'),
                KakaoTimeInput(readOnly: true, now: true, label: 'Read only', value: '14:30'),
                KakaoTimeInput(label: 'Check-in', error: 'Check-in starts at 15:00.', value: '11:00'),
              ]),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Playground', style: theme.text(size: 14, weight: 600)),
        const SizedBox(height: 8),
        SizedBox(
          width: 320,
          child: KakaoTimeInput(
            label: 'Playground',
            value: _value,
            step: _seconds ? 1 : null,
            disabled: _disabled,
            now: _now,
            controller: _picker,
            onChanged: (v) => _event('input · ${v.isEmpty ? '""' : v}'),
            onCommitted: (v) => _event('change · ${v.isEmpty ? '""' : v}'),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            button('value = "08:45"', () => setState(() => _value = '08:45')),
            button('showPicker()', _picker.open),
            button('step = 1', () => setState(() => _seconds = !_seconds), pressed: _seconds),
            button('disabled', () => setState(() => _disabled = !_disabled), pressed: _disabled),
            button('now', () => setState(() => _now = !_now), pressed: _now),
          ],
        ),
        const SizedBox(height: 8),
        for (final e in _log) Text(e, style: theme.text(size: 13, color: theme.colors.muted, tabular: true)),
      ],
    );
  }
}

/// code-input/demo.html: Basic, In a form (completing submits) and the
/// playground with its API buttons and event log.
class _CodeInputExamples extends StatefulWidget {
  const _CodeInputExamples();

  @override
  State<_CodeInputExamples> createState() => _CodeInputExamplesState();
}

class _CodeInputExamplesState extends State<_CodeInputExamples> {
  final _play = TextEditingController();
  final _playFocus = FocusNode();
  final _form = TextEditingController();
  int _length = 6;
  bool _error = false;
  String _formOut = 'Submit to see the entries. A half-filled code does not submit.';
  final _log = <String>[];

  @override
  void dispose() {
    _play.dispose();
    _playFocus.dispose();
    _form.dispose();
    super.dispose();
  }

  void _event(String e) => setState(() {
    _log.insert(0, e);
    if (_log.length > 6) _log.removeLast();
  });

  void _submit() => setState(() {
    final v = _form.text;
    _formOut = v.isEmpty
        ? 'Please fill in this field.'
        : v.length < 6
        ? 'Please enter all 6 digits.'
        : 'Submitted: otp=$v';
  });

  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    Widget example(String caption, Widget child) => SizedBox(
      width: 380,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(caption, style: theme.text(size: 14, weight: 600)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
    Widget stack(List<Widget> children) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 12), children[i]],
      ],
    );
    Widget button(String label, VoidCallback onPressed, {bool? pressed, bool secondary = true}) => KakaoButton(
      label: label,
      variant: secondary ? KakaoButtonVariant.secondary : KakaoButtonVariant.primary,
      size: KakaoButtonSize.sm,
      toggle: pressed != null,
      pressed: pressed ?? false,
      onPressed: onPressed,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 24,
          runSpacing: 20,
          children: [
            example(
              'Verification code',
              const KakaoCodeInput(label: 'Verification code', hint: 'We sent a 6-digit code to +43 660 ··· 12.'),
            ),
            example(
              'Grouped · separator "3"',
              const KakaoCodeInput(label: 'Sign-in code', separator: '3', value: '482'),
            ),
            example(
              'PIN · length 4, mask',
              const KakaoCodeInput(label: 'Card PIN', length: 4, mask: true, autofillHints: [], value: '12'),
            ),
            example(
              'Letters too · alphanumeric',
              const KakaoCodeInput(
                label: 'Backup code',
                type: KakaoCodeInputType.alphanumeric,
                length: 8,
                separator: '4',
                hint: 'Letters and digits, as printed on your backup sheet.',
              ),
            ),
            example(
              'Own character set · pattern',
              const KakaoCodeInput(
                label: 'Pairing code (hex)',
                type: KakaoCodeInputType.alphanumeric,
                pattern: '[0-9A-F]',
                length: 4,
                hint: '0–9 and A–F; letters are capitalised as you type.',
              ),
            ),
            example(
              'Error',
              const KakaoCodeInput(
                label: 'Verification code',
                value: '123456',
                error: 'That code has expired. We sent you a new one.',
              ),
            ),
            example(
              'Sizes',
              stack(const [
                KakaoCodeInput(size: KakaoCodeInputSize.sm, label: 'Small', length: 4, value: '36'),
                KakaoCodeInput(label: 'Medium', length: 4, value: '44'),
                KakaoCodeInput(size: KakaoCodeInputSize.lg, label: 'Large', length: 4, value: '52'),
              ]),
            ),
            example(
              'Disabled · read only',
              stack(const [
                KakaoCodeInput(disabled: true, label: 'Disabled', length: 4, value: '1234'),
                KakaoCodeInput(readOnly: true, label: 'Read only', length: 4, value: '5678'),
              ]),
            ),
            example(
              'In a form',
              stack([
                KakaoCodeInput(
                  label: 'Verification code',
                  hint: 'Completing the code submits the form.',
                  controller: _form,
                  onCompleted: (_) => _submit(),
                  onSubmitted: (_) => _submit(),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    button('Verify', _submit, secondary: false),
                    button(
                      'Reset',
                      () => setState(() {
                        _form.clear();
                        _formOut = 'Reset to the initial value.';
                      }),
                    ),
                  ],
                ),
                Text(_formOut, style: theme.text(size: 13, color: theme.colors.muted)),
              ]),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Playground', style: theme.text(size: 14, weight: 600)),
        const SizedBox(height: 8),
        SizedBox(
          width: 380,
          child: KakaoCodeInput(
            label: 'Playground',
            length: _length,
            error: _error ? 'That code is not right.' : null,
            controller: _play,
            focusNode: _playFocus,
            onChanged: (v) => _event('input · $v'),
            onCommitted: (v) => _event('change · $v'),
            onCompleted: (v) => _event('code-complete · $v'),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            button('value = "908172"', () => _play.text = '908172'),
            button('clear()', _play.clear),
            button('focus()', _playFocus.requestFocus),
            button('next length', () {
              setState(() => _length = _length >= 8 ? 4 : _length + 1);
              _event('length · $_length');
            }),
            button('error', () => setState(() => _error = !_error), pressed: _error),
          ],
        ),
        const SizedBox(height: 8),
        for (final e in _log) Text(e, style: theme.text(size: 13, color: theme.colors.muted)),
      ],
    );
  }
}

/// tag-input/demo.html: Basic, States, In a form (as a values readout) and
/// the playground with its API buttons and event log.
class _TagInputExamples extends StatefulWidget {
  const _TagInputExamples();

  @override
  State<_TagInputExamples> createState() => _TagInputExamplesState();
}

class _TagInputExamplesState extends State<_TagInputExamples> {
  final _play = KakaoTagInputController();
  bool _disabled = false;
  var _form = (tags: const ['news', 'berlin'], cc: const <String>[]);
  final _log = <String>[];

  void _event(String e) => setState(() {
    _log.insert(0, e);
    if (_log.length > 6) _log.removeLast();
  });

  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    Widget example(String caption, Widget child) => SizedBox(
      width: 320,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(caption, style: theme.text(size: 14, weight: 600)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
    Widget stack(List<Widget> children) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 10), children[i]],
      ],
    );
    Widget button(String label, VoidCallback onPressed, {bool? pressed}) => KakaoButton(
      label: label,
      variant: KakaoButtonVariant.secondary,
      size: KakaoButtonSize.sm,
      toggle: pressed != null,
      pressed: pressed ?? false,
      onPressed: onPressed,
    );
    String entries(String name, List<String> values) => values.map((v) => '$name=$v').join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 24,
          runSpacing: 20,
          children: [
            example(
              'Enter or comma',
              KakaoTagInput(
                label: 'Keywords',
                values: KakaoTagInput.parse('design, tokens, theming'),
                placeholder: 'Add a keyword',
                hint: 'Enter or a comma adds the text. Paste “a, b, c” to add three.',
              ),
            ),
            example(
              'Suggestions',
              const KakaoTagInput(
                label: 'Labels',
                placeholder: 'Type to see suggestions',
                hint: 'Matching labels open below the field; any other text works too.',
                suggestions: tagSuggestions,
              ),
            ),
            example(
              'Delimiters ",; "',
              const KakaoTagInput(
                label: 'Recipients',
                delimiters: ',; ',
                placeholder: 'name@example.com',
                hint: 'Comma, semicolon or space ends a tag.',
              ),
            ),
            example(
              'Limit · maxTags 3',
              const KakaoTagInput(
                label: 'Top three skills',
                maxTags: 3,
                values: ['CSS', 'JavaScript'],
                hint: 'Up to three. Adding “css” again flashes the existing tag.',
              ),
            ),
            example(
              'Duplicates allowed · tags with commas',
              KakaoTagInput(
                label: 'Authors',
                allowDuplicates: true,
                delimiters: ';',
                values: KakaoTagInput.parse('["Smith, J.", "Doe, A.", "Smith, J."]'),
                hint: 'Semicolon ends a tag, so names keep their comma.',
              ),
            ),
            example(
              'Many tags · wraps',
              KakaoTagInput(
                label: 'Ingredients',
                values: KakaoTagInput.parse(
                  'Flour, Sugar, Butter, Eggs, Milk, Vanilla extract, Baking powder, Salt, Lemon zest, Cinnamon',
                ),
              ),
            ),
            example(
              'Sizes',
              stack(const [
                KakaoTagInput(size: KakaoTagInputSize.sm, label: 'Small', values: ['36px', 'sm']),
                KakaoTagInput(label: 'Medium', values: ['44px', 'md']),
                KakaoTagInput(size: KakaoTagInputSize.lg, label: 'Large', values: ['52px', 'lg']),
              ]),
            ),
            example(
              'Disabled · read-only · error',
              stack(const [
                KakaoTagInput(disabled: true, label: 'Disabled', values: ['One', 'Two']),
                KakaoTagInput(readOnly: true, label: 'Read-only', values: ['Locked', 'Shown']),
                KakaoTagInput(label: 'Topics', error: 'Add at least one topic.', placeholder: 'Add a topic'),
              ]),
            ),
            example(
              'In a form',
              stack([
                KakaoTagInput(
                  label: 'Tags',
                  placeholder: 'Add a tag',
                  values: _form.tags,
                  onChanged: (v) => setState(() => _form = (tags: v, cc: _form.cc)),
                ),
                KakaoTagInput(
                  label: 'Cc',
                  delimiters: ',; ',
                  placeholder: 'name@example.com',
                  values: _form.cc,
                  onChanged: (v) => setState(() => _form = (tags: _form.tags, cc: v)),
                ),
                Text(
                  'Entries: ${[entries('tags', _form.tags), entries('cc', _form.cc)].where((e) => e.isNotEmpty).join(' · ')}',
                  style: theme.text(size: 13, color: theme.colors.muted),
                ),
              ]),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Playground', style: theme.text(size: 14, weight: 600)),
        const SizedBox(height: 8),
        SizedBox(
          width: 320,
          child: KakaoTagInput(
            label: 'Playground',
            values: const ['alpha', 'beta'],
            placeholder: 'Add a tag',
            hint: 'Tags starting with “x” are refused by an onTagAdd listener.',
            disabled: _disabled,
            controller: _play,
            onTagAdd: (v) {
              final ok = !v.toLowerCase().startsWith('x');
              _event('tag-add · $v${ok ? '' : ' (refused)'}');
              return ok;
            },
            onTagRemove: (v) {
              _event('tag-remove · $v');
              return true;
            },
            onChanged: (v) => _event('change · ${KakaoTagInput.join(v)}'),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            button('add("gamma")', () => setState(() => _play.add('gamma'))),
            button('values = ["one", "two"]', () => setState(() => _play.values = ['one', 'two'])),
            button('clear()', () => setState(_play.clear)),
            button('disabled', () => setState(() => _disabled = !_disabled), pressed: _disabled),
          ],
        ),
        const SizedBox(height: 8),
        for (final e in _log) Text(e, style: theme.text(size: 13, color: theme.colors.muted)),
      ],
    );
  }
}

class _TextareaExamples extends StatefulWidget {
  const _TextareaExamples();

  @override
  State<_TextareaExamples> createState() => _TextareaExamplesState();
}

class _TextareaExamplesState extends State<_TextareaExamples> {
  final _a1 = TextEditingController();
  final _a1Focus = FocusNode();
  final _feedback = TextEditingController();
  String? _feedbackError;
  String _submitted = 'Submit to see the submitted value.';
  final _log = <String>[];

  void _event(String e) => setState(() {
    _log.insert(0, e.replaceAll('\n', '⏎'));
    if (_log.length > 6) _log.removeLast();
  });

  @override
  void dispose() {
    _a1.dispose();
    _a1Focus.dispose();
    _feedback.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _feedback.text;
    setState(() {
      // required: the owner checks (no form participation).
      _feedbackError = v.trim().isEmpty ? 'Please fill out this field.' : null;
      if (_feedbackError == null) _submitted = 'Submitted: feedback="${v.length > 40 ? v.substring(0, 40) : v}"';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    Widget column(List<Widget> children) => SizedBox(
      width: 320,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 16), children[i]],
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
              KakaoTextarea(
                controller: _a1,
                focusNode: _a1Focus,
                label: 'Message',
                rows: 4,
                placeholder: 'Write a message…',
                onChanged: (v) => _event('input · $v'),
                onCommitted: (v) => _event('change · $v'),
              ),
              const KakaoTextarea(label: 'Bio', maxLength: 140, counter: true, value: 'Design systems, mostly.'),
              const KakaoTextarea(label: 'Notes', autosize: true, rows: 2, hint: 'Grows with what you type.'),
            ]),
            column([
              const KakaoTextarea(label: 'Reason', value: 'Too short', error: 'Please write at least 20 characters.'),
              const KakaoTextarea(
                size: KakaoTextareaSize.sm,
                rows: 2,
                value: 'Small',
                semanticLabel: 'Small text area',
              ),
              const KakaoTextarea(
                size: KakaoTextareaSize.lg,
                rows: 2,
                resize: KakaoTextareaResize.none,
                value: 'Large, no resize',
                semanticLabel: 'Large text area',
              ),
              const KakaoTextarea(label: 'Disabled', value: 'Not now', disabled: true),
              KakaoTextarea(
                controller: _feedback,
                label: 'Feedback',
                rows: 3,
                error: _feedbackError,
                onChanged: (_) {
                  if (_feedbackError != null) setState(() => _feedbackError = null);
                },
              ),
              Row(
                children: [KakaoButton(label: 'Submit', onPressed: _submit)],
              ),
              Text(_submitted, style: theme.text(size: 13.6, color: theme.colors.muted)),
            ]),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            KakaoButton(
              label: 'focus()',
              variant: KakaoButtonVariant.secondary,
              size: KakaoButtonSize.sm,
              onPressed: _a1Focus.requestFocus,
            ),
            KakaoButton(
              label: 'value = long text',
              variant: KakaoButtonVariant.secondary,
              size: KakaoButtonSize.sm,
              onPressed: () => _a1.text = 'A longer piece of text\nwith two lines.',
            ),
            KakaoButton(
              label: 'value = ""',
              variant: KakaoButtonVariant.secondary,
              size: KakaoButtonSize.sm,
              onPressed: () => _a1.text = '',
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _log.isEmpty ? 'Type in the message field to see its events.' : _log.join('\n'),
          style: theme.text(size: 14, color: theme.colors.muted),
        ),
      ],
    );
  }
}

/// password-input/demo.html: show / hide, hint and error, sizes, disabled,
/// read only and no toggle; the default requirements with the event log, own
/// requirements, the length from minLength, requirements set by script; a
/// sign-up form blocked by required strength (the owner sets the error); and
/// the playground's script calls.
class _PasswordInputExamples extends StatefulWidget {
  const _PasswordInputExamples();

  @override
  State<_PasswordInputExamples> createState() => _PasswordInputExamplesState();
}

class _PasswordInputExamplesState extends State<_PasswordInputExamples> {
  final _log = <String>[];
  final _password = TextEditingController();
  String? _passwordError;
  String _submitted = 'Submit to see the result.';
  String _play = '';
  bool? _playVisible;
  final _playLog = <String>[];

  void _event(List<String> log, String e) => setState(() {
    log.insert(0, e);
    if (log.length > 6) log.removeLast();
  });

  String _requirements(KakaoPasswordRequirements r) => 'password-input-requirements · ${r.met} of ${r.total}';

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _password.text;
    final check = KakaoPasswordInput.evaluate(v, requiredStrength: 4);
    setState(() {
      // required and required-strength: the owner checks (no form participation).
      _passwordError = v.isEmpty ? 'Please fill in this field.' : check.strengthMessage;
      if (_passwordError == null) _submitted = 'Submitted: user="ana", password of ${v.length} characters';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    final muted = theme.text(size: 14, color: theme.colors.muted);
    Widget column(List<Widget> children) => SizedBox(
      width: 340,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 16), children[i]],
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
              const KakaoPasswordInput(label: 'Password', placeholder: 'Your password'),
              const KakaoPasswordInput(label: 'Password', hint: 'Case sensitive.'),
              const KakaoPasswordInput(label: 'Password', value: 'hunter2', error: 'That password is not right.'),
              const KakaoPasswordInput(size: KakaoPasswordInputSize.sm, label: 'Small', value: '36px tall'),
              const KakaoPasswordInput(label: 'Medium', value: '44px tall'),
              const KakaoPasswordInput(size: KakaoPasswordInputSize.lg, label: 'Large', value: '52px tall'),
              const KakaoPasswordInput(disabled: true, label: 'Disabled', value: 'secret'),
              const KakaoPasswordInput(readOnly: true, label: 'Read only', value: 'secret'),
              const KakaoPasswordInput(hideToggle: true, label: 'No toggle', value: 'secret'),
            ]),
            column([
              KakaoPasswordInput(
                label: 'New password',
                requirements: true,
                onRequirementsChanged: (r) => _event(_log, _requirements(r)),
                onToggled: (v) => _event(_log, 'password-input-toggle · visible $v'),
                onCommitted: (v) => _event(_log, 'change · ${v.length} characters'),
              ),
              Text(_log.isEmpty ? 'Type a password to see its events.' : _log.join('\n'), style: muted),
              KakaoPasswordInput(label: 'Passphrase', requirements: true, requirementList: passphraseRequirements),
              const KakaoPasswordInput(label: 'Admin password', requirements: true, minLength: 12),
              KakaoPasswordInput(label: 'Account password', requirements: true, requirementList: accountRequirements),
            ]),
            column([
              const KakaoTextInput(label: 'Username', value: 'ana', autofillHints: [AutofillHints.username]),
              KakaoPasswordInput(
                controller: _password,
                label: 'Password',
                requiredStrength: 4,
                hint: 'Meet at least 4 of the 5.',
                error: _passwordError,
                onChanged: (_) {
                  if (_passwordError != null) setState(() => _passwordError = null);
                },
                onSubmitted: (_) => _submit(),
              ),
              Row(
                children: [KakaoButton(label: 'Create account', onPressed: _submit)],
              ),
              Text(_submitted, style: muted),
            ]),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: 420,
          child: KakaoPasswordInput(
            label: 'Password',
            value: _play,
            visible: _playVisible,
            requirements: true,
            requiredStrength: KakaoPasswordInput.allRequirements,
            onChanged: (v) => _play = v,
            onToggled: (v) {
              _playVisible = v;
              _event(_playLog, 'password-input-toggle · visible $v');
            },
            onRequirementsChanged: (r) => _event(_playLog, _requirements(r)),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            KakaoButton(
              label: 'value = "Tr0ub4dor"',
              variant: KakaoButtonVariant.secondary,
              size: KakaoButtonSize.sm,
              onPressed: () => setState(() => _play = 'Tr0ub4dor'),
            ),
            KakaoButton(
              label: 'value = ""',
              variant: KakaoButtonVariant.secondary,
              size: KakaoButtonSize.sm,
              onPressed: () => setState(() => _play = ''),
            ),
            KakaoButton(
              label: 'toggle visible',
              variant: KakaoButtonVariant.secondary,
              size: KakaoButtonSize.sm,
              onPressed: () => setState(() => _playVisible = !(_playVisible ?? false)),
            ),
            KakaoButton(
              label: 'check strength',
              variant: KakaoButtonVariant.secondary,
              size: KakaoButtonSize.sm,
              onPressed: () {
                final message = KakaoPasswordInput.evaluate(_play, requiredStrength: 0).strengthMessage;
                _event(_playLog, 'valid ${message == null}${message == null ? '' : ' · $message'}');
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(_playLog.isEmpty ? 'Use the buttons or type to see events.' : _playLog.join('\n'), style: muted),
      ],
    );
  }
}

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
