import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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

    // A fresh-enough cache is shown as-is; only hit the network when there's
    // nothing cached yet or it's gone stale - keeps this "lightweight".
    if (_manifest != null && !_service.isCacheStale) {
      setState(() => _hasCheckedOnce = true);
      return;
    }
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

  Future<void> _download(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      // Handing off to the OS browser/download manager rather than
      // downloading in-app: on Android that lands in Downloads and offers to
      // open it (the normal package installer) with no extra permissions;
      // on Windows the installer's stable AppId (installer/zipx.iss) already
      // updates the existing install in place once the user runs it.
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) HelperFunctions.showSnackBar(context, 'Could not open the download link.');
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
            else if (_hasCheckedOnce)
              const Text('Unable to check for updates.', style: TextStyle(color: ZipxUi.textMuted, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
