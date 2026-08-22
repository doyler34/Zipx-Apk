import 'dart:io' show Platform;

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../../common/styles/zipx_ui.dart';
import '../../../../../core/dependency_injection/di.dart';
import '../../../../../core/update/app_update_service.dart';
import '../../../../../core/update/update_manifest.dart';
import '../../../../../core/utils/helpers/helper_functions.dart';

/// Profile -> App Updates. Entirely opt-in: the check only ever runs because
/// this section built (never at app startup), it's cached so revisiting the
/// tab doesn't re-hit the network every time, and a failure just falls back
/// to the last known state instead of an error dialog. There is no forced
/// popup and no automatic download/install anywhere in this widget - the
/// user has to tap "Download Update" themselves.
class AppUpdatesTile extends StatefulWidget {
  const AppUpdatesTile({super.key});

  @override
  State<AppUpdatesTile> createState() => _AppUpdatesTileState();
}

class _AppUpdatesTileState extends State<AppUpdatesTile> {
  final _service = sl<AppUpdateService>();

  String? _currentVersion;
  UpdateManifest? _manifest;
  bool _checking = false;
  bool _hasCheckedOnce = false;
  bool _downloading = false;
  double _downloadProgress = 0;
  int _downloadedBytes = 0;
  int _totalBytes = 0;

  @override
  void initState() {
    super.initState();
    _manifest = _service.cachedManifest();
    _load();
  }

  Future<void> _load() async {
    final version = await _service.currentVersion();
    if (!mounted) return;
    setState(() => _currentVersion = version);

    // Any cached manifest is shown immediately (set in initState) so this
    // never flashes blank, but every visit to this section still checks
    // fresh - no manual refresh control, just always up to date on open.
    setState(() => _checking = true);
    final fresh = await _service.checkForUpdate();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _hasCheckedOnce = true;
      if (fresh != null) _manifest = fresh;
    });
  }

  String _downloadUrlFor(UpdateManifest manifest) {
    if (kIsWeb) return '';
    if (Platform.isAndroid) return manifest.androidUrl;
    if (Platform.isWindows) return manifest.windowsUrl;
    return '';
  }

  String _formatMb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

  Future<void> _download(String url) async {
    setState(() {
      _downloading = true;
      _downloadProgress = 0;
      _downloadedBytes = 0;
      _totalBytes = 0;
    });
    try {
      // Downloaded straight into the app (no browser hand-off), then handed
      // to the OS installer/opener: on Android that's the normal package
      // installer (updates the existing install in place, same applicationId);
      // on Windows it runs the installer, which uses a stable AppId
      // (installer/zipx.iss) so it also updates in place.
      final path = await _service.downloadUpdate(
        url: url,
        onProgress: (p, received, total) {
          if (mounted) {
            setState(() {
              _downloadProgress = p;
              _downloadedBytes = received;
              _totalBytes = total;
            });
          }
        },
      );
      if (!mounted) return;
      setState(() => _downloading = false);
      final result = await OpenFile.open(path);
      if (result.type == ResultType.permissionDenied && mounted) {
        // Android blocks installing an APK from this app until the user
        // flips "Allow from this source" for it once, in Settings. Send
        // them straight to that exact screen instead of a dead-end error -
        // after enabling it, tapping Download Update again just works.
        HelperFunctions.showSnackBar(
          context,
          'Enable "Allow from this source" for Zipx Movies, then tap Download Update again.',
        );
        await _openInstallPermissionSettings();
      } else if (result.type != ResultType.done && mounted) {
        HelperFunctions.showSnackBar(context, 'Could not open installer: ${result.type} - ${result.message}');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _downloading = false);
        HelperFunctions.showSnackBar(context, 'Download failed - please try again.');
      }
    }
  }

  Future<void> _openInstallPermissionSettings() async {
    if (!Platform.isAndroid) return;
    try {
      final info = await PackageInfo.fromPlatform();
      final intent = AndroidIntent(
        action: 'android.settings.MANAGE_UNKNOWN_APP_SOURCES',
        data: 'package:${info.packageName}',
      );
      await intent.launch();
    } catch (_) {
      // Older Android versions don't have this exact screen - the snackbar
      // message alone still points the user to Settings manually.
    }
  }

  @override
  Widget build(BuildContext context) {
    final version = _currentVersion;
    final manifest = _manifest;
    final updateAvailable = manifest != null && version != null && manifest.isNewerThan(version);
    final downloadUrl = manifest != null ? _downloadUrlFor(manifest) : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: ZipxUi.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.system_update_alt_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Text(
                  'App Updates',
                  style: Theme.of(context).textTheme.titleSmall!.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Current version: ${version ?? '...'}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            if (manifest != null) ...[
              const SizedBox(height: 2),
              Text('Latest version: ${manifest.version}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
            const SizedBox(height: 12),
            if (!_hasCheckedOnce && _checking)
              const Text('Checking for updates...', style: TextStyle(color: ZipxUi.textMuted, fontSize: 13))
            else if (updateAvailable) ...[
              const Text('Update available', style: TextStyle(color: ZipxUi.red, fontWeight: FontWeight.bold, fontSize: 14)),
              if (manifest!.releaseNotes.isNotEmpty) ...[
                const SizedBox(height: 6),
                for (final note in manifest.releaseNotes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text('•  $note', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ),
              ],
              const SizedBox(height: 12),
              if (_downloading) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _downloadProgress >= 0 ? _downloadProgress : null,
                    minHeight: 8,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation(ZipxUi.red),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _totalBytes > 0
                      ? '${_formatMb(_downloadedBytes)} MB / ${_formatMb(_totalBytes)} MB (${(_downloadProgress * 100).round()}%)'
                      : 'Downloading...',
                  style: const TextStyle(color: ZipxUi.textMuted, fontSize: 12),
                ),
              ] else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: downloadUrl.isEmpty ? null : () => _download(downloadUrl),
                    style: ElevatedButton.styleFrom(backgroundColor: ZipxUi.red),
                    child: const Text('Download Update', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
            ] else if (manifest != null)
              const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 18),
                  SizedBox(width: 6),
                  Text("You're running the latest version", style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              )
            else if (_hasCheckedOnce) ...[
              const Text('Unable to check for updates.', style: TextStyle(color: ZipxUi.textMuted, fontSize: 13)),
              if (_service.lastError != null) ...[
                const SizedBox(height: 4),
                Text(_service.lastError!, style: const TextStyle(color: ZipxUi.textMuted, fontSize: 11)),
              ],
            ],
            const SizedBox(height: 10),
            Text(
              'Checking: ${_service.manifestUrl}',
              style: const TextStyle(color: Colors.white24, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
