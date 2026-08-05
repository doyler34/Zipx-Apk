import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../dependency_injection/di.dart';
import '../../domain/entities/playback_request.dart';
import '../../domain/entities/stream_source.dart';
import '../../services/playback_history_service.dart';
import '../../services/playback_provider_service.dart';
import '../../services/stream_sources_service.dart';
import 'player_screen.dart';

/// The primary "Watch Now" screen: fetches direct streams from the sources
/// backend and plays them in a native, ad-free player (media_kit / mpv), with a
/// real settings menu - embedded subtitle + audio track selection and speed.
///
/// Resilience is built in:
///  - each source is tried in turn; one that fails to open auto-advances,
///  - files far too short to be the real title (samples/trailers) are skipped,
///  - if the backend returns nothing (or is unreachable) it falls back to the
///    WebView provider player ([PlayerScreen]) so playback still works.
class NativePlayerScreen extends StatefulWidget {
  const NativePlayerScreen({super.key, required this.request});

  final PlaybackRequest request;

  @override
  State<NativePlayerScreen> createState() => _NativePlayerScreenState();
}

/// When true the native player shows a clear error instead of silently handing
/// off to the WebView player - useful for testing. Normally false.
const bool kDisableWebFallback = false;

const String _userAgent =
    'Mozilla/5.0 (Linux; Android 11) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';

enum _Stage { loading, playing, fallback, error }

class _NativePlayerScreenState extends State<NativePlayerScreen> with WidgetsBindingObserver {
  final StreamSourcesService _service = sl<StreamSourcesService>();

  final Player _player = Player();
  // Created eagerly in initState (NOT lazily): the video output must be
  // attached to the player before the first open(), otherwise you get audio
  // with a blank video surface.
  late final VideoController _videoController;

  List<StreamSource> _sources = const [];
  int _index = 0;
  int _attemptToken = 0;
  _Stage _stage = _Stage.loading;
  String _status = 'Finding streams…';
  String _error = '';
  bool _historyRecorded = false;

  /// Real runtime (minutes) from TMDB, used to reject sample/trailer/junk files.
  int? _expectedRuntimeMin;

  /// Per-source failure reasons, shown on the error screen.
  final List<String> _attemptLog = [];

  @override
  void initState() {
    super.initState();
    _videoController = VideoController(_player);
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _player.dispose(); // stops playback + releases mpv
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // No background playback: pause whenever the app leaves the foreground.
    if (state != AppLifecycleState.resumed) {
      _player.pause();
    }
  }

  Future<void> _load() async {
    try {
      // Runtime in parallel with the sources (only needed later, at play time).
      final runtimeFuture = _service.expectedRuntimeMinutes(widget.request);
      final sources = await _service.fetch(widget.request);
      _expectedRuntimeMin = await runtimeFuture;
      if (!mounted) return;
      if (sources.isEmpty) {
        _goFallback();
        return;
      }
      _sources = sources;
      await _playIndex(0);
    } catch (_) {
      if (mounted) _goFallback();
    }
  }

  void _goFallback() {
    if (!mounted) return;
    if (kDisableWebFallback) {
      setState(() {
        _stage = _Stage.error;
        _error = _sources.isEmpty
            ? 'Native streaming found NO playable source for this title.\n\n(Expected for unreleased / very new titles. Web fallback is OFF for testing.)'
            : 'The backend returned ${_sources.length} native source(s), but none would open.\n\n(Web fallback is OFF for testing.)';
      });
      return;
    }
    setState(() => _stage = _Stage.fallback);
  }

  void _forceWebPlayer() {
    if (!mounted) return;
    setState(() => _stage = _Stage.fallback);
  }

