import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../../common/styles/zipx_ui.dart';
import '../../../../../core/dependency_injection/di.dart';
import '../../../../../core/playback/domain/entities/download_item.dart';
import '../../../../../core/playback/domain/entities/player_args.dart';
import '../../../../../core/playback/services/downloads_service.dart';
import '../../../../../core/playback/services/stream_sources_service.dart';
import '../../../../../core/utils/strings/url_strings.dart';

/// Profile → Downloads: titles being prepared server-side (by ZipX). Not device
/// downloads. Polls active jobs (~10s) while open, restores + refreshes on open,
/// and lets the user play a ready item or retry/remove a failed one.
class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> with WidgetsBindingObserver {
  final DownloadsService _downloads = sl<DownloadsService>();
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Restore + refresh persisted active jobs, then poll while the screen is up.
    unawaited(_downloads.refreshActive());
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Don't poll in the background; resume (and refresh once) on return.
    if (state == AppLifecycleState.resumed) {
      unawaited(_downloads.refreshActive());
      _startPolling();
    } else {
      _stopPolling();
    }
  }

  void _startPolling() {
    _poll ??= Timer.periodic(const Duration(seconds: 10), (_) {
      // refreshActive only touches queued/downloading jobs - ready/failed are
      // never polled, and there's a single loop for the whole screen.
      unawaited(_downloads.refreshActive());
    });
  }

  void _stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZipxUi.bg,
      appBar: AppBar(
        backgroundColor: ZipxUi.bg,
        foregroundColor: Colors.white,
        title: const Text('Downloads'),
      ),
      body: ValueListenableBuilder<Box>(
        valueListenable: _downloads.listenable,
        builder: (context, _, __) {
          final items = _downloads.all();
          if (items.isEmpty) return _empty();
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, i) => _DownloadCard(
              item: items[i],
              onPlay: () => _play(items[i]),
              onRetry: () => _retry(items[i]),
              onRemove: () => _remove(items[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _empty() => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_download_outlined, color: Colors.white24, size: 48),
              SizedBox(height: 12),
              Text('Nothing preparing right now.',
                  style: TextStyle(color: Colors.white54), textAlign: TextAlign.center),
              SizedBox(height: 6),
              Text('Titles you prepare for playback show up here.',
                  style: TextStyle(color: Colors.white38, fontSize: 12), textAlign: TextAlign.center),
            ],
          ),
        ),
      );

  // Ready → play. Asks the backend to unrestrict the exact prepared file to a
  // fresh URL (plays instantly, no waiting on AIOStreams' cached view); if that
  // isn't available it hands the request to the normal player, which re-queries
  // current sources. No stale/stored URL is ever reused.
  Future<void> _play(DownloadItem item) async {
    if (item.status != DownloadStatus.ready) return;
    final url = await sl<StreamSourcesService>().preparedPlaybackUrl(item.jobId);
    if (!mounted) return;
    context.push('/player', extra: PlayerArgs(request: item.toPlaybackRequest(), primaryUrl: url));
  }

  Future<void> _retry(DownloadItem item) async {
    final result = await _downloads.retry(item.jobId);
    if (!mounted) return;
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't retry - please try again.")),
      );
    } else {
      _startPolling();
    }
  }

  Future<void> _remove(DownloadItem item) async {
    await _downloads.deleteJob(item.jobId);
  }
}

class _DownloadCard extends StatelessWidget {
  const _DownloadCard({
    required this.item,
    required this.onPlay,
    required this.onRetry,
    required this.onRemove,
  });

  final DownloadItem item;
  final VoidCallback onPlay;
  final VoidCallback onRetry;
  final VoidCallback onRemove;

  bool get _ready => item.status == DownloadStatus.ready;
  bool get _failed => item.status == DownloadStatus.failed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: ZipxUi.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: _ready ? onPlay : null,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _poster(),
                const SizedBox(width: 12),
                Expanded(child: _details(context)),
                if (_ready)
                  const Icon(Icons.play_circle_fill, color: ZipxUi.red, size: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _poster() {
    final path = (item.poster ?? '').replaceFirst(RegExp(r'^/'), '');
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 54,
        height: 80,
        child: path.isEmpty
            ? Container(color: ZipxUi.surfaceHigh, child: const Icon(Icons.movie, color: Colors.white24))
            : Image.network(
                '${UrlStrings.imageUrl}$path',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(color: ZipxUi.surfaceHigh, child: const Icon(Icons.movie, color: Colors.white24)),
              ),
      ),
    );
  }

  Widget _details(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
        if (item.episodeLabel != null) ...[
          const SizedBox(height: 2),
          Text(item.episodeLabel!, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
        const SizedBox(height: 6),
        _statusLine(),
        if (_failed) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              _smallButton('Retry', ZipxUi.red, onRetry),
              const SizedBox(width: 8),
              _smallButton('Remove', ZipxUi.surfaceHigh, onRemove),
            ],
          ),
        ],
      ],
    );
  }

  Widget _statusLine() {
    late final String text;
    late final Color color;
    switch (item.status) {
      case DownloadStatus.ready:
        text = 'Ready to Watch';
        color = const Color(0xFF4ADE80);
        break;
      case DownloadStatus.failed:
        text = 'Download failed';
        color = const Color(0xFFF87171);
        break;
      case DownloadStatus.downloading:
        // Real progress only; otherwise a plain state, never an invented number.
        text = item.progress != null ? 'Downloading — ${item.progress}%' : 'Downloading…';
        color = Colors.white70;
        break;
      case DownloadStatus.queued:
        text = 'Preparing…';
        color = Colors.white70;
        break;
    }
    final speed = (item.status == DownloadStatus.downloading && item.speed != null && item.speed! > 0)
        ? '  ·  ${_fmtSpeed(item.speed!)}'
        : '';
    return Row(
      children: [
        if (item.isActive) ...[
          const SizedBox(
            width: 12, height: 12,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text('$text$speed',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }

  String _fmtSpeed(int bytesPerSec) {
    final mb = bytesPerSec / (1024 * 1024);
    if (mb >= 1) return '${mb.toStringAsFixed(1)} MB/s';
    return '${(bytesPerSec / 1024).toStringAsFixed(0)} KB/s';
  }

  Widget _smallButton(String label, Color color, VoidCallback onTap) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}
