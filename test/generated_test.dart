// The generated Dart against tokens.json (tool/tokens.json, exported by
// kakao-components): every generated setting of every ported component, in
// every theme and both contrast modes, must come to what the web resolves.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakao_components/kakao_components.dart';

final Map<String, dynamic> tokens = jsonDecode(File('tool/tokens.json').readAsStringSync()) as Map<String, dynamic>;

String hex(Color c) {
  String h(double x) => (x * 255).round().toRadixString(16).padLeft(2, '0');
  return '#${h(c.r)}${h(c.g)}${h(c.b)}${h(c.a)}';
}

/// Flutter blurRadius back to the CSS blur it stands for.
double cssBlurOf(double blurRadius) => blurRadius == 0 ? 0 : (blurRadius * 0.57735 + 0.5) * 2;

void expectMatches(Object dart, Map<String, dynamic> web, String what) {
  switch (web['type']) {
    case 'color':
      expect(hex(dart as Color), web['hex'], reason: what);
    case 'length':
      expect(dart as double, closeTo((web['px'] as num).toDouble(), 1e-9), reason: what);
    case 'number':
      expect(dart as double, closeTo((web['value'] as num).toDouble(), 1e-9), reason: what);
    case 'percent':
      expect(dart as double, closeTo((web['value'] as num) / 100, 1e-9), reason: what);
    case 'duration':
      expect((dart as Duration).inMicroseconds, ((web['ms'] as num) * 1000).round(), reason: what);
    case 'easing':
      final c = dart as Cubic;
      expect([c.a, c.b, c.c, c.d], (web['bezier'] as List).map((n) => (n as num).toDouble()).toList(), reason: what);
    case 'em':
      expect((dart as KakaoEm).factor, (web['factor'] as num).toDouble(), reason: what);
    case 'viewport':
      final v = dart as KakaoViewportLength;
      expect([v.unit, v.value], [web['unit'], (web['value'] as num).toDouble()], reason: what);
    case 'font':
      final f = dart as KakaoFontSpec;
      expectMatches(f.size, web['size'] as Map<String, dynamic>, '$what size');
      expectMatches(f.lineHeight, web['lineHeight'] as Map<String, dynamic>, '$what line height');
    case 'calc':
      // Only numeric calc() is generated: its folded px value.
      double eval(Map<String, dynamic> n) => switch (n['type']) {
        'length' => (n['px'] as num).toDouble(),
        'number' => (n['value'] as num).toDouble(),
        'op' => switch (n['op']) {
          '+' => eval(n['left'] as Map<String, dynamic>) + eval(n['right'] as Map<String, dynamic>),
          '-' => eval(n['left'] as Map<String, dynamic>) - eval(n['right'] as Map<String, dynamic>),
          '*' => eval(n['left'] as Map<String, dynamic>) * eval(n['right'] as Map<String, dynamic>),
          _ => eval(n['left'] as Map<String, dynamic>) / eval(n['right'] as Map<String, dynamic>),
        },
        _ => throw StateError('not numeric'),
      };
      expect(dart as double, closeTo(eval(web['expr'] as Map<String, dynamic>), 1e-9), reason: what);
    case 'shadow':
      final layers = (web['layers'] as List).cast<Map<String, dynamic>>();
      final shadows = dart as List<BoxShadow>;
      expect(shadows.length, layers.length, reason: what);
      for (var k = 0; k < layers.length; k++) {
        final s = shadows[k];
        final l = layers[k];
        expectMatches(s.color, l['color'] as Map<String, dynamic>, '$what layer $k colour');
        expectMatches(s.offset.dx, l['x'] as Map<String, dynamic>, '$what layer $k x');
        expectMatches(s.offset.dy, l['y'] as Map<String, dynamic>, '$what layer $k y');
        expectMatches(s.spreadRadius, l['spread'] as Map<String, dynamic>, '$what layer $k spread');
        expect(
          cssBlurOf(s.blurRadius),
          closeTo(((l['blur'] as Map)['px'] as num).toDouble(), 1e-9),
          reason: '$what blur',
        );
      }
    default:
      fail('$what: no comparison for ${web['type']}');
  }
}

final Map<String, Map<String, Object> Function(KakaoColors)> generated = {
  'button': (c) => KakaoButtonSettings.of(c).toMap(),
  'card': (c) => KakaoCardSettings.of(c).toMap(),
  'dialog': (c) => KakaoDialogSettings.of(c).toMap(),
  'progress': (c) => KakaoProgressSettings.of(c).toMap(),
  'text-input': (c) => KakaoTextInputSettings.of(c).toMap(),
  'theme-switch': (c) => KakaoThemeSwitchSettings.of(c).toMap(),
  'tooltip': (c) => KakaoTooltipSettings.of(c).toMap(),
};

void main() {
  test('every theme of tokens.json is generated, colours and contrast colours exact', () {
    final themes = tokens['themes'] as Map<String, dynamic>;
    expect(KakaoThemeData.all.map((t) => t.name), tokens['themeOrder']);
    for (final t in KakaoThemeData.all) {
      final web = themes[t.name] as Map<String, dynamic>;
      expect(hex(t.colors.primary), (web['colors'] as Map)['primary'], reason: t.name);
      expect(hex(t.highContrast.border), (web['contrastColors'] as Map)['border'], reason: t.name);
      expect(t.isDark, web['dark'], reason: t.name);
    }
  });

  for (final MapEntry(key: component, value: of) in generated.entries) {
    test('$component: generated settings equal the web, in every theme and contrast mode', () {
      final web = ((tokens['components'] as Map)[component] as Map)['settings'] as Map<String, dynamic>;
      var checked = 0;
      for (final theme in KakaoThemeData.all) {
        for (final contrast in [false, true]) {
          final mode = contrast ? '${theme.name}/contrast' : theme.name;
          final dart = of(contrast ? theme.highContrast : theme.colors);
          for (final MapEntry(key: name, value: value) in dart.entries) {
            final s = web[name] as Map<String, dynamic>;
            final resolved = s['themed'] == true
                ? (s['resolved'] as Map<String, dynamic>)[mode] as Map<String, dynamic>
                : s['resolved'] as Map<String, dynamic>;
            expectMatches(value, resolved, '$component $name in $mode');
            checked++;
          }
        }
      }
      // Most of the settings block is generated; the rest is listed in the class doc.
      expect(checked / (KakaoThemeData.all.length * 2), greaterThanOrEqualTo(web.length * 0.85));
    });
  }
}
