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
                      label: t.name[0].toUpperCase() + t.name.substring(1),
                      size: KakaoButtonSize.sm,
                      variant: KakaoButtonVariant.secondary,
                      toggle: true,
                      pressed: choice.chosen == t,
                      onPressed: () => choice.onChoose(t),
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
            const _Heading('Card'),
            const _CardExamples(),
            _Section(title: 'Dialog', child: const _DialogExamples()),
            _Section(title: 'Popover', child: const _PopoverExamples()),
            _Section(title: 'Progress', child: const _ProgressExamples()),
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
