import 'dart:async';

import 'package:dio/dio.dart';

/// Progress of a "prepare episode" (cache an uncached torrent on Real-Debrid).
class RdPrepareProgress {
  const RdPrepareProgress(this.status, this.percent);

  /// Human status: "Adding…", "Downloading…", "Ready", "Failed".
  final String status;

  /// 0–100 (RD download progress), or null when not downloading yet.
  final int? percent;
}

/// Talks to the Real-Debrid API to cache an uncached torrent on demand and hand
/// back a directly-playable link - the "prepare this episode" flow.
///
/// The RD token is injected at build time (`--dart-define=REAL_DEBRID_TOKEN`),
/// so it isn't committed. Only used for the opt-in prepare action; normal
/// playback never touches this (it only ever plays already-cached streams).
class RealDebridService {
  RealDebridService(this._dio);

  final Dio _dio;

  static const String _token = String.fromEnvironment('REAL_DEBRID_TOKEN');
  static const String _base = 'https://api.real-debrid.com/rest/1.0';

  bool get isConfigured => _token.isNotEmpty;

  Options get _opts => Options(headers: {'Authorization': 'Bearer $_token'});

  /// Adds the torrent, selects just the wanted episode file, waits for RD to
  /// cache it, and returns a playable link. Reports progress via [onProgress].
  /// Returns null on failure/timeout. [episode] picks the right file out of a
  /// multi-episode batch; null selects all files (single-file torrents).
  Future<String?> prepare(
    String infohash, {
    int? episode,
    void Function(RdPrepareProgress)? onProgress,
    Duration timeout = const Duration(minutes: 6),
  }) async {
    if (!isConfigured || infohash.isEmpty) return null;
    final deadline = DateTime.now().add(timeout);
    try {
      onProgress?.call(const RdPrepareProgress('Adding torrent…', null));
      final magnet = 'magnet:?xt=urn:btih:$infohash';
      final add = await _dio.post(
        '$_base/torrents/addMagnet',
        data: {'magnet': magnet},
        options: _opts.copyWith(contentType: Headers.formUrlEncodedContentType),
      );
      final id = (add.data is Map ? add.data['id'] : null)?.toString();
      if (id == null || id.isEmpty) return null;

      // Get the file list, pick the episode file (or all), then select it.
      final info0 = await _info(id);
      final files = (info0?['files'] as List?) ?? const [];
      final fileId = _pickFile(files, episode);
      onProgress?.call(const RdPrepareProgress('Preparing…', null));
      await _dio.post(
        '$_base/torrents/selectFiles/$id',
        data: {'files': fileId ?? 'all'},
        options: _opts.copyWith(contentType: Headers.formUrlEncodedContentType),
      );

      // Poll until RD has it cached ("downloaded"), reporting progress.
      while (DateTime.now().isBefore(deadline)) {
        final info = await _info(id);
        final status = (info?['status'] ?? '').toString();
        final progress = info?['progress'];
        final pct = progress is num ? progress.toInt() : null;
        if (status == 'downloaded') {
          final links = (info?['links'] as List?)?.whereType<String>().toList() ?? const [];
          if (links.isEmpty) return null;
          onProgress?.call(const RdPrepareProgress('Ready', 100));
          return await _unrestrict(links.first);
        }
        if (status == 'error' || status == 'magnet_error' || status == 'virus' || status == 'dead') {
          onProgress?.call(const RdPrepareProgress('Failed', null));
          return null;
        }
        onProgress?.call(RdPrepareProgress('Downloading…', pct));
        await Future.delayed(const Duration(seconds: 4));
      }
      return null; // timed out
    } catch (_) {
      return null;
    }
  }

  Future<Map?> _info(String id) async {
    try {
      final r = await _dio.get('$_base/torrents/info/$id', options: _opts);
      return r.data is Map ? r.data as Map : null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _unrestrict(String link) async {
    try {
      final r = await _dio.post(
        '$_base/unrestrict/link',
        data: {'link': link},
        options: _opts.copyWith(contentType: Headers.formUrlEncodedContentType),
      );
      final url = r.data is Map ? r.data['download'] : null;
      return url?.toString();
    } catch (_) {
      return null;
    }
  }

  /// Chooses the file id for [episode] out of a torrent's file list, matching
  /// the episode number in the filename (E33 / " 33 " / "- 33"). Falls back to
  /// the single/largest video file. Returns null to select all.
  String? _pickFile(List files, int? episode) {
    final videos = files.where((f) => f is Map && _isVideo((f['path'] ?? '').toString())).cast<Map>().toList();
    if (videos.isEmpty) return null;
    if (videos.length == 1) return videos.first['id']?.toString();

    if (episode != null) {
      final ep = episode.toString();
      final epPad = episode.toString().padLeft(2, '0');
      for (final f in videos) {
        final name = (f['path'] ?? '').toString().toLowerCase();
        if (RegExp('(?:e|ep|episode|[ _.-])0*$ep(?:[ _.\\-\\]v]|\$)').hasMatch(name) ||
            name.contains('e$epPad')) {
          return f['id']?.toString();
        }
      }
    }
    // Fallback: the largest video file.
    videos.sort((a, b) => ((b['bytes'] ?? 0) as num).compareTo((a['bytes'] ?? 0) as num));
    return videos.first['id']?.toString();
  }

  bool _isVideo(String path) {
    final p = path.toLowerCase();
    return p.endsWith('.mkv') || p.endsWith('.mp4') || p.endsWith('.avi') || p.endsWith('.m4v') || p.endsWith('.ts');
  }
}
