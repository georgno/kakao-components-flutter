import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakao_showcase/lookalike/fixtures.dart';
import 'package:kakao_showcase/lookalike/lookalike_app.dart';

void main() {
  final cases = (jsonDecode(File('../tool/lookalike/cases.json').readAsStringSync())['cases'] as List)
      .map((c) => (c as Map<String, dynamic>)['id'] as String)
      .toList();

  test('every look-alike case has a fixture, and every fixture a case', () {
    expect(lookalikeFixtures.keys.toSet(), cases.toSet());
  });

  test('look-alike mode only with ?lookalike', () {
    expect(LookalikeApp.queryOf(Uri.parse('http://x/')), isNull);
    expect(LookalikeApp.queryOf(Uri.parse('http://x/?lookalike=card-primary&theme=dark'))?['theme'], 'dark');
  });

  for (final id in cases) {
    for (final contrast in ['', 'more']) {
      testWidgets('fixture $id builds${contrast.isEmpty ? '' : ' (more contrast)'}', (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          LookalikeApp(query: {'lookalike': id, 'theme': 'dark', 'w': '640', 'bg': '101010', 'contrast': contrast, 'settle': '0'}),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.textContaining('No look-alike fixture'), findsNothing);
      });
    }
  }
}
