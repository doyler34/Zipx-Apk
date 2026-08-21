import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'update_manifest.dart';

/// Optional, user-initiated update check for Profile -> App Updates. Never
/// runs at startup and never blocks/pops anything on its own - it only does
/// work when [checkForUpdate] is called (from the App Updates section), and
/// that call is itself fail-open: any network/parse error just returns null
/// so the UI falls back to the last cached result or "unable to check".
class AppUpdateService {
  AppUpdateService(this._dio);

  final Dio _dio;

  /// Where the manifest lives. Defaults to a JSON file attached to the same
  /// "latest" GitHub Release the APK already ships from (see
  /// .github/workflows/build-apk.yml) - no separate hosting needed. Override
  /// at build time with `--dart-define=UPDATE_MANIFEST_URL=...` to point at
  /// different infrastructure (e.g. your own VPS) without a code change.
  static const String _manifestUrl = String.fromEnvironment(
    'UPDATE_MANIFEST_URL',
    defaultValue: 'https://github.com/doyler34/zipx-apk/releases/download/latest/update-manifest.json',
  );

  static const String _boxName = 'app_update';

  /// A check made within this long of the last one just reuses the cache
  /// instead of hitting the network again - "lightweight" per the spec.
  static const Duration _cacheTtl = Duration(hours: 6);

  /// The manifest URL this exact build was compiled with - shown in the UI
  /// so it's obvious whether a build is actually pointed at the VPS or still
  /// on the GitHub default, without having to guess from behaviour alone.
  String get manifestUrl => _manifestUrl;

  /// The last checkForUpdate() failure, if any (e.g. "404", a timeout, a
  /// parse error) - shown in the UI instead of being silently swallowed, so
  /// a real failure reason is visible instead of just "unable to check".
  String? lastError;

  Box get _box => Hive.box(_boxName);

  Future<String> currentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  /// The last successfully fetched manifest, if any - shown immediately so
  /// the section never has to sit on a spinner while a fresh check runs.
  UpdateManifest? cachedManifest() {
    final raw = _box.get('manifest');
    if (raw is! Map) return null;
    try {
      return UpdateManifest.fromMap(raw);
    } catch (_) {
      return null;
    }
  }

  bool get isCacheStale {
    final ts = _box.get('checkedAt');
    if (ts is! int) return true;
    return DateTime.now().millisecondsSinceEpoch - ts > _cacheTtl.inMilliseconds;
  }

  /// Fetches and caches the remote manifest. Returns null on any failure
  /// (network down, bad JSON, timeout) - callers should fall back to
  /// [cachedManifest] rather than surface this as an error dialog.
  Future<UpdateManifest?> checkForUpdate() async {
    lastError = null;
    try {
      // A cache-busting query param defeats any browser/CDN/proxy cache
      // sitting between the phone and wherever the manifest is hosted -
      // otherwise an edited file on the server can keep serving a stale
      // cached response indefinitely regardless of what's actually on disk.
      final bustUrl = '$_manifestUrl?t=${DateTime.now().millisecondsSinceEpoch}';
      final response = await _dio.get(
        bustUrl,
        options: Options(
          sendTimeout: const Duration(seconds: 6),
          receiveTimeout: const Duration(seconds: 6),
          headers: const {'Cache-Control': 'no-cache'},
        ),
      );
      final data = response.data;
      final json = data is String ? jsonDecode(data) : data;
      if (json is! Map) {
        lastError = 'Response was not JSON (status ${response.statusCode})';
        return null;
      }
      final manifest = UpdateManifest.fromJson(json.cast<String, dynamic>());
      if (manifest.version.isEmpty) {
        lastError = 'Manifest JSON had no "version" field';
        return null;
      }
      await _box.put('manifest', manifest.toMap());
      await _box.put('checkedAt', DateTime.now().millisecondsSinceEpoch);
      return manifest;
    } on DioException catch (e) {
      lastError = '${e.type.name}${e.response != null ? ' (HTTP ${e.response!.statusCode})' : ''}: ${e.message}';
      return null;
    } catch (e) {
      lastError = e.toString();
      return null;
    }
  }

  /// Downloads [url] into the app's cache dir (overwriting any previous
  /// download there) and reports progress via [onProgress] - both the
  /// 0.0-1.0 fraction (or -1 when the server doesn't send a content-length)
  /// and the raw byte counts, so the UI can show "42.3 MB / 68.1 MB".
  /// Returns the local file path on success, so the caller can hand it to
  /// the OS installer/opener.
  Future<String> downloadUpdate({
    required String url,
    required void Function(double progress, int received, int total) onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final fileName = Uri.parse(url).pathSegments.isNotEmpty ? Uri.parse(url).pathSegments.last : 'zipx-update';
    final savePath = '${dir.path}/$fileName';
    // Drop a stale partial/previous download before starting a fresh one.
    final existing = File(savePath);
    if (await existing.exists()) await existing.delete();

    await _dio.download(
      url,
      savePath,
      onReceiveProgress: (received, total) {
        onProgress(total > 0 ? received / total : -1, received, total);
      },
    );
    return savePath;
  }
}
