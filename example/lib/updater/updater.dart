import 'package:flutter/widgets.dart';
import 'package:kakao_components/kakao_components.dart';

import '../build_info.dart';
import 'update_source.dart';
import 'updater_stub.dart' if (dart.library.io) 'updater_io.dart' as platform;

/// Checks for a newer CI build when the app opens (and when it comes back to
/// the foreground after a while), then offers to download and install it.
///
/// Wrap the app's home in it. Only CI builds on Android check; a local
/// `flutter run` build never does.
class Updater extends StatefulWidget {
  const Updater({
    super.key,
    required this.navigatorKey,
    required this.child,
    this.platformOverride,
    this.currentBuild = BuildInfo.number,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  final UpdatePlatform? platformOverride;

  /// This app's build number (0 = local build, never updates).
  final int currentBuild;

  /// Runs a check now and says so when there is nothing new.
  static Future<void> checkNow(BuildContext context) =>
      context.findAncestorStateOfType<_UpdaterState>()!._check(manual: true);

  @override
  State<Updater> createState() => _UpdaterState();
}

class _UpdaterState extends State<Updater> with WidgetsBindingObserver {
  late final UpdatePlatform _platform = widget.platformOverride ?? platform.createPlatform();
  DateTime? _lastCheck;
  int? _dismissedBuild;
  bool _open = false;

  static const _recheckAfter = Duration(minutes: 10);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        (_lastCheck == null || DateTime.now().difference(_lastCheck!) > _recheckAfter)) {
      _check();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;

  Future<void> _check({bool manual = false}) async {
    if (_open) return;
    if (!_platform.supported || widget.currentBuild <= 0) {
      if (manual) {
        _message('Updates', 'Only CI builds on Android update themselves. This is a ${BuildInfo.label.toLowerCase()}.');
      }
      return;
    }
    _lastCheck = DateTime.now();
    final release = await _platform.latest(BuildInfo.updateUrl);
    if (!mounted) return;
    if (release == null) {
      if (manual) _message('Updates', 'The update server could not be reached. Try again later.');
      return;
    }
    if (release.build <= widget.currentBuild || (!manual && release.build == _dismissedBuild)) {
      if (manual) _message('Up to date', 'You have the newest build (${widget.currentBuild}).');
      return;
    }
    await _offer(release);
  }

  Future<void> _message(String title, String text) async {
    final nav = widget.navigatorKey.currentState;
    if (nav == null) return;
    _open = true;
    await showGeneralDialog<void>(
      context: nav.context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: const Color(0x73000000), // --kakao-dialog-scrim: rgb(0 0 0 / .45)
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, _, _) => ShowcaseDialog(
        title: title,
        body: Text(text, style: KakaoTheme.of(context).text(color: KakaoTheme.of(context).colors.textSoft)),
        actions: [KakaoButton(label: 'OK', onPressed: () => Navigator.of(context).pop())],
      ),
      transitionBuilder: _dialogTransition,
    );
    _open = false;
  }

  Future<void> _offer(ReleaseInfo release) async {
    final nav = widget.navigatorKey.currentState;
    if (nav == null) return;
    _open = true;
    final installed = await showGeneralDialog<bool>(
      context: nav.context,
      barrierDismissible: false,
      barrierColor: const Color(0x73000000),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, _, _) =>
          _UpdateDialog(release: release, platform: _platform, current: widget.currentBuild),
      transitionBuilder: _dialogTransition,
    );
    _open = false;
    if (installed != true) _dismissedBuild = release.build;
  }
}

Widget _dialogTransition(BuildContext context, Animation<double> a, Animation<double> _, Widget child) {
  final t = CurvedAnimation(parent: a, curve: const KakaoTokens().easeStandard);
  return FadeTransition(
    opacity: t,
    child: ScaleTransition(scale: Tween(begin: .96, end: 1.0).animate(t), child: child),
  );
}

