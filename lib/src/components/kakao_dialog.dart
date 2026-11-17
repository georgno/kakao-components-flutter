import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../settings/kakao_button_settings.g.dart';
import '../settings/kakao_dialog_settings.g.dart';
import '../theme/kakao_theme.dart';
import 'kakao_button.dart';

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
/// the body scrolls, so header and footer stay put. Footer rule: the main
/// (filled) button sits in the corner, last for [KakaoDialogButtonPosition.right]
/// and first for left; that corner then rounds to the button's radius + the
/// padding, so the two curves sit concentric. A ghost button has no shape at
/// rest and doesn't count. With [fullWidth] the buttons share the width and
/// both bottom corners can hold one.
class KakaoDialog extends StatelessWidget {
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

  /// The radius a bottom corner takes when [w] (a footer widget) sits in it:
  /// a filled button's radius + the dialog padding, else null.
  static double? cornerFor(Widget? w, KakaoButtonSettings buttons, double padding) {
    if (w is! KakaoButton || w.variant == KakaoButtonVariant.ghost) return null;
    final r = switch (w.size) {
      KakaoButtonSize.sm => buttons.smRadius,
      KakaoButtonSize.md => buttons.mdRadius,
      KakaoButtonSize.lg => buttons.lgRadius,
    };
    return r + padding;
  }

  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    final st = KakaoDialogSettings.of(theme.colors);
    final buttons = KakaoButtonSettings.of(theme.colors);

    final maxWidth = switch (size) {
      KakaoDialogSize.sm => st.widthSm,
      KakaoDialogSize.md => st.widthMd,
      KakaoDialogSize.lg => st.widthLg,
    };

    // Which bottom corners hold a filled button.
    double? bl;
    double? br;
    if (footer.isNotEmpty) {
      if (fullWidth) {
        bl = cornerFor(footer.first, buttons, st.padding);
        br = cornerFor(footer.last, buttons, st.padding);
      } else if (buttonPosition == KakaoDialogButtonPosition.right) {
        br = cornerFor(footer.last, buttons, st.padding);
      } else if (buttonPosition == KakaoDialogButtonPosition.left) {
        bl = cornerFor(footer.first, buttons, st.padding);
      }
    }
    final r = Radius.circular(st.radius);

    final title = header == null
        ? null
        : DefaultTextStyle.merge(
            style: theme.text(size: st.titleSize, weight: st.titleWeight, tracking: -0.01, height: 1.3, color: st.text),
            child: header!,
          );

    final footerRow = footer.isEmpty
        ? null
        : fullWidth
        ? Row(
            children: [
              for (var i = 0; i < footer.length; i++) ...[
                if (i > 0) SizedBox(width: st.footerGap),
                Expanded(child: KakaoButtonStretch(child: footer[i])),
              ],
            ],
          )
        : Wrap(
            alignment: switch (buttonPosition) {
              KakaoDialogButtonPosition.left => WrapAlignment.start,
              KakaoDialogButtonPosition.center => WrapAlignment.center,
              KakaoDialogButtonPosition.right => WrapAlignment.end,
            },
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: st.footerGap,
            runSpacing: st.footerGap,
            children: footer,
          );

    // The panel takes focus when it opens (dialog.js), so Tab starts here and
    // Escape reaches the dialog's shortcut.
    return Focus(
      autofocus: true,
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: header == null ? label : null,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16), // the host's 1rem inset
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: st.maxHeight.of(context)),
              child: DefaultTextStyle.merge(
                style: TextStyle(color: st.text),
                child: Container(
                  padding: EdgeInsets.all(st.padding),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: st.bg,
                    borderRadius: BorderRadius.only(
                      topLeft: r,
                      topRight: r,
                      bottomLeft: bl == null ? r : Radius.circular(bl),
                      bottomRight: br == null ? r : Radius.circular(br),
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
                              for (var i = 0; i < children.length; i++) ...[
                                if (i > 0) SizedBox(height: st.gap),
                                children[i],
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
