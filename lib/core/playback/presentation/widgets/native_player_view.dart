import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../services/tv_remote_service.dart';
import '../../../dependency_injection/di.dart';
import '../../domain/entities/extracted_stream.dart';

/// Plays an already-[ExtractedStream] in a native ExoPlayer (via
/// `video_player`) and drives it entirely from the Fire TV remote through
/// [TvRemoteService].
///
/// This is the whole point of the extraction work: no WebView, no iframe, no
/// tap hacks - the remote's play/pause/seek map straight onto the native
/// controller, exactly like any TV video app.
///
/// If the controller reports an error (a stale/expired stream URL is the
/// common cause), [onStreamError] is invoked so the parent can re-extract and
/// hand us a fresh [stream]; giving the widget a `ValueKey(stream.url)`
/// upstream makes a new URL rebuild the controller cleanly.
class NativePlayerView extends StatefulWidget {
  const NativePlayerView({
    super.key,
    required this.stream,
    required this.onStreamError,
  });

  final ExtractedStream stream;

  /// Called when playback fails in a way that warrants re-extraction. The
  /// parent should resolve a fresh stream (forceRefresh) and rebuild.
  final VoidCallback onStreamError;

  @override
  State<NativePlayerView> createState() => _NativePlayerViewState();
}

class _NativePlayerViewState extends State<NativePlayerView> {
  late VideoPlayerController _controller;
  final TvRemoteService _remote = sl<TvRemoteService>();
  StreamSubscription<TvRemoteEvent>? _remoteSub;

  bool _initialized = false;
  bool _showControls = true;
  bool _errorReported = false;
  Timer? _hideControlsTimer;

  static const Duration _shortSeek = Duration(seconds: 10);
  static const Duration _longSeek = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    _remoteSub = _remote.events.listen(_onRemoteEvent);
    _initController();
  }

  Future<void> _initController() async {
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.stream.url),
      httpHeaders: widget.stream.headers,
    )..addListener(_onControllerUpdate);

    try {
      await _controller.initialize();
      if (!mounted) return;
      await _controller.play();
      setState(() => _initialized = true);
      _scheduleHideControls();
    } catch (e) {
      debugPrint('[VIDSRC] native init failed: $e');
      _reportError();
    }
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    if (_controller.value.hasError) {
      debugPrint('[VIDSRC] native playback error: ${_controller.value.errorDescription}');
      _reportError();
      return;
    }
    // Keep the scrubber/time labels live while controls are visible.
    if (_showControls) setState(() {});
  }

  /// Ask the parent to re-extract, but only once per controller instance so a
  /// storm of error callbacks can't trigger repeated reloads.
  void _reportError() {
    if (_errorReported) return;
    _errorReported = true;
    widget.onStreamError();
  }

  @override
  void dispose() {
    _remoteSub?.cancel();
    _hideControlsTimer?.cancel();
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    super.dispose();
  }

  // --- remote handling ------------------------------------------------------

  void _onRemoteEvent(TvRemoteEvent event) {
    if (!mounted || !_initialized) return;
    switch (event.action) {
      case TvRemoteAction.back:
        return; // owned by the parent's PopScope
      case TvRemoteAction.select:
      case TvRemoteAction.playPause:
        if (event.isInitialPress) _togglePlayPause();
      case TvRemoteAction.play:
        if (event.isInitialPress) _setPlaying(true);
      case TvRemoteAction.pause:
        if (event.isInitialPress) _setPlaying(false);
      case TvRemoteAction.left:
        _seekBy(-_shortSeek);
      case TvRemoteAction.right:
        _seekBy(_shortSeek);
      case TvRemoteAction.rewind:
        _seekBy(-_longSeek);
      case TvRemoteAction.fastForward:
        _seekBy(_longSeek);
      case TvRemoteAction.up:
      case TvRemoteAction.down:
        _revealControls();
    }
  }

  void _togglePlayPause() => _setPlaying(!_controller.value.isPlaying);

  void _setPlaying(bool playing) {
    playing ? _controller.play() : _controller.pause();
    _revealControls();
  }

  void _seekBy(Duration delta) {
    final value = _controller.value;
    if (!value.isInitialized) return;
    var target = value.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (target > value.duration) target = value.duration;
    _controller.seekTo(target);
    _revealControls();
  }

  void _revealControls() {
    if (!_showControls) setState(() => _showControls = true);
    _scheduleHideControls();
  }

  void _scheduleHideControls() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _controller.value.isPlaying) setState(() => _showControls = false);
    });
  }

  // --- UI -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio == 0 ? 16 / 9 : _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
          ),
          if (_controller.value.isBuffering) const Center(child: CircularProgressIndicator(color: Colors.white)),
          if (_showControls) _buildControls(),
        ],
      ),
    );
  }

  Widget _buildControls() {
    final value = _controller.value;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.center,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Icon(
              value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
              color: Colors.white,
              size: 72,
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  VideoProgressIndicator(
                    _controller,
                    allowScrubbing: false,
                    colors: const VideoProgressColors(
                      playedColor: Colors.redAccent,
                      bufferedColor: Colors.white24,
                      backgroundColor: Colors.white10,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_fmt(value.position), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      Text(_fmt(value.duration), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }
}