enum _Stage { offer, downloading, permission, installing, failed }

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.release, required this.platform, required this.current});

  final ReleaseInfo release;
  final int current;
  final UpdatePlatform platform;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> with WidgetsBindingObserver {
  _Stage _stage = _Stage.offer;
  double _progress = 0;
  String? _error;
  String? _apk;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Back from Android's "install unknown apps" page: try the install again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _stage == _Stage.permission && _apk != null) _install();
  }

  Future<void> _update() async {
    setState(() {
      _stage = _Stage.downloading;
      _progress = 0;
    });
    try {
      _apk = await widget.platform.download(widget.release, (p) {
        if (mounted) setState(() => _progress = p);
      });
      await _install();
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _stage = _Stage.failed;
          _error = '$e';
        });
      }
    }
  }

  Future<void> _install() async {
    final started = await widget.platform.install(_apk!);
    if (!mounted) return;
    setState(() => _stage = started ? _Stage.installing : _Stage.permission);
  }

  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    final soft = theme.text(color: theme.colors.textSoft, height: 1.45);
    final r = widget.release;
    final (String body, List<Widget> actions) = switch (_stage) {
      _Stage.offer => (
        'Build ${r.build} is out (you have ${widget.current}).'
            '${r.message.isEmpty ? '' : '\n\n${r.message}'}',
        [
          KakaoButton(
            label: 'Later',
            variant: KakaoButtonVariant.ghost,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          KakaoButton(label: 'Update', onPressed: _update),
        ],
      ),
      _Stage.downloading => (
        'The new build is on its way. Android\'s installer opens when it is in.',
        [const KakaoButton(label: 'Update', loading: true, onPressed: null)],
      ),
      _Stage.permission => (
        'Android needs your permission to install updates from this app. '
            'Turn on "Allow from this source", then come back.',
        [
          KakaoButton(
            label: 'Later',
            variant: KakaoButtonVariant.ghost,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          KakaoButton(label: 'Try again', onPressed: _install),
        ],
      ),
      _Stage.installing => (
        'Android\'s installer is open. Confirm there to finish; the app restarts on the new build.',
        [
          KakaoButton(
            label: 'Close',
            variant: KakaoButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
      _Stage.failed => (
        'The update failed: $_error',
        [
          KakaoButton(
            label: 'Later',
            variant: KakaoButtonVariant.ghost,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          KakaoButton(label: 'Retry', onPressed: _update),
        ],
      ),
    };
    return ShowcaseDialog(
      title: 'Update available',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(body, style: soft),
          if (_stage == _Stage.downloading) ...[
            const SizedBox(height: 12),
            _Progress(label: 'Downloading build ${r.build}', value: _progress),
          ],
        ],
      ),
      actions: actions,
    );
  }
}

/// Interim stand-in for `<kakao-dialog>` (its settings block's values) until
/// KakaoDialog lands in the library.
class ShowcaseDialog extends StatelessWidget {
  const ShowcaseDialog({super.key, required this.title, required this.body, required this.actions});

  final String title;
  final Widget body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    final c = theme.colors;
    // Nesting rule: the corner holding a filled footer button rounds to that
    // button's radius + the dialog padding (md: 14 + 20 = 34); a ghost
    // button has no shape at rest, so its corner keeps the dialog radius.
    final last = actions.isEmpty ? null : actions.last;
    final filledCorner = last is KakaoButton && last.variant != KakaoButtonVariant.ghost;
    final buttonRadius = last is KakaoButton && last.size == KakaoButtonSize.sm ? 10.0 : 14.0;
    final radius = Radius.circular(theme.tokens.radiusLg);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480), // --_width-md: 30rem
          child: Container(
            padding: const EdgeInsets.all(20), // --_padding: 1.25rem
            decoration: BoxDecoration(
              color: c.raised,
              borderRadius: BorderRadius.only(
                topLeft: radius,
                topRight: radius,
                bottomLeft: radius,
                bottomRight: filledCorner ? Radius.circular(buttonRadius + 20) : radius,
              ),
              boxShadow: [
                const BoxShadow(offset: Offset(0, 8), blurRadius: 24, color: Color(0x14000000)),
                BoxShadow(spreadRadius: 1, color: c.text.withValues(alpha: .10)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: theme.step(theme.tokens.textXl)), // --_title-size / -weight
                const SizedBox(height: 12), // --_gap: 0.75rem
                body,
                const SizedBox(height: 20), // --_footer-spacing: 1.25rem
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8, // --_footer-gap: 0.5rem
                  runSpacing: 8,
                  children: actions,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Interim stand-in for `<kakao-progress>` with a label (its settings
/// block's values): label 550 at 0.875rem, value muted with tabular figures,
/// an 8px pill track that fills in 320 ms on the standard curve.
class _Progress extends StatelessWidget {
  const _Progress({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    final c = theme.colors;
    final v = value.clamp(0.0, 1.0);
    return Semantics(
      label: label,
      value: '${(v * 100).round()} %',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: theme.text(size: 14, weight: 550))),
              Text('${(v * 100).round()} %', style: theme.text(size: 14, color: c.muted, tabular: true)),
            ],
          ),
          const SizedBox(height: 6.4), // --kakao-progress-label-gap: 0.4rem
          ClipRRect(
            borderRadius: BorderRadius.circular(theme.tokens.radiusPill),
            child: SizedBox(
              height: 8, // --kakao-progress-height
              child: ColoredBox(
                color: c.subtleStrong, // --kakao-progress-track
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: v),
                  duration: theme.tokens.motionDuration, // --kakao-progress-fill-duration
                  curve: theme.tokens.easeStandard,
                  builder: (context, w, _) => FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: w,
                    child: ColoredBox(color: c.primary),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
