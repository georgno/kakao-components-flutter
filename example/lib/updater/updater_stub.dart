import 'update_source.dart';

UpdatePlatform createPlatform() => _Unsupported();

class _Unsupported implements UpdatePlatform {
  @override
  bool get supported => false;

  @override
  Future<ReleaseInfo?> latest(String url) async => null;

  @override
  Future<String> download(ReleaseInfo release, void Function(double) onProgress) =>
      throw UnsupportedError('Updates are Android only');

  @override
  Future<bool> install(String path) => throw UnsupportedError('Updates are Android only');
}
