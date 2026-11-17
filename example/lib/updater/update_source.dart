/// What `version.json` on the rolling debug release says.
class ReleaseInfo {
  const ReleaseInfo({required this.build, required this.commit, required this.message, required this.apkUrl});

  final int build;
  final String commit;
  final String message;
  final String apkUrl;

  static ReleaseInfo? fromJson(Object? json) {
    if (json is! Map) return null;
    final build = json['build'];
    final apk = json['apk'];
    if (build is! int || apk is! String) return null;
    return ReleaseInfo(
      build: build,
      commit: (json['commit'] as String?) ?? '',
      message: (json['message'] as String?) ?? '',
      apkUrl: apk,
    );
  }
}

/// Platform side of the updater: Android downloads and installs, every other
/// platform does nothing (see updater_io.dart / updater_stub.dart).
abstract class UpdatePlatform {
  bool get supported;

  /// The newest release, or null when it can't be read (offline, repo private…).
  Future<ReleaseInfo?> latest(String url);

  /// Downloads the APK (reusing a finished earlier download), reporting 0..1.
  Future<String> download(ReleaseInfo release, void Function(double progress) onProgress);

  /// Hands the APK to Android's installer. Returns false when Android first
  /// needs the "install unknown apps" permission (its settings page is opened).
  Future<bool> install(String path);
}
