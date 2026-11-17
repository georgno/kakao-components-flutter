/// What CI baked into this build (`--dart-define`). A local `flutter run`
/// has build 0, which never offers or takes updates.
class BuildInfo {
  static const int number = int.fromEnvironment('BUILD_NUMBER');
  static const String commit = String.fromEnvironment('COMMIT', defaultValue: 'local');

  /// Where CI publishes the newest build's description (see
  /// .github/workflows/showcase.yml). The repo must be public for this to load.
  static const String updateUrl = String.fromEnvironment(
    'UPDATE_URL',
    defaultValue: 'https://github.com/georgno/kakao-components-flutter/releases/download/debug/version.json',
  );

  static bool get isCiBuild => number > 0;
  static String get label => isCiBuild ? 'Build $number · $commit' : 'Local build';
}