  Future<void> _playIndex(int index) async {
    if (index < 0 || index >= _sources.length) {
      _goFallback();
      return;
    }
    final token = ++_attemptToken;
    setState(() {
      _stage = _Stage.loading;
      _index = index;
      _status = 'Loading ${_label(_sources[index])}…';
    });

    final source = _sources[index];
    try {
      final headers = <String, String>{'User-Agent': _userAgent, ...source.headers};
      await _player.open(Media(source.url, httpHeaders: headers), play: true);

      // Consider the source good once a real duration is known; bail on an
      // error event or a timeout (dead/slow host).
      final ok = await Future.any(<Future<bool>>[
        _player.stream.duration.firstWhere((d) => d > Duration.zero).then((_) => true),
        _player.stream.error.first.then((_) => false),
      ]).timeout(const Duration(seconds: 20), onTimeout: () => false);
      if (token != _attemptToken || !mounted) return;

      if (!ok) {
        _attemptLog.add('${_label(source)} → failed to open (error / timeout)');
        await _tryNext();
        return;
      }

      // Reject samples/trailers: compare the loaded duration to the title's
      // real runtime. A 24-min file for a 142-min movie is a sample.
      final duration = _player.state.duration;
      final minReal = _minAcceptableDuration();
      if (duration > Duration.zero && duration < minReal) {
        _attemptLog.add('${_label(source)} → ${duration.inMinutes}m (need ≥${minReal.inMinutes}m) - sample/trailer, skipped');
        await _tryNext();
        return;
      }

      _recordHistoryOnce(source);
      setState(() => _stage = _Stage.playing);
    } catch (e) {
      if (token != _attemptToken) return;
      var reason = e.toString();
      if (reason.length > 160) reason = '${reason.substring(0, 160)}…';
      _attemptLog.add('${_label(source)} → $reason');
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

  Duration _minAcceptableDuration() {
    final runtime = _expectedRuntimeMin;
    if (runtime != null && runtime > 0) {
      return Duration(minutes: (runtime * 0.6).round());
    }
    return widget.request.isTvEpisode ? const Duration(minutes: 8) : const Duration(minutes: 45);
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

  // --- settings menus (subtitles / audio / speed / sources) -----------------

  Future<void> _pickFromSheet(String title, List<_Choice> choices) async {
    final chosen = await showModalBottomSheet<VoidCallback>(
      context: context,
      backgroundColor: const Color(0xFF16161B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: choices.length,
                itemBuilder: (context, i) {
                  final c = choices[i];
                  return ListTile(
                    dense: true,
                    title: Text(c.label, style: const TextStyle(color: Colors.white)),
                    trailing: c.selected ? const Icon(Icons.check, color: Color(0xFFE11D2A)) : null,
                    onTap: () => Navigator.of(context).pop(c.onSelect),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    chosen?.call();
  }

  void _openSubtitles() {
    final subs = _player.state.tracks.subtitle;
    final cur = _player.state.track.subtitle;
    _pickFromSheet('Subtitles', [
      for (final t in subs) _Choice(_subLabel(t), t.id == cur.id, () => _player.setSubtitleTrack(t)),
    ]);
  }

  void _openAudio() {
    final audios = _player.state.tracks.audio;
    final cur = _player.state.track.audio;
    _pickFromSheet('Audio', [
      for (final t in audios) _Choice(_audioLabel(t), t.id == cur.id, () => _player.setAudioTrack(t)),
    ]);
  }

  void _openSpeed() {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    final cur = _player.state.rate;
    _pickFromSheet('Playback speed', [
      for (final s in speeds) _Choice('${s}x', (s - cur).abs() < 0.01, () => _player.setRate(s)),
    ]);
  }

  String _subLabel(SubtitleTrack t) {
    if (t.id == 'no') return 'Off';
    if (t.id == 'auto') return 'Auto';
    return _trackName(t.title, t.language) ?? 'Subtitle ${t.id}';
  }

  String _audioLabel(AudioTrack t) {
    if (t.id == 'no') return 'Off';
    if (t.id == 'auto') return 'Auto';
    return _trackName(t.title, t.language) ?? 'Audio ${t.id}';
  }

  String? _trackName(String? title, String? language) {
    final parts = [title, language].where((x) => x != null && x.trim().isNotEmpty).cast<String>().toList();
    return parts.isEmpty ? null : parts.join(' · ');
  }

  Future<void> _openSourcePicker() async {
    _pickFromSheet('Sources', [
      for (var i = 0; i < _sources.length; i++)
        _Choice(_label(_sources[i]), i == _index, () {
          if (i != _index) _playIndex(i);
        }),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (_stage == _Stage.fallback) {
      return PlayerScreen(
        request: widget.request,
        playbackProviderService: sl<PlaybackProviderService>(),
        historyService: sl<PlaybackHistoryService>(),
      );
    }

    if (_stage == _Stage.playing) {
      // Full-bleed video; all controls (back, settings, seek) live inside the
      // player overlay so they work in fullscreen too.
      return Scaffold(backgroundColor: Colors.black, body: _videoWithControls());
    }

    // loading / error
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
            if (_stage == _Stage.loading)
              const Text('NATIVE · searching…', style: TextStyle(fontSize: 11, color: Color(0xFF4ADE80))),
          ],
        ),
      ),
      body: Center(child: _body()),
    );
  }

  Widget _videoWithControls() {
    final theme = MaterialVideoControlsThemeData(
      // Double-tap the left/right of the video to seek back/forward (~10s).
      seekOnDoubleTap: true,
      seekOnDoubleTapEnabledWhileControlsVisible: true,
      topButtonBar: [
        const BackButton(color: Colors.white),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.request.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              Text('NATIVE · ${_label(_sources[_index])}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF4ADE80), fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        IconButton(tooltip: 'Subtitles', icon: const Icon(Icons.subtitles, color: Colors.white), onPressed: _openSubtitles),
        IconButton(tooltip: 'Audio', icon: const Icon(Icons.multitrack_audio, color: Colors.white), onPressed: _openAudio),
        IconButton(tooltip: 'Speed', icon: const Icon(Icons.speed, color: Colors.white), onPressed: _openSpeed),
        if (_sources.length > 1)
          IconButton(tooltip: 'Sources', icon: const Icon(Icons.playlist_play, color: Colors.white), onPressed: _openSourcePicker),
      ],
    );
    return MaterialVideoControlsTheme(
      normal: theme,
      fullscreen: theme,
      child: Video(
        controller: _videoController,
        subtitleViewConfiguration: const SubtitleViewConfiguration(
          style: TextStyle(
            fontSize: 22,
            color: Colors.white,
            fontWeight: FontWeight.w500,
            backgroundColor: Color(0xCC000000),
          ),
          padding: EdgeInsets.all(24),
        ),
      ),
    );
  }

  Widget _body() {
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
                    child: Text(_attemptLog.join('\n\n'),
                        style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace', height: 1.4)),
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

class _Choice {
  const _Choice(this.label, this.selected, this.onSelect);
  final String label;
  final bool selected;
  final VoidCallback onSelect;
}
