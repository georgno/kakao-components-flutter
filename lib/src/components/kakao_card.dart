import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import '../settings/kakao_card_settings.g.dart';
import '../theme/kakao_theme.dart';
import '../theme/kakao_values.dart';
import 'kakao_button.dart';

/// Flutter twin of `<kakao-card>`: optional header, body, optional footer.
///
/// - Body children are spaced by the card's gap (`--kakao-card-gap`), as the
///   web card spaces its slotted children.
/// - When the footer starts with a [KakaoButton], a very subtle, blurred
///   radial glow in that button's colour rises from the bottom left, where
///   the button sits: primary → ink, secondary → subtle-strong, danger →
///   danger; a ghost button has no colour of its own, so no glow. The colour
///   fades (400 ms) when the button or the theme changes. [noGlow] turns it off.
/// - When the content changes height, the card glides to its new height
///   (`--kakao-card-resize-*`); off with [animateSize] false or reduced motion.
class KakaoCard extends StatelessWidget {
  const KakaoCard({
    super.key,
    this.header,
    required this.children,
    this.footer = const [],
    this.noGlow = false,
    this.animateSize = true,
  });

  /// `slot="header"`: usually a title.
  final Widget? header;

  /// The body.
  final List<Widget> children;

  /// `slot="footer"`: a row of buttons, the main one first (it gives the glow).
  final List<Widget> footer;

  /// `no-glow`.
  final bool noGlow;

  /// The opposite of `no-animate`.
  final bool animateSize;

  /// The glow colour the web card's page rules pick for its first footer button.
  static Color? glowColorFor(Widget? first, KakaoThemeValues theme) {
    if (first is! KakaoButton) return null;
    final c = theme.colors;
    return switch (first.variant) {
      KakaoButtonVariant.primary => c.ink, // --kakao-button-primary-bg → ink
      KakaoButtonVariant.secondary => c.subtleStrong, // --kakao-button-secondary-bg → subtle-strong
      KakaoButtonVariant.danger => c.danger, // --kakao-button-danger-bg → danger
      KakaoButtonVariant.ghost => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = KakaoTheme.of(context);
    final st = KakaoCardSettings.of(theme.colors);
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final glow = noGlow ? null : glowColorFor(footer.isEmpty ? null : footer.first, theme);

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ?header,
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0 || header != null) SizedBox(height: st.gap),
          children[i],
        ],
        if (footer.isNotEmpty) ...[
          // The footer sits footer-spacing below the body (padding-top: spacing − gap, plus the gap).
          SizedBox(height: st.footerSpacing),
          Wrap(
            spacing: st.footerGap,
            runSpacing: st.footerGap,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: footer,
          ),
        ],
      ],
    );
    if (animateSize && !reduce) {
      content = AnimatedSize(
        duration: st.resizeDuration,
        curve: st.resizeEasing,
        alignment: Alignment.topCenter,
        child: content,
      );
    }

    final radius = BorderRadius.circular(st.radius);
    return DefaultTextStyle.merge(
      style: TextStyle(color: st.text),
      child: Container(
        decoration: BoxDecoration(
          color: st.bg,
          borderRadius: radius,
          border: Border.all(color: st.border),
        ),
        // Container insets its child by the 1px border, so the child is the
        // padding box: the glow is clipped to it (overflow: hidden) and
        // measured from it, as on the web.
        child: ClipRRect(
          borderRadius: BorderRadius.circular(st.radius - 1),
          child: Stack(
            children: [
              Positioned.fill(
                child: TweenAnimationBuilder<Color?>(
                  // --kakao-card-glow-color is a registered colour: it fades, 400ms ease.
                  // No glow fades to the same colour at zero alpha, not through black.
                  tween: ColorTween(end: glow ?? theme.colors.ink.withValues(alpha: 0)),
                  duration: reduce ? Duration.zero : const Duration(milliseconds: 400),
                  curve: Curves.ease,
                  builder: (context, color, _) =>
                      color == null || color.a == 0 ? const SizedBox.shrink() : _Glow(color: color, settings: st),
                ),
              ),
              Padding(padding: EdgeInsets.all(st.padding), child: content),
            ],
          ),
        ),
      ),
    );
  }
}

/// The card's glow, as the web card draws it:
/// `radial-gradient(circle SIZE at X (100% − Y), color-mix(COLOUR STRENGTH,
/// transparent), transparent 70%)` with `filter: blur(BLUR)`, a Gaussian
/// whose deviation is that length.
class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.settings});
  final Color color;
  final KakaoCardSettings settings;

  @override
  Widget build(BuildContext context) {
    final st = settings;
    final inner = kakaoMix(color, st.glowStrength * 100, const Color(0x00000000), null);
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: st.glowBlur, sigmaY: st.glowBlur, tileMode: TileMode.decal),
        child: CustomPaint(painter: _GlowPainter(inner, st)),
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  _GlowPainter(this.inner, this.st);
  final Color inner;
  final KakaoCardSettings st;

  @override
  void paint(Canvas canvas, Size size) {
    // glow-x / glow-y from the bottom-left of the padding box.
    final center = Offset(st.glowX, size.height - st.glowY);
    final shader = RadialGradient(
      colors: [inner, inner.withValues(alpha: 0)],
      stops: const [0, 0.7],
    ).createShader(Rect.fromCircle(center: center, radius: st.glowSize));
    // Paint beyond the edges so the blur doesn't fade at the clip (the web glow
    // reaches 2 × blur past the card).
    canvas.drawRect((Offset.zero & size).inflate(st.glowBlur * 2), Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_GlowPainter old) => old.inner != inner || old.st.glowSize != st.glowSize;
}
