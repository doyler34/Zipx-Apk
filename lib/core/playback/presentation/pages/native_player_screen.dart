import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
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
import '../../services/subtitle_service.dart';
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
  final SubtitleService _subtitleService = sl<SubtitleService>();

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

  /// External (OpenSubtitles via Wyzie) subtitle tracks for this title, fetched
  /// in the background so text subs are available even when the streamed file
  /// has none embedded. [_selectedExternalSub] is the index currently applied
  /// (null when an embedded track or Off is selected instead).
  List<ExternalSubtitle> _externalSubs = const [];
  int? _selectedExternalSub;
  bool _subsRequested = false;

  /// The title's original language (TMDB code). When a file has several audio
  /// tracks (e.g. original + dub), we auto-select this one so the dub isn't the
  /// default. Done once, then the user can override from the Audio menu.
  String? _originalLang;
  bool _audioAutoSelected = false;
  bool _subsAutoEnabled = false;
  StreamSubscription<Tracks>? _tracksSub;

  /// Subtitle text size (adjustable from the subtitle menu). Small (24) is the
  /// smallest offered - it's a comfortable readable size, and the steps go up
  /// from there.
  double _subtitleFontSize = 24;

  /// How the video fills the screen: contain (letterboxed, true aspect) or
  /// cover (zoomed to fill, crops the edges). Toggled from the control bar.
  BoxFit _videoFit = BoxFit.contain;

  /// Subtitle timing offset in seconds (mpv `sub-delay`). Positive shows subs
  /// later, negative earlier - lets the user line up an out-of-sync sub file.
  double _subtitleDelay = 0;

  static const Map<String, double> _subtitleSizes = {'S': 24, 'M': 32, 'L': 42, 'XL': 52};

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
    // True fullscreen: hide the status + navigation bars so the video fills the
    // screen and the system nav bar stops clipping the control bar. "Sticky" so
    // a swipe reveals them briefly then they auto-hide again.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // Auto-pick the original-language audio track once the file's tracks load.
    _tracksSub = _player.stream.tracks.listen((tracks) {
      _maybeAutoSelectAudio(tracks.audio);
      _maybeAutoEnableSubs();
    });
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tracksSub?.cancel();
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
      // Runtime + original language in parallel with the sources (both only
      // needed later, at/after play time).
      final runtimeFuture = _service.expectedRuntimeMinutes(widget.request);
      final langFuture = _service.originalLanguage(widget.request);
      final sources = await _service.fetch(widget.request);
      _expectedRuntimeMin = await runtimeFuture;
      _originalLang = await langFuture;
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

  /// Applies a subtitle timing offset via mpv's `sub-delay` property so the
  /// user can fix an out-of-sync sub. Persists across track switches (it's a
  /// player-global property). The dynamic call avoids a hard dependency on the
  /// native-player type; if the property API isn't available it's a no-op.
  Widget _syncButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: const BoxDecoration(color: Colors.white12, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Future<void> _setSubtitleDelay(double seconds) async {
    final clamped = seconds.clamp(-20.0, 20.0);
    setState(() => _subtitleDelay = clamped);
    try {
      await (_player.platform as dynamic).setProperty('sub-delay', clamped.toStringAsFixed(2));
    } catch (_) {
      // Property API unavailable on this platform - delay just won't apply.
    }
  }

  /// When a file exposes multiple audio tracks (original + dub is common on
  /// C-drama torrents), pick the original-language one so the dub - which often
  /// bleeds the original underneath - isn't the default. Runs once, when tracks
  /// first load; the user can still override from the Audio menu.
  void _maybeAutoSelectAudio(List<AudioTrack> audios) {
    if (_audioAutoSelected) return;
    final real = audios.where((a) => a.id != 'no' && a.id != 'auto').toList();
    if (real.length < 2) return; // nothing to choose between yet
    // Wait for track metadata to populate before committing (early emits can
    // have empty language/title).
    final hasMeta = real.any((a) => (a.language ?? '').isNotEmpty || (a.title ?? '').isNotEmpty);
    if (!hasMeta) return;
    _audioAutoSelected = true;

    final lang = _originalLang;
    if (lang == null || lang.isEmpty) return;
    final aliases = _langAliases(lang);

    for (final a in real) {
      final hay = '${a.language ?? ''} ${a.title ?? ''}'.toLowerCase();
      if (aliases.any(hay.contains)) {
        if (_player.state.track.audio.id != a.id) _player.setAudioTrack(a);
        return;
      }
    }
  }

  /// Language-code/name aliases so a TMDB code ("zh") matches mpv track tags
  /// ("chi"/"zho"/"mandarin"/...).
  List<String> _langAliases(String code) {
    switch (code.toLowerCase()) {
      case 'zh':
        return const ['zh', 'zho', 'chi', 'cmn', 'yue', 'mandarin', 'cantonese', 'chinese'];
      case 'ja':
        return const ['ja', 'jpn', 'japanese'];
      case 'ko':
        return const ['ko', 'kor', 'korean'];
      case 'hi':
        return const ['hi', 'hin', 'hindi'];
      case 'th':
        return const ['th', 'tha', 'thai'];
      case 'es':
        return const ['es', 'spa', 'spanish'];
      case 'fr':
        return const ['fr', 'fra', 'fre', 'french'];
      case 'en':
        return const ['en', 'eng', 'english'];
      default:
        return [code.toLowerCase()];
    }
  }

  /// Fetches online subtitles once the stream is playing, matched to the
  /// playing release so they're in sync. Runs once (guarded).
  void _maybeLoadSubs(StreamSource source) {
    if (_subsRequested) return;
    _subsRequested = true;
    unawaited(_loadExternalSubs(source.releaseName));
  }

  Future<void> _loadExternalSubs(String? releaseName) async {
    final subs = await _subtitleService.fetch(widget.request, releaseName: releaseName);
    if (!mounted) return;
    setState(() => _externalSubs = subs);
    // Online subs just arrived - use them if we still need to turn subs on.
    _maybeAutoEnableSubs();
  }

  /// For non-English originals (e.g. anime), turn English subtitles ON by
  /// default: prefer an embedded English track, else the first English online
  /// sub once it loads. English-original titles are left alone (no forced subs).
  /// Runs once, and only if the user hasn't already picked a subtitle.
  void _maybeAutoEnableSubs() {
    if (_subsAutoEnabled) return;
    final lang = (_originalLang ?? '').toLowerCase();
    if (lang.isEmpty || lang == 'en') return;
    // Don't override a track the user already chose.
    if (_selectedExternalSub != null) {
      _subsAutoEnabled = true;
      return;
    }
    final cur = _player.state.track.subtitle;
    if (cur.id != 'no' && cur.id != 'auto') {
      // A subtitle is already showing (embedded default) - leave it.
      _subsAutoEnabled = true;
      return;
    }

    // 1) An embedded English subtitle track, if present.
    for (final t in _player.state.tracks.subtitle) {
      if (t.id == 'no' || t.id == 'auto') continue;
      if (_isEnglishTrack(t)) {
        _subsAutoEnabled = true;
        _player.setSubtitleTrack(t);
        return;
      }
    }

    // 2) Otherwise the first online English sub, once it has loaded.
    if (_externalSubs.isNotEmpty) {
      _subsAutoEnabled = true;
      final direct = _externalSubs.indexWhere((s) => s.kind == SubtitleKind.direct);
      _applyExternalSub(direct >= 0 ? direct : 0);
    }
  }

  /// Desktop has no webview_flutter, so the VidSrc WebView fallback can't run
  /// there (yet) - native streaming is the only path on desktop.
  bool get _isDesktop =>
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS;

  void _goFallback() {
    if (!mounted) return;
    if (kDisableWebFallback || _isDesktop) {
      setState(() {
        _stage = _Stage.error;
        _error = _sources.isEmpty
            ? 'Native streaming found NO playable source for this title.\n\n(Expected for unreleased / very new titles.)'
            : 'The backend returned ${_sources.length} native source(s), but none would open.';
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
      _maybeLoadSubs(source);
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
    final off = subs.where((t) => t.id == 'no').toList();
    // The video's own tracks are the primary option now that they're
    // size-controllable; English ones sort to the top.
    final embedded = subs.where((t) => t.id != 'no').toList()
      ..sort((a, b) => (_isEnglishTrack(a) ? 0 : 1).compareTo(_isEnglishTrack(b) ? 0 : 1));

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF16161B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheet) {
            final noOnline = _selectedExternalSub == null;

            Widget tile(String label, bool selected, VoidCallback onTap) => ListTile(
                  dense: true,
                  title: Text(label, style: const TextStyle(color: Colors.white)),
                  trailing: selected ? const Icon(Icons.check, color: Color(0xFFE11D2A)) : null,
                  onTap: onTap,
                );

            Widget header(String text) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      text.toUpperCase(),
                      style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6),
                    ),
                  ),
                );

            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text('Subtitles', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  // Text-size selector - changes the on-screen subtitle size live.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        const Text('Text size', style: TextStyle(color: Colors.white70)),
                        const Spacer(),
                        for (final opt in _subtitleSizes.entries)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _subtitleFontSize = opt.value);
                                setSheet(() {});
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  color: (_subtitleFontSize - opt.value).abs() < 0.5 ? const Color(0xFFE11D2A) : Colors.white12,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(opt.key, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Subtitle sync (delay) - nudge the subs earlier/later to
                  // line them up with the speech.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        const Text('Sync', style: TextStyle(color: Colors.white70)),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            _setSubtitleDelay(0);
                            setSheet(() {});
                          },
                          child: const Text('reset', style: TextStyle(color: Colors.white38, fontSize: 12)),
                        ),
                        const Spacer(),
                        _syncButton(Icons.remove, () {
                          _setSubtitleDelay(_subtitleDelay - 0.25);
                          setSheet(() {});
                        }),
                        SizedBox(
                          width: 74,
                          child: Text(
                            '${_subtitleDelay > 0 ? '+' : ''}${_subtitleDelay.toStringAsFixed(2)}s',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ),
                        _syncButton(Icons.add, () {
                          _setSubtitleDelay(_subtitleDelay + 0.25);
                          setSheet(() {});
                        }),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 20),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        // Off first, for quick access.
                        for (final t in off)
                          tile('Off', noOnline && t.id == cur.id, () {
                            setState(() => _selectedExternalSub = null);
                            _player.setSubtitleTrack(t);
                            Navigator.of(sheetCtx).pop();
                          }),
                        // Primary: the video's own subtitle tracks (English first).
                        if (embedded.isNotEmpty) header('From the video'),
                        for (final t in embedded)
                          tile(_subLabel(t), noOnline && t.id == cur.id, () {
                            setState(() => _selectedExternalSub = null);
                            _player.setSubtitleTrack(t);
                            Navigator.of(sheetCtx).pop();
                          }),
                        // Backup: online subs (SubDL / OpenSubtitles).
                        if (_externalSubs.isNotEmpty) header('Backup · online'),
                        for (var i = 0; i < _externalSubs.length; i++)
                          tile(_externalSubs[i].label, _selectedExternalSub == i, () {
                            Navigator.of(sheetCtx).pop();
                            _applyExternalSub(i);
                          }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Applies an online subtitle. Direct URLs go straight into mpv; SubDL zips
  /// are downloaded + unzipped first (with a brief "loading" toast).
  Future<void> _applyExternalSub(int i) async {
    final s = _externalSubs[i];
    if (s.kind == SubtitleKind.direct) {
      setState(() => _selectedExternalSub = i);
      await _player.setSubtitleTrack(SubtitleTrack.uri(s.url, title: s.label, language: 'en'));
      return;
    }
    // SubDL zip: fetch + unpack before loading.
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading subtitle…'), duration: Duration(seconds: 2)),
      );
    }
    final data = await _subtitleService.resolveSubdlZip(s.url, episode: s.episode);
    if (!mounted) return;
    if (data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subtitle unavailable')),
      );
      return;
    }
    setState(() => _selectedExternalSub = i);
    await _player.setSubtitleTrack(SubtitleTrack.data(data, title: s.label, language: 'en'));
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

  bool _isEnglishTrack(SubtitleTrack t) {
    final lang = (t.language ?? '').toLowerCase();
    final title = (t.title ?? '').toLowerCase();
    return lang == 'en' || lang == 'eng' || lang.startsWith('en-') || title.contains('english');
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
      // Lift the seek bar + bottom buttons off the very bottom edge so the
      // progress bar isn't clipped by the screen edge / gesture area, and pad
      // the top bar down from the notch.
      topButtonBarMargin: const EdgeInsets.only(top: 12, left: 8, right: 8),
      seekBarMargin: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
      bottomButtonBarMargin: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
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
        IconButton(
          tooltip: _videoFit == BoxFit.contain ? 'Zoom to fill' : 'Fit',
          icon: Icon(_videoFit == BoxFit.contain ? Icons.fit_screen : Icons.crop_free, color: Colors.white),
          onPressed: () => setState(() => _videoFit = _videoFit == BoxFit.contain ? BoxFit.cover : BoxFit.contain),
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
        fit: _videoFit,
        subtitleViewConfiguration: SubtitleViewConfiguration(
          style: TextStyle(
            fontSize: _subtitleFontSize,
            color: Colors.white,
            fontWeight: FontWeight.w600,
            backgroundColor: const Color(0x99000000),
            shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
          ),
          padding: const EdgeInsets.all(24),
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
