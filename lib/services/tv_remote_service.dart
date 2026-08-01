import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The meaningful, platform-agnostic actions a Fire TV / Android TV remote can
/// produce on the player screen. UI code reasons about these, never about raw
/// Android key codes.
enum TvRemoteAction {
  up,
  down,
  left,
  right,
  select,
  play,
  pause,
  playPause,
  rewind,
  fastForward,
  back,
}

/// A single decoded remote press coming up from the native side.
@immutable
class TvRemoteEvent {
  const TvRemoteEvent({
    required this.action,
    required this.keyCode,
    required this.repeatCount,
  });

  final TvRemoteAction action;

  /// The raw Android `KEYCODE_*` value, kept for logging / debugging.
  final int keyCode;

  /// 0 for the initial press; >0 for auto-repeat presses while a key is held.
  final int repeatCount;

  /// The first press of a key (as opposed to an auto-repeat). Discrete actions
  /// (play/pause/select/back) should only fire on this to avoid a held key
  /// triggering the action many times.
  bool get isInitialPress => repeatCount == 0;

  @override
  String toString() => 'TvRemoteEvent(action: $action, keyCode: $keyCode, repeatCount: $repeatCount)';
}

/// Bridges Fire TV / Android TV remote key events from native Android
/// (`MainActivity.dispatchKeyEvent` over the `zipx.tv/remote` [MethodChannel])
/// into a single broadcast [Stream] the player screen can listen to.
///
/// Registered once as an app-wide singleton (see dependency injection). The
/// method-call handler is installed a single time in [initialize]; screens
/// subscribe to [events] and cancel their own subscription on dispose, so
/// there are never duplicate native handlers or leaked listeners.
class TvRemoteService {
  static const MethodChannel _channel = MethodChannel('zipx.tv/remote');

  /// `TV_REMOTE_FLUTTER` diagnostic tag (see the task's diagnostic-mode spec).
  static const String _logTag = 'TV_REMOTE_FLUTTER';

  final StreamController<TvRemoteEvent> _controller = StreamController<TvRemoteEvent>.broadcast();

  bool _initialized = false;
  bool _hasReceivedNativeEvent = false;

  /// Broadcast so multiple widgets could listen; in practice the active
  /// player screen is the sole subscriber.
  Stream<TvRemoteEvent> get events => _controller.stream;

  /// True once at least one event has arrived from native. The Flutter-side
  /// [Focus] fallback in the player uses this to stand down: if native is
  /// already delivering events there's no need to also process Flutter's own
  /// key events, which would double-handle every press.
  bool get hasReceivedNativeEvent => _hasReceivedNativeEvent;

  /// Idempotent. Installs the native -> Dart method-call handler exactly once.
  void initialize() {
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method != 'onKeyEvent') return null;

    final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? const {};
    final keyCode = args['keyCode'] as int?;
    final repeatCount = (args['repeatCount'] as int?) ?? 0;
    if (keyCode == null) return null;

    final action = _actionForKeyCode(keyCode);
    if (action == null) return null;

    _hasReceivedNativeEvent = true;
    final event = TvRemoteEvent(action: action, keyCode: keyCode, repeatCount: repeatCount);
    if (kDebugMode) {
      debugPrint('$_logTag received $event');
    }
    if (!_controller.isClosed) _controller.add(event);
    return null;
  }

  /// Maps a raw Android `KEYCODE_*` value to a [TvRemoteAction]. Returns null
  /// for codes we don't care about. Kept in sync with the relayed set in
  /// `MainActivity.kt`.
  static TvRemoteAction? _actionForKeyCode(int keyCode) {
    switch (keyCode) {
      case 19: // KEYCODE_DPAD_UP
        return TvRemoteAction.up;
      case 20: // KEYCODE_DPAD_DOWN
        return TvRemoteAction.down;
      case 21: // KEYCODE_DPAD_LEFT
        return TvRemoteAction.left;
      case 22: // KEYCODE_DPAD_RIGHT
        return TvRemoteAction.right;
      case 23: // KEYCODE_DPAD_CENTER
      case 66: // KEYCODE_ENTER
        return TvRemoteAction.select;
      case 126: // KEYCODE_MEDIA_PLAY
        return TvRemoteAction.play;
      case 127: // KEYCODE_MEDIA_PAUSE
        return TvRemoteAction.pause;
      case 85: // KEYCODE_MEDIA_PLAY_PAUSE
        return TvRemoteAction.playPause;
      case 89: // KEYCODE_MEDIA_REWIND
        return TvRemoteAction.rewind;
      case 90: // KEYCODE_MEDIA_FAST_FORWARD
        return TvRemoteAction.fastForward;
      case 4: // KEYCODE_BACK
        return TvRemoteAction.back;
      default:
        return null;
    }
  }

  /// Releases the singleton for good (app teardown). Screens should NOT call
  /// this - they cancel their own [StreamSubscription] instead. Calling it
  /// clears the native handler and closes the broadcast stream.
  void dispose() {
    if (!_initialized) return;
    _initialized = false;
    _channel.setMethodCallHandler(null);
    _controller.close();
  }
}
