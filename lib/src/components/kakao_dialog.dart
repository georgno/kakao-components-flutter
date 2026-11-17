import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../settings/kakao_dialog_settings.g.dart';
import '../theme/kakao_theme.dart';
import 'kakao_button.dart';
import 'kakao_corner_scope.dart';

/// `<kakao-dialog size>`: the panel's max width.
enum KakaoDialogSize { sm, md, lg }

/// `<kakao-dialog button-position>`: where the footer buttons sit.
enum KakaoDialogButtonPosition { left, center, right }

/// Shows a [KakaoDialog] as a modal route and completes with what it was
/// closed with: `Navigator.pop(context, value)` from a footer button
/// (`data-close="value"`), or null for Escape and a tap on the covered page
/// (unless [dismissible] is false: `no-dismiss`).
///
/// Motion as dialog.js: the scrim fades in, the panel fades in while it rises
/// 8 px and grows from 98 %, all on `--kakao-dialog-duration` /
/// `--kakao-dialog-easing`; with reduced motion it appears at once.
Future<T?> showKakaoDialog<T>(
  BuildContext context, {
  Widget? header,
  String? label,
  required List<Widget> children,
  List<Widget> footer = const [],
  KakaoDialogSize size = KakaoDialogSize.md,
  KakaoDialogButtonPosition buttonPosition = KakaoDialogButtonPosition.right,
  bool fullWidth = false,
  bool dismissible = true,
}) => showKakaoDialogWith<T>(
  context,
  label: label,
  dismissible: dismissible,
  builder: (context) => KakaoDialog(
    header: header,
    label: label,
    size: size,
    buttonPosition: buttonPosition,
    fullWidth: fullWidth,
    footer: footer,
    children: children,
  ),
);

/// [showKakaoDialog] for a dialog whose content changes while it is open:
/// [builder] returns a [KakaoDialog] (usually from a stateful widget).
Future<T?> showKakaoDialogWith<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  String? label,
  bool dismissible = true,
}) {
  final theme = KakaoTheme.of(context);
  final st = KakaoDialogSettings.of(theme.colors);
  final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: label ?? 'Close',
    barrierColor: st.scrim,
    transitionDuration: reduce ? Duration.zero : st.duration,
    // Escape dismisses (the route's own DismissIntent action, so only when
    // dismissible), whatever shortcuts the app sets up, as the web dialog does.
    pageBuilder: (context, _, _) => Shortcuts(
      shortcuts: const {SingleActivator(LogicalKeyboardKey.escape): DismissIntent()},
      child: Builder(builder: builder),
    ),
    transitionBuilder: (context, animation, _, child) {
      if (reduce) return child;
      final t = CurvedAnimation(parent: animation, curve: st.easing, reverseCurve: st.easing.flipped);
      return FadeTransition(
        opacity: t,
        child: AnimatedBuilder(
          animation: t,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, 8 * (1 - t.value)),
            child: Transform.scale(scale: .98 + .02 * t.value, child: child),
          ),
          child: child,
        ),
      );
    },
  );
}

/// Flutter twin of `<kakao-dialog>`'s panel; show it with [showKakaoDialog].
///
/// The header is the title (18 px, 600, −0.01em, as `slot="header"`); only
/// the body scrolls, so header and footer stay put.
///
/// Footer rule: put the main (filled) button in the corner, last for
/// [KakaoDialogButtonPosition.right] and first for left. The nesting rule
/// then rounds a bottom corner to (button radius + padding) when a filled
/// footer button sits right in it, so the two curves are concentric. As in
/// dialog.js this is measured after layout, not read from the footer list:
/// it follows the buttons' sizes, wrappers around them, the alignment,
/// wrapping and [fullWidth] (where both corners can hold one). A ghost
/// button has no shape at rest and never counts; centred buttons sit in no
/// corner. While the dialog closes the corners keep their shape.
class KakaoDialog extends StatefulWidget {
  const KakaoDialog({
    super.key,
    this.header,
    this.label,
    required this.children,
    this.footer = const [],
    this.size = KakaoDialogSize.md,
    this.buttonPosition = KakaoDialogButtonPosition.right,
    this.fullWidth = false,
  });

  final Widget? header;

  /// Accessible name when there is no [header].
  final String? label;
  final List<Widget> children;
  final List<Widget> footer;
  final KakaoDialogSize size;
  final KakaoDialogButtonPosition buttonPosition;
  final bool fullWidth;

