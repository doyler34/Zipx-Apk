package com.example.movie_bloc_app

import android.app.UiModeManager
import android.content.Context
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.util.Log
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val deviceChannelName = "com.zipx/device"
    private val remoteChannelName = "zipx.tv/remote"

    // Held so [dispatchKeyEvent] (which runs long after
    // configureFlutterEngine) can push Fire TV remote key events up to
    // Flutter. Nullable because key events can technically arrive before /
    // after the engine is attached.
    private var remoteChannel: MethodChannel? = null

    // Android key codes we relay to Flutter. Anything not in this set is left
    // entirely alone so normal Flutter focus traversal on the browse UI, text
    // input, volume keys, etc. keep behaving exactly as before.
    private val relayedKeyCodes = setOf(
        KeyEvent.KEYCODE_DPAD_UP,
        KeyEvent.KEYCODE_DPAD_DOWN,
        KeyEvent.KEYCODE_DPAD_LEFT,
        KeyEvent.KEYCODE_DPAD_RIGHT,
        KeyEvent.KEYCODE_DPAD_CENTER,
        KeyEvent.KEYCODE_ENTER,
        KeyEvent.KEYCODE_MEDIA_PLAY,
        KeyEvent.KEYCODE_MEDIA_PAUSE,
        KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE,
        KeyEvent.KEYCODE_MEDIA_REWIND,
        KeyEvent.KEYCODE_MEDIA_FAST_FORWARD,
        KeyEvent.KEYCODE_BACK,
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, deviceChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isTv" -> result.success(isRunningOnTv())
                    else -> result.notImplemented()
                }
            }

        // Native -> Flutter only. We never receive method calls on this
        // channel; it exists purely so dispatchKeyEvent can invoke
        // "onKeyEvent" up into the Dart TvRemoteService.
        remoteChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, remoteChannelName)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        remoteChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    /// Activity-level key dispatch is the FIRST place a hardware key event
    /// lands, before it is routed down into the Flutter view / embedded
    /// WebView. We relay the interesting keys up to Flutter here, then call
    /// through to `super` WITHOUT consuming the event, so:
    ///   * the browse UI's Flutter focus traversal still works everywhere,
    ///   * the system Back button still reaches Flutter's PopScope,
    ///   * we only *observe* the stream, we don't hijack it.
    ///
    /// To avoid a single press being handled multiple times we relay only
    /// ACTION_DOWN (including auto-repeats, whose repeatCount we pass through
    /// so Flutter can choose to act on the first, repeatCount == 0, press).
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.action == KeyEvent.ACTION_DOWN && relayedKeyCodes.contains(event.keyCode)) {
            Log.d(
                TAG_NATIVE,
                "keyCode=${event.keyCode} action=down repeatCount=${event.repeatCount}",
            )
            remoteChannel?.invokeMethod(
                "onKeyEvent",
                mapOf(
                    "keyCode" to event.keyCode,
                    "action" to "down",
                    "repeatCount" to event.repeatCount,
                ),
            )
        }
        // Never consume: normal focus/back/WebView handling continues.
        return super.dispatchKeyEvent(event)
    }

    // A device is treated as a TV if the system UI mode reports television,
    // or it advertises the leanback feature (Fire TV / Android TV), or it
    // has no touchscreen.
    private fun isRunningOnTv(): Boolean {
        val uiModeManager = getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
        if (uiModeManager.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION) return true
        val pm = packageManager
        if (pm.hasSystemFeature(PackageManager.FEATURE_LEANBACK)) return true
        if (pm.hasSystemFeature("amazon.hardware.fire_tv")) return true
        return !pm.hasSystemFeature(PackageManager.FEATURE_TOUCHSCREEN)
    }

    companion object {
        private const val TAG_NATIVE = "TV_REMOTE_NATIVE"
    }
}
