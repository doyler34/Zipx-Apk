import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../../dependency_injection/di.dart';
import '../../domain/entities/playback_request.dart';
import '../../domain/entities/stream_source.dart';
import '../../services/playback_history_service.dart';
import '../../services/playback_provider_service.dart';
import '../../services/stream_sources_service.dart';
import 'player_screen.dart';

/// The primary "Watch Now" screen: fetches direct streams from the sources
/// backend and plays them in a native, ad-free player.
///
/// Resilience is built in:
///  - each source is tried in turn; one that fails to open auto-advances to
///    the next,
///  - if the backend returns nothing (or is unreachable), it falls back to the
///    existing WebView provider player ([PlayerScreen]) so playback still
///    works.
class NativePlayerScreen extends StatefulWidget {
  const NativePlayerScreen({super.key, required this.request});

  final PlaybackRequest request;

  @override
  State<NativePlayerScreen> createState() => _NativePlayerScreenState();
}

enum _Stage { loading, playing, fallback }

class _NativePlayerScreenState extends State<NativePlayerScreen> {
  final StreamSourcesService _service = sl<StreamSourcesService>();

  List<StreamSource> _sources = const [];
  int _index = 0;
  _Stage _stage = _Stage.loading;
  String _status = 'Finding streams…';
  bool _historyRecorded = false;

  VideoPlayerController? _video;
  ChewieController? _chewie;

  @override
  void initState() {
    super.initState();
    // Allow landscape so the native player can rotate to fullscreen.
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _load();
  }

  @override
  void dispose() {
    _disposeControllers();
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _disposeControllers() async {
    final chewie = _chewie;
    final video = _video;
    _chewie = null;
    _video = null;
    // ChewieController.dispose() also disposes its VideoPlayerController, so
    // only dispose the video ourselves when no Chewie was created (e.g. the
    // source failed to initialise before we wrapped it).
    if (chewie != null) {
      chewie.dispose();
    } else {
      await video?.dispose();
    }
  }

  Future<void> _load() async {
    try {
      final sources = await _service.fetch(widget.request);
      if (!mounted) return;
      if (sources.isEmpty) {
        _goFallback();
        return;
      }
      _sources = sources;
      await _playIndex(0);
    } catch (_) {
      // Backend unreachable / errored - use the WebView providers instead.
      if (mounted) _goFallback();
    }
  }

  void _goFallback() {
    if (!mounted) return;
    setState(() => _stage = _Stage.fallback);
  }

  Future<void> _playIndex(int index) async {
    if (index < 0 || index >= _sources.length) {
      _goFallback();
      return;
    }
    setState(() {
      _stage = _Stage.loading;
      _index = index;
      _status = 'Loading ${_label(_sources[index])}…';
    });
    await _disposeControllers();

    final source = _sources[index];
    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(source.url),
        httpHeaders: source.headers,
      );
      _video = controller;
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      final aspect = controller.value.aspectRatio;
      _chewie = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        aspectRatio: (aspect.isFinite && aspect > 0) ? aspect : 16 / 9,
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFFE11D2A),
          handleColor: const Color(0xFFE11D2A),
          bufferedColor: Colors.white24,
          backgroundColor: Colors.white10,
        ),
        // A source that "opens" but then errors mid-load: offer the next one.
        errorBuilder: (context, message) => _playbackError(message),
      );
      _recordHistoryOnce(source);
      setState(() => _stage = _Stage.playing);
    } catch (_) {
      // This source didn't open - move straight to the next candidate.
      await _tryNext();
    }
  }

  Future<void> _tryNext() async {
    if (_index + 1 < _sources.length) {
      await _playIndex(_index + 1);
    } else {
      _goFallback();
    }
  }

  void _recordHistoryOnce(StreamSource source) {
    if (_historyRecorded) return;
    _historyRecorded = true;
    sl<PlaybackHistoryService>().recordPlaybackStarted(
      request: widget.request,
      providerId: 'native:${source.provider}',
    );
  }

  String _label(StreamSource s) {
    final q = s.quality.trim();
    final provider = s.provider.trim();
    if (q.isNotEmpty && q.toLowerCase() != 'auto') return '$provider · $q';
    return provider.isEmpty ? s.title : provider;
  }

  Future<void> _openSourcePicker() async {
    final chosen = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xFF16161B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Sources', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _sources.length,
                itemBuilder: (context, i) {
                  final s = _sources[i];
                  final selected = i == _index;
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      s.isHls ? Icons.hd_outlined : Icons.play_circle_outline,
                      color: selected ? const Color(0xFFE11D2A) : Colors.white54,
                    ),
                    title: Text(_label(s), style: const TextStyle(color: Colors.white)),
                    subtitle: Text(s.isHls ? 'HLS' : 'MP4', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    trailing: selected ? const Icon(Icons.check, color: Color(0xFFE11D2A)) : null,
                    onTap: () => Navigator.of(context).pop(i),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (chosen != null && chosen != _index) {
      await _playIndex(chosen);
    }
  }

  Widget _playbackError(String message) {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.white54, size: 40),
          const SizedBox(height: 12),
          Text(
            _index + 1 < _sources.length ? 'This source failed to play.' : 'No more sources to try.',
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            children: [
              if (_index + 1 < _sources.length)
                ElevatedButton.icon(
                  onPressed: _tryNext,
                  icon: const Icon(Icons.skip_next),
                  label: const Text('Next source'),
                ),
              OutlinedButton.icon(
                onPressed: _goFallback,
                icon: const Icon(Icons.public),
                label: const Text('Web player'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Seamless fallback: render the existing WebView provider player.
    if (_stage == _Stage.fallback) {
      return PlayerScreen(
        request: widget.request,
        playbackProviderService: sl<PlaybackProviderService>(),
        historyService: sl<PlaybackHistoryService>(),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.request.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (_stage == _Stage.playing && _sources.length > 1)
            IconButton(
              tooltip: 'Sources',
              icon: const Icon(Icons.playlist_play),
              onPressed: _openSourcePicker,
            ),
        ],
      ),
      body: Center(
        child: (_stage == _Stage.playing && _chewie != null)
            ? Chewie(controller: _chewie!)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Color(0xFFE11D2A)),
                  const SizedBox(height: 16),
                  Text(_status, style: const TextStyle(color: Colors.white70)),
                ],
              ),
      ),
    );
  }
}
