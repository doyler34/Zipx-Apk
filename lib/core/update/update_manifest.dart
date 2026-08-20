/// The remote "is there a newer build" manifest fetched from
/// [AppUpdateService]. Schema (hosted wherever the update is announced from -
/// see AppUpdateService's `_manifestUrl`):
/// ```json
/// {
///   "version": "1.2.0",
///   "android_url": "https://.../zipx-movies.apk",
///   "windows_url": "https://.../ZipX-Setup.exe",
///   "release_notes": ["Faster loading", "UI improvements", "Bug fixes"]
/// }
/// ```
class UpdateManifest {
  const UpdateManifest({
    required this.version,
    required this.androidUrl,
    required this.windowsUrl,
    required this.releaseNotes,
  });

  final String version;
  final String androidUrl;
  final String windowsUrl;
  final List<String> releaseNotes;

  factory UpdateManifest.fromJson(Map<String, dynamic> json) {
    return UpdateManifest(
      version: (json['version'] as String?)?.trim() ?? '',
      androidUrl: (json['android_url'] as String?)?.trim() ?? '',
      windowsUrl: (json['windows_url'] as String?)?.trim() ?? '',
      releaseNotes: (json['release_notes'] as List?)?.whereType<String>().toList() ?? const [],
    );
  }

  /// Hive can't store a plain `Map<String, dynamic>` reliably across restarts
  /// (dynamic-list quirks), so the cached copy is round-tripped through this
  /// simpler `Map<String, dynamic>` shape instead of re-using [fromJson].
  Map<String, dynamic> toMap() => {
        'version': version,
        'android_url': androidUrl,
        'windows_url': windowsUrl,
        'release_notes': releaseNotes,
      };

  factory UpdateManifest.fromMap(Map<dynamic, dynamic> map) {
    return UpdateManifest(
      version: map['version'] as String? ?? '',
      androidUrl: map['android_url'] as String? ?? '',
      windowsUrl: map['windows_url'] as String? ?? '',
      releaseNotes: (map['release_notes'] as List?)?.whereType<String>().toList() ?? const [],
    );
  }

  /// True when [version] is a newer release than [installedVersion]. Compares
  /// dot-separated numeric segments (e.g. "1.0.187" vs "1.2.0") rather than
  /// exact string equality, so it's correct regardless of which numbering
  /// scheme either side happens to use.
  bool isNewerThan(String installedVersion) => _compareVersions(version, installedVersion) > 0;

  static int _compareVersions(String a, String b) {
    final partsA = a.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final partsB = b.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final length = partsA.length > partsB.length ? partsA.length : partsB.length;
    for (var i = 0; i < length; i++) {
      final va = i < partsA.length ? partsA[i] : 0;
      final vb = i < partsB.length ? partsB[i] : 0;
      if (va != vb) return va.compareTo(vb);
    }
    return 0;
  }
}
