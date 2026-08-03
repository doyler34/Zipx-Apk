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

/// TEMPORARY test switch. When true, the native player does NOT silently hand
/// off to the WebView provider player if it finds no playable stream - it shows
/// a clear error instead, so you can tell whether native streaming actually
/// works (vs. always seeing the web player because of the hidden fallback).
/// Set back to false to restore the normal seamless fallback.
const bool kDisableWebFallback = false;

enum _Stage { loading, playing, fallback, error }

class _NativePlayerScreenState extends State<NativePlayerScreen> {
  final StreamSourcesService _service = sl<StreamSourcesService>();

  List<StreamSource> _sources = const [];
  int _index = 0;
  _Stage _stage = _Stage.loading;
  String _status = 'Finding streams…';
  String _error = '';
  bool _historyRecorded = false;

  /// Per-source failure reasons, shown on the error screen so we can see
  /// exactly why each stream wouldn't open (403, format, timeout, …).
  final List<String> _attemptLog = [];

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
    if (kDisableWebFallback) {
      // Testing mode: surface the native result instead of hiding it behind
      // the web player.
      setState(() {
        _stage = _Stage.error;
        _error = _sources.isEmpty
            ? 'Native streaming found NO playable source for this title.\n\n(This is expected for unreleased / very new titles. Web fallback is OFF for testing.)'
            : 'The backend returned ${_sources.length} native source(s), but none would open in the player.\n\n(Web fallback is OFF for testing.)';
      });
      return;
    }
    setState(() => _stage = _Stage.fallback);
  }

  /// Force the WebView provider player even when the fallback is disabled -
  /// so the error screen still gives a way to actually watch.
  void _forceWebPlayer() {
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
      // Many of these URLs don't end in .m3u8/.mp4 (they're proxied via
      // ?url= or worker links), so ExoPlayer can't infer the container -
      // tell it explicitly. And send a browser User-Agent when the backend
      // gave none, since some hosts 403 the default player agent.
      final headers = <String, String>{
        'User-Agent': 'Mozilla/5.0 (Linux; Android 11) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
        ...source.headers,
      };
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(source.url),
        httpHeaders: headers,
        formatHint: source.isHls ? VideoFormat.hls : VideoFormat.other,
      );
      _video = controller;
      // A dead/slow host can hang initialize() forever - cap it so we move on.
      await controller.initialize().timeout(const Duration(seconds: 15));
      if (controller.value.hasError) {
        throw controller.value.errorDescription ?? 'playback error';
      }
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
    } catch (e) {
      // This source didn't open - record why, then move to the next candidate.
      var reason = e.toString();
      if (reason.length > 160) reason = '${reason.substring(0, 160)}…';
      _attemptLog.add('${_label(source)} [${source.isHls ? 'hls' : 'mp4'}] → $reason');
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.request.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            // Unmistakable proof of which player you're looking at.
            if (_stage == _Stage.playing)
              Text(
                'NATIVE · ${_label(_sources[_index])}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF4ADE80), fontWeight: FontWeight.w600),
              )
            else if (_stage == _Stage.loading)
              const Text('NATIVE · searching…', style: TextStyle(fontSize: 11, color: Color(0xFF4ADE80))),
          ],
        ),
        actions: [
          if (_stage == _Stage.playing && _sources.length > 1)
            IconButton(
              tooltip: 'Sources',
              icon: const Icon(Icons.playlist_play),
              onPressed: _openSourcePicker,
            ),
        ],
      ),
      body: Center(child: _body()),
    );
  }

  Widget _body() {
    if (_stage == _Stage.playing && _chewie != null) {
      return Chewie(controller: _chewie!);
    }
    if (_stage == _Stage.error) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 8),
            const Icon(Icons.movie_filter_outlined, color: Colors.white54, size: 40),
            const SizedBox(height: 12),
            Text(_error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            if (_attemptLog.isNotEmpty) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Why each source failed:', style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                  child: SingleChildScrollView(
                    child: Text(
                      _attemptLog.join('\n\n'),
                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace', height: 1.4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            ElevatedButton.icon(
              onPressed: _forceWebPlayer,
              icon: const Icon(Icons.public),
              label: const Text('Use web player'),
            ),
          ],
        ),
      );
    }
    // loading
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(color: Color(0xFFE11D2A)),
        const SizedBox(height: 16),
        Text(_status, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}
