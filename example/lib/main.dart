import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kakao_components/kakao_components.dart';

import 'build_info.dart';
import 'updater/updater.dart';

void main() => runApp(const ShowcaseApp());

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
  bool _loading = false;

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
            Text('Kakao showcase', style: theme.text(size: 24, weight: 650)),
            const SizedBox(height: 4),
            Text('Flutter twins of kakao-components', style: theme.text(color: c.muted)),
            const SizedBox(height: 20),
            _Section(
              title: 'Theme',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  KakaoButton(
                    label: 'System',
                    size: KakaoButtonSize.sm,
                    variant: choice.chosen == null ? KakaoButtonVariant.primary : KakaoButtonVariant.secondary,
                    onPressed: () => choice.onChoose(null),
                  ),
                  for (final t in KakaoThemeData.all)
                    KakaoButton(
                      label: t.name[0].toUpperCase() + t.name.substring(1),
                      size: KakaoButtonSize.sm,
                      variant: choice.chosen == t ? KakaoButtonVariant.primary : KakaoButtonVariant.secondary,
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
                    loading: _loading,
                    onPressed: () async {
                      setState(() => _loading = true);
                      await Future<void>.delayed(const Duration(seconds: 2));
                      if (mounted) setState(() => _loading = false);
                    },
                  ),
                  const KakaoButton(label: 'Disabled'),
                ],
              ),
            ),
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

/// Interim stand-in for a `<kakao-card>` with a header, as on the demo pages.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colors.bg,
        borderRadius: BorderRadius.circular(theme.tokens.radiusLg),
        border: Border.all(color: theme.colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.text(weight: 600)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
