import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakao_components/kakao_components.dart';
import 'package:kakao_showcase/updater/update_source.dart';
import 'package:kakao_showcase/updater/updater.dart';

class _FakePlatform implements UpdatePlatform {
  _FakePlatform(this.release, {this.permissionFirst = false});

  final ReleaseInfo? release;
  bool permissionFirst;
  int checks = 0;
  final installs = <String>[];

  @override
  bool get supported => true;

  @override
  Future<ReleaseInfo?> latest(String url) async {
    checks++;
    return release;
  }

  @override
  Future<String> download(ReleaseInfo r, void Function(double) onProgress) async {
    onProgress(.5);
    onProgress(1);
    return '/cache/updates/kakao-showcase-${r.build}.apk';
  }

  @override
  Future<bool> install(String path) async {
    installs.add(path);
    if (permissionFirst) {
      permissionFirst = false;
      return false;
    }
    return true;
  }
}

const _r7 = ReleaseInfo(build: 7, commit: 'abc1234', message: 'Button: loading arc', apkUrl: 'https://x/a.apk');

Future<void> _pump(WidgetTester tester, _FakePlatform p, {int current = 5}) async {
  final nav = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: nav,
      builder: (_, child) => KakaoTheme(
        data: KakaoThemeData.light,
        child: Updater(navigatorKey: nav, platformOverride: p, currentBuild: current, child: child!),
      ),
      home: const SizedBox(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('offers a newer build on open and installs it', (tester) async {
    final p = _FakePlatform(_r7);
    await _pump(tester, p);
    expect(find.text('Update available'), findsOneWidget);
    expect(find.textContaining('Build 7 is out (you have 5)'), findsOneWidget);
    expect(find.textContaining('Button: loading arc'), findsOneWidget);

    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();
    expect(p.installs, ['/cache/updates/kakao-showcase-7.apk']);
    expect(find.textContaining('installer is open'), findsOneWidget);
  });

  testWidgets('says nothing when the build is current', (tester) async {
    final p = _FakePlatform(_r7);
    await _pump(tester, p, current: 7);
    expect(p.checks, 1);
    expect(find.text('Update available'), findsNothing);
  });

  testWidgets('local builds never check', (tester) async {
    final p = _FakePlatform(_r7);
    await _pump(tester, p, current: 0);
    expect(p.checks, 0);
  });

  testWidgets('asks for the install permission, then retries', (tester) async {
    final p = _FakePlatform(_r7, permissionFirst: true);
    await _pump(tester, p);
    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();
    expect(find.textContaining('needs your permission'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(p.installs.length, 2);
    expect(find.textContaining('installer is open'), findsOneWidget);
  });

  testWidgets('Later closes the offer', (tester) async {
    final p = _FakePlatform(_r7);
    await _pump(tester, p);
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(find.text('Update available'), findsNothing);
  });

  test('version.json parsing', () {
    expect(ReleaseInfo.fromJson({'build': 3, 'apk': 'u'})?.build, 3);
    expect(ReleaseInfo.fromJson({'build': '3'}), isNull);
    expect(ReleaseInfo.fromJson('nope'), isNull);
  });
}
