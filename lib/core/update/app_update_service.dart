import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
    try {
      final response = await _dio.get(
        _manifestUrl,
        options: Options(
          sendTimeout: const Duration(seconds: 6),
          receiveTimeout: const Duration(seconds: 6),
        ),
      );
      final data = response.data;
      final json = data is String ? jsonDecode(data) : data;
      if (json is! Map) return null;
      final manifest = UpdateManifest.fromJson(json.cast<String, dynamic>());
      if (manifest.version.isEmpty) return null;
      await _box.put('manifest', manifest.toMap());
      await _box.put('checkedAt', DateTime.now().millisecondsSinceEpoch);
      return manifest;
    } catch (_) {
      return null;
    }
  }
}
