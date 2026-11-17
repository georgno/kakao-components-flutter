import 'package:flutter/widgets.dart';

import 'kakao_colors.g.dart';

/// One step of the styleguide's type scale (styleguide.html, Typography).
@immutable
class KakaoTextStep {
  const KakaoTextStep(this.size, this.weight, [this.tracking = 0]);

  /// Logical pixels (1rem = 16).
  final double size;
  final double weight;

  /// Letter spacing in em.
  final double tracking;
}

/// Non-colour main variables (`shared/tokens.css` on the web).
///
/// Lengths are logical pixels; 1rem on the web is 16 here.
class KakaoTokens {
  const KakaoTokens();

  // --kakao-space-*
  double get spaceX => 12; // 0.75rem
  double get spaceY => 8; // 0.5rem
  double get spaceGap => 16; // 1rem
  double get spaceBelowBar => 8;
  double get scrollFade => 24; // 1.5rem

  // --kakao-radius-*
  double get radiusXs => 4;
  double get radiusSm => 6;
  double get radiusMd => 10;
  double get radiusLg => 14;
  double get radiusPill => 999;

  // --kakao-font-*
  String get fontFamily => 'Inter Tight';
  String get fontPackage => 'kakao_components';
  double get fontSize => 15.2; // 0.95rem

  // Type scale (styleguide: Typography → Type scale).
  KakaoTextStep get text2xl => const KakaoTextStep(28, 650, -0.02); // page title
  KakaoTextStep get textXl => const KakaoTextStep(18, 600, -0.01); // section heading, dialog title
  KakaoTextStep get textLg => const KakaoTextStep(16, 400); // body, large button labels
  KakaoTextStep get textBase => const KakaoTextStep(15, 400); // field values and labels
  KakaoTextStep get textSm => const KakaoTextStep(14, 400); // dense UI
  KakaoTextStep get textXs => const KakaoTextStep(13, 400); // small buttons, helper text
  KakaoTextStep get text2xs => const KakaoTextStep(12, 600); // group label, caption

  // --kakao-motion-duration, --kakao-ease-*
  Duration get motionDuration => const Duration(milliseconds: 320);
  Curve get easeStandard => const Cubic(.2, 0, 0, 1);
  Curve get easeSpring => const Cubic(.5, 1.8, .4, 1);

  // --kakao-theme-switch-fade-duration / -easing (theme pickers cross-fade).
  Duration get themeFadeDuration => const Duration(milliseconds: 280);
  Curve get themeFadeEasing => const Cubic(.4, 0, .2, 1);
}

/// The resolved theme a widget reads: colours (with the platform's contrast
/// setting applied) plus the shared tokens.
@immutable
class KakaoThemeValues {
  const KakaoThemeValues({required this.data, required this.colors, this.tokens = const KakaoTokens()});

  final KakaoThemeData data;
  final KakaoColors colors;
  final KakaoTokens tokens;

  bool get isDark => data.isDark;

  /// A text style in the kakao font. [weight] accepts in-between weights
  /// such as 550, which the variable font draws exactly. [tracking] is
  /// letter spacing in em. [tabular] gives figures of equal width, for
  /// values that change in place (styleguide: Numbers).
  TextStyle text({
    double? size,
    double weight = 400,
    Color? color,
    double? height,
    double tracking = 0,
    bool tabular = false,
  }) {
    final s = size ?? tokens.fontSize;
    return TextStyle(
      fontFamily: tokens.fontFamily,
      package: tokens.fontPackage,
      fontSize: s,
      fontWeight: FontWeight.values[((weight / 100).round() - 1).clamp(0, 8)],
      fontVariations: [FontVariation.weight(weight)],
      fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
      letterSpacing: tracking == 0 ? null : tracking * s,
      color: color ?? colors.text,
      height: height,
      decoration: TextDecoration.none,
    );
  }

  /// [text] at a step of the type scale.
  TextStyle step(KakaoTextStep step, {Color? color, double? weight, double? height, bool tabular = false}) => text(
    size: step.size,
    weight: weight ?? step.weight,
    tracking: step.tracking,
    color: color,
    height: height,
    tabular: tabular,
  );
}

/// Puts a kakao theme into the tree, like `data-kakao-theme` on the web.
///
/// Nest one to theme part of a screen differently. When the platform asks
/// for more contrast (`MediaQuery.highContrastOf`), the theme's high-contrast
/// colours are used, as `prefers-contrast: more` does on the web. A change of
/// [data] cross-fades the colours (280 ms), as the web's theme pickers do;
/// with reduced motion the theme changes at once.
class KakaoTheme extends StatefulWidget {
  const KakaoTheme({super.key, required this.data, required this.child});

  final KakaoThemeData data;
  final Widget child;

  /// The nearest theme; light when there is none (components work bare,
  /// like the web components without tokens.css).
  static KakaoThemeValues of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_KakaoThemeScope>();
    return scope?.values ?? KakaoThemeValues(data: KakaoThemeData.light, colors: KakaoThemeData.light.colors);
  }

  @override
  State<KakaoTheme> createState() => _KakaoThemeState();
}

class _KakaoThemeState extends State<KakaoTheme> with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(vsync: this, value: 1);
  KakaoColors? _from; // colours on screen when the theme changed

  KakaoColors _target(BuildContext context) =>
      (MediaQuery.maybeHighContrastOf(context) ?? false) ? widget.data.highContrast : widget.data.colors;

  KakaoColors _current(BuildContext context) {
    final to = _target(context);
    final from = _from;
    if (from == null || _fade.value >= 1) return to;
    return KakaoColors.lerp(from, to, const KakaoTokens().themeFadeEasing.transform(_fade.value));
  }

  @override
  void didUpdateWidget(KakaoTheme old) {
    super.didUpdateWidget(old);
    if (old.data == widget.data) return;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _from = null;
      return;
    }
    final more = MediaQuery.maybeHighContrastOf(context) ?? false;
    final oldColors = more ? old.data.highContrast : old.data.colors;
    // Start from whatever is on screen, also when a fade is still running.
    final from = _from;
    _from = (from != null && _fade.value < 1)
        ? KakaoColors.lerp(from, oldColors, const KakaoTokens().themeFadeEasing.transform(_fade.value))
        : oldColors;
    _fade.duration = const KakaoTokens().themeFadeDuration;
    _fade.forward(from: 0);
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _fade,
    builder: (context, child) {
      final values = KakaoThemeValues(data: widget.data, colors: _current(context));
      // A base text style, so text below never falls back to Flutter's
      // missing-style look (yellow double underline) outside a Material.
      return _KakaoThemeScope(
        values: values,
        child: DefaultTextStyle(style: values.text(), child: child!),
      );
    },
    child: widget.child,
  );
}

class _KakaoThemeScope extends InheritedWidget {
  const _KakaoThemeScope({required this.values, required super.child});

  final KakaoThemeValues values;

  @override
  bool updateShouldNotify(_KakaoThemeScope old) => old.values.data != values.data || old.values.colors != values.colors;
}
