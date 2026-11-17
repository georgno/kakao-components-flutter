import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'update_source.dart';

UpdatePlatform createPlatform() => _AndroidUpdates();

/// Talks to MainActivity.kt over this channel.
const _channel = MethodChannel('kakao_showcase/updater');

class _AndroidUpdates implements UpdatePlatform {
  final _http = HttpClient()..connectionTimeout = const Duration(seconds: 10);

  @override
  bool get supported => Platform.isAndroid;

  @override
  Future<ReleaseInfo?> latest(String url) async {
    try {
      // Cache-busting query: GitHub's CDN may otherwise hand back an old file.
      final uri = Uri.parse(url).replace(queryParameters: {'t': '${DateTime.now().millisecondsSinceEpoch}'});
      final res = await (await _http.getUrl(uri)).close().timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        await res.drain<void>();
        return null;
      }
      return ReleaseInfo.fromJson(jsonDecode(await res.transform(utf8.decoder).join()));
    } on Object {
      return null; // Offline or unreachable: try again next time.
    }
  }

  @override
  Future<String> download(ReleaseInfo release, void Function(double) onProgress) async {
    final cache = await _channel.invokeMethod<String>('cacheDir');
    final dir = Directory('$cache/updates')..createSync(recursive: true);
    final file = File('${dir.path}/kakao-showcase-${release.build}.apk');
    final done = File('${file.path}.done');
    if (file.existsSync() && done.existsSync()) {
      onProgress(1);
      return file.path;
    }
    // Drop older downloads.
    for (final f in dir.listSync()) {
      f.deleteSync();
    }
    final res = await (await _http.getUrl(Uri.parse(release.apkUrl))).close();
    if (res.statusCode != 200) throw HttpException('Download failed (${res.statusCode})');
    final total = res.contentLength;
    var got = 0;
    final sink = file.openWrite();
    await for (final chunk in res) {
      sink.add(chunk);
      got += chunk.length;
      if (total > 0) onProgress(got / total);
    }
    await sink.close();
    done.createSync();
    onProgress(1);
    return file.path;
  }

  @override
  Future<bool> install(String path) async =>
      await _channel.invokeMethod<String>('install', {'path': path}) == 'started';
}