  @override
  State<KakaoDialog> createState() => _KakaoDialogState();
}

class _KakaoDialogState extends State<KakaoDialog> {
  final _panel = GlobalKey();
  late final _registry = KakaoCornerRegistry(onChange: _scheduleFit);
  bool _fitScheduled = false;

  /// Measured bottom corner radii (null: the dialog radius).
  double? _bl;
  double? _br;

  void _scheduleFit() {
    if (_fitScheduled) return;
    _fitScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitScheduled = false;
      if (mounted) _fitCorners();
    });
  }

  /// dialog.js `_fitCorners`: a corner follows a filled footer button whose
  /// face sits right in it (within 1.5 px of the padding on both sides).
  void _fitCorners() {
    // Only while open: closing is often a tap on a footer button, and the
    // corners keep their shape through the exit animation.
    final status = ModalRoute.of(context)?.animation?.status;
    if (status == AnimationStatus.reverse || status == AnimationStatus.dismissed) return;
    final panel = _panel.currentContext?.findRenderObject();
    if (panel is! RenderBox || !panel.hasSize) return;
    final pad = KakaoDialogSettings.of(KakaoTheme.of(context).colors).padding;
    bool near(double a, double b) => (a - b).abs() <= 1.5;
    double? bl;
    double? br;
    for (final e in _registry.entries) {
      if (!e.filled) continue;
      final box = e.context.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize || box.size.width == 0) continue;
      final r = box.localToGlobal(Offset.zero, ancestor: panel) & box.size;
      if (!near(panel.size.height - r.bottom, pad)) continue;
      if (near(panel.size.width - r.right, pad)) br = e.radius + pad;
      if (near(r.left, pad)) bl = e.radius + pad;
    }
    if (bl != _bl || br != _br) {
      setState(() {
        _bl = bl;
        _br = br;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    final st = KakaoDialogSettings.of(theme.colors);
    final w = widget;
    _scheduleFit();

    final maxWidth = switch (w.size) {
      KakaoDialogSize.sm => st.widthSm,
      KakaoDialogSize.md => st.widthMd,
      KakaoDialogSize.lg => st.widthLg,
    };
    final r = Radius.circular(st.radius);

    final title = w.header == null
        ? null
        : DefaultTextStyle.merge(
            style: theme.text(size: st.titleSize, weight: st.titleWeight, tracking: -0.01, height: 1.3, color: st.text),
            child: w.header!,
          );

    final footerRow = w.footer.isEmpty
        ? null
        : KakaoCornerScope(
            registry: _registry,
            child: w.fullWidth
                ? Row(
                    children: [
                      for (var i = 0; i < w.footer.length; i++) ...[
                        if (i > 0) SizedBox(width: st.footerGap),
                        Expanded(child: KakaoButtonStretch(child: w.footer[i])),
                      ],
                    ],
                  )
                : Wrap(
                    alignment: switch (w.buttonPosition) {
                      KakaoDialogButtonPosition.left => WrapAlignment.start,
                      KakaoDialogButtonPosition.center => WrapAlignment.center,
                      KakaoDialogButtonPosition.right => WrapAlignment.end,
                    },
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: st.footerGap,
                    runSpacing: st.footerGap,
                    children: w.footer,
                  ),
          );

    // The panel takes focus when it opens (dialog.js), so Tab starts here and
    // Escape reaches the dialog's shortcut.
    return Focus(
      autofocus: true,
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: w.header == null ? w.label : null,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16), // the host's 1rem inset
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: st.maxHeight.of(context)),
              child: DefaultTextStyle.merge(
                style: TextStyle(color: st.text),
                child: Container(
                  key: _panel,
                  padding: EdgeInsets.all(st.padding),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: st.bg,
                    borderRadius: BorderRadius.only(
                      topLeft: r,
                      topRight: r,
                      bottomLeft: _bl == null ? r : Radius.circular(_bl!),
                      bottomRight: _br == null ? r : Radius.circular(_br!),
                    ),
                    boxShadow: st.shadow,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (title != null) ...[title, SizedBox(height: st.gap)],
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < w.children.length; i++) ...[
                                if (i > 0) SizedBox(height: st.gap),
                                w.children[i],
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (footerRow != null) ...[SizedBox(height: st.footerSpacing), footerRow],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
