import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// `color-mix(in srgb, a pa%, b pb%)` exactly as CSS Color 4 defines it (and
/// tools/export-tokens.js computes it): missing percentages make up 100,
/// channels are mixed premultiplied by alpha, a sum under 100% lowers the
/// alpha. Rounded to 8 bits per channel, as browsers draw it.
Color kakaoMix(Color a, double? pa, Color b, double? pb) {
  var p = pa;
  var q = pb;
  if (p == null && q == null) {
    p = q = 50;
  } else if (p == null) {
    p = 100 - q!;
  } else {
    q ??= 100 - p;
  }
  final sum = p + q;
  if (sum <= 0) return const Color(0x00000000);
  final wa = p / sum;
  final wb = q / sum;
  final alpha = a.a * wa + b.a * wb;
  double ch(double ca, double cb) => alpha == 0 ? 0 : (ca * a.a * wa + cb * b.a * wb) / alpha;
  int to8(double x) => (x.clamp(0.0, 1.0) * 255).round();
  return Color.fromARGB(to8(alpha * math.min(1, sum / 100)), to8(ch(a.r, b.r)), to8(ch(a.g, b.g)), to8(ch(a.b, b.b)));
}

/// A CSS `box-shadow` blur as Flutter's [BoxShadow.blurRadius], so the
/// shadow is as soft as on the web: CSS blurs with a Gaussian of
/// σ = blur / 2, Flutter with σ = blurRadius × 0.57735 + 0.5.
double kakaoCssBlur(double cssBlur) => cssBlur <= 1 ? 0 : (cssBlur / 2 - 0.5) / 0.57735;

/// A font shorthand from a settings block (`0.95rem/1.4 …`, `550 0.875rem/1 …`).
/// The family is always the kakao font, so it is not carried.
@immutable
class KakaoFontSpec {
  const KakaoFontSpec({required this.size, required this.lineHeight, this.weight});
  final double size;
  final double lineHeight;
  final double? weight;

  @override
  bool operator ==(Object other) =>
      other is KakaoFontSpec && other.size == size && other.lineHeight == lineHeight && other.weight == weight;

  @override
  int get hashCode => Object.hash(size, lineHeight, weight);
}

/// A length in `em`: a factor of the font size where it is used.
@immutable
class KakaoEm {
  const KakaoEm(this.factor);
  final double factor;

  double of(double fontSize) => factor * fontSize;

  @override
  bool operator ==(Object other) => other is KakaoEm && other.factor == factor;

  @override
  int get hashCode => factor.hashCode;
}

/// A length in viewport units (`vh`, `vw`, `dvh`), resolved against the
/// screen the widget is on.
@immutable
class KakaoViewportLength {
  const KakaoViewportLength(this.unit, this.value);
  final String unit;
  final double value;

  double of(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    return switch (unit) {
      'vw' => size.width * value / 100,
      // dvh: the visible height (without system bars); vh: the full height.
      'dvh' => (size.height - padding.vertical) * value / 100,
      _ => size.height * value / 100,
    };
  }

  @override
  bool operator ==(Object other) => other is KakaoViewportLength && other.unit == unit && other.value == value;

  @override
  int get hashCode => Object.hash(unit, value);
}
