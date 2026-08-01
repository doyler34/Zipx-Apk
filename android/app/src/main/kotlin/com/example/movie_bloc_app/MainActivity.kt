package com.example.movie_bloc_app

import android.app.UiModeManager
import android.content.Context
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.webkit.WebView
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

        // Two-way channel:
        //  * native -> Flutter: dispatchKeyEvent relays "onKeyEvent" (below).
        //  * Flutter -> native: the player asks us to "tapWebView" so a real
        //    touch is dispatched at the WebView's centre. This is what lets a
        //    remote SELECT click VidSrc's play button even though it lives in
        //    a cross-origin iframe: a synthetic MotionEvent is hit-tested by
        //    the browser against whatever pixel is there and delivered to the
        //    inner frame, which injected JavaScript can never reach.
        remoteChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, remoteChannelName).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "tapWebView" -> result.success(tapWebViewCentre())
                    else -> result.notImplemented()
                }
            }
        }
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

    /// Dispatches a real down/up touch at the centre of the embedded WebView.
    /// Returns true if a WebView was found and tapped.
    ///
    /// Why a native MotionEvent (and not JS): the same-origin policy stops
    /// scripts in the outer page from dispatching events into a cross-origin
    /// iframe, but it does NOT stop a genuine touch - the WebView's renderer
    /// hit-tests the coordinate and delivers the tap to whatever is drawn
    /// there, inner frame included. VidSrc's play button sits dead-centre, so
    /// a centre tap starts playback.
    private fun tapWebViewCentre(): Boolean {
        val webView = findWebView(window.decorView)
        if (webView == null) {
            Log.d(TAG_NATIVE, "tapWebView: no WebView in view tree")
            return false
        }
        if (webView.width == 0 || webView.height == 0) {
            Log.d(TAG_NATIVE, "tapWebView: WebView not laid out yet")
            return false
        }

        val x = webView.width / 2f
        val y = webView.height / 2f
        val downTime = SystemClock.uptimeMillis()

        fun dispatch(action: Int, eventTime: Long) {
            val event = MotionEvent.obtain(downTime, eventTime, action, x, y, 0)
            webView.dispatchTouchEvent(event)
            event.recycle()
        }

        dispatch(MotionEvent.ACTION_DOWN, downTime)
        // A short, human-plausible press: release ~90ms later so it registers
        // as a tap/click rather than a long-press or an ignored flick.
        Handler(Looper.getMainLooper()).postDelayed({
            dispatch(MotionEvent.ACTION_UP, SystemClock.uptimeMillis())
        }, 90)

        Log.d(TAG_NATIVE, "tapWebView at ($x,$y) size=${webView.width}x${webView.height}")
        return true
    }

    /// Depth-first search for the first `android.webkit.WebView` in the view
    /// tree. webview_flutter attaches a real WebView to the Flutter view
    /// hierarchy, so it is reachable from the Activity's decor view.
    private fun findWebView(view: View): WebView? {
        if (view is WebView) return view
        if (view is ViewGroup) {
            for (i in 0 until view.childCount) {
                findWebView(view.getChildAt(i))?.let { return it }
            }
        }
        return null
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
