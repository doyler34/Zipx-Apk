import 'package:flutter/material.dart';
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
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title ?? 'Trailer'),
        actions: [
          IconButton(
            tooltip: 'Open in YouTube',
            icon: const Icon(Icons.open_in_new),
            onPressed: _openExternal,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: WebViewWidget(controller: _controller),
          ),
        ),
      ),
    );
  }
}
