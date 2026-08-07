import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// Full-screen in-app trailer player.
///
/// Loads a small public HTML page hosted on GitHub Pages that renders the
/// YouTube iframe. This is the key detail: `loadHtmlString` serves the page
/// from an opaque local origin, so YouTube's player rejects it with "video
/// unavailable" 152/153 - a `referrerpolicy`/`baseUrl` does NOT fix that in a
/// WebView. Pointing the WebView at a real HTTPS page gives the iframe a valid
/// origin/Referer, so playback works. The page lives in its own public repo
/// (so the app repo can go private without breaking trailers). An "Open in
/// YouTube" action is kept as a fallback.
///
/// While open, the page goes immersive (status + navigation bars hidden) and
/// allows landscape, so the video is a true full-screen experience - not a box
/// with the phone's system bars still showing.
class TrailerPlayerPage extends StatefulWidget {
  const TrailerPlayerPage({super.key, required this.videoId, this.title});

  final String videoId;
  final String? title;

  @override
  State<TrailerPlayerPage> createState() => _TrailerPlayerPageState();
}

class _TrailerPlayerPageState extends State<TrailerPlayerPage> {
  late final WebViewController _controller;

  /// Public HTTPS embed page (GitHub Pages, own repo). Renders the YouTube
  /// iframe from a real origin so the WebView player stops erroring 152/153.
  /// It reads the video id from `?v=`.
  static const String _embedBase = 'https://doyler34.github.io/Embed-test/embed.html';

  @override
  void initState() {
    super.initState();

    // True fullscreen: hide the phone's status + navigation bars, and allow
    // landscape so the video can fill the screen when the phone is rotated
    // (or the player's fullscreen button is used).
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black);

    // Allow autoplay without a tap (Android only API).
    final platform = _controller.platform;
    if (platform is AndroidWebViewController) {
      platform.setMediaPlaybackRequiresUserGesture(false);
    }

    // Load the real hosted page (not loadHtmlString), so the iframe has a valid
    // HTTPS origin/Referer and YouTube allows playback.
    _controller.loadRequest(Uri.parse('$_embedBase?v=${widget.videoId}'));
  }

  @override
  void dispose() {
    // Restore the app's normal chrome + portrait lock on the way out.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    super.dispose();
  }

  Future<void> _openExternal() async {
    final uri = Uri.https('www.youtube.com', '/watch', {'v': widget.videoId});
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Ignore - nothing else to do if no browser/YouTube app is available.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 16:9 video centred on black. Immersive mode removes the system bars,
          // and in landscape this fills the screen for a true-fullscreen feel;
          // keeping it boxed means YouTube's own controls stay inside the video
          // rather than colliding with the back button.
          Center(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: WebViewWidget(controller: _controller),
            ),
          ),
          // Floating controls over the top black margin. Kept small (with a
          // dark disc) so they don't cover the player's own chrome.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  children: [
                    _circleButton(Icons.arrow_back, 'Back', () => Navigator.of(context).maybePop()),
                    const Spacer(),
                    _circleButton(Icons.open_in_new, 'Open in YouTube', _openExternal),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleButton(IconData icon, String tooltip, VoidCallback onTap) {
    return Material(
      color: Colors.black45,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, color: Colors.white),
        onPressed: onTap,
      ),
    );
  }
}
