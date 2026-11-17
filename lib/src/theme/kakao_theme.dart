import 'package:flutter/widgets.dart';

import 'kakao_colors.g.dart';

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

  // --kakao-motion-duration, --kakao-ease-*
  Duration get motionDuration => const Duration(milliseconds: 320);
  Curve get easeStandard => const Cubic(.2, 0, 0, 1);
  Curve get easeSpring => const Cubic(.5, 1.8, .4, 1);
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
  /// such as 550, which the variable font draws exactly.
  TextStyle text({double? size, double weight = 400, Color? color, double? height}) => TextStyle(
    fontFamily: tokens.fontFamily,
    package: tokens.fontPackage,
    fontSize: size ?? tokens.fontSize,
    fontWeight: FontWeight.values[((weight / 100).round() - 1).clamp(0, 8)],
    fontVariations: [FontVariation.weight(weight)],
    color: color ?? colors.text,
    height: height,
    decoration: TextDecoration.none,
  );
}

/// Puts a kakao theme into the tree, like `data-kakao-theme` on the web.
///
/// Nest one to theme part of a screen differently. When the platform asks
/// for more contrast (`MediaQuery.highContrastOf`), the theme's high-contrast
/// colours are used, as `prefers-contrast: more` does on the web.
class KakaoTheme extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final more = MediaQuery.maybeHighContrastOf(context) ?? false;
    final values = KakaoThemeValues(data: data, colors: more ? data.highContrast : data.colors);
    // A base text style, so text below never falls back to Flutter's
    // missing-style look (yellow double underline) outside a Material.
    return _KakaoThemeScope(
      values: values,
      child: DefaultTextStyle(style: values.text(), child: child),
    );
  }
}

class _KakaoThemeScope extends InheritedWidget {
  const _KakaoThemeScope({required this.values, required super.child});

  final KakaoThemeValues values;

  @override
  bool updateShouldNotify(_KakaoThemeScope old) => old.values.data != values.data || old.values.colors != values.colors;
}
