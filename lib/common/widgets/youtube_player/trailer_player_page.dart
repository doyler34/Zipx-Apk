import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// Full-screen in-app trailer player.
///
/// Serves a tiny HTML page that embeds the video in an `<iframe>`, loaded with
/// the WebView base URL set to `https://www.youtube.com`. That gives the embed
/// a valid parent origin/referer, which YouTube's player requires - loading the
/// player another way returned "origin"/"configuration" errors (152 / 153) for
/// every video. An "Open in YouTube" action is kept as a fallback.
class TrailerPlayerPage extends StatefulWidget {
  const TrailerPlayerPage({super.key, required this.videoId, this.title});

  final String videoId;
  final String? title;

  @override
  State<TrailerPlayerPage> createState() => _TrailerPlayerPageState();
}

class _TrailerPlayerPageState extends State<TrailerPlayerPage> {
  late final WebViewController _controller;

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

    // Embed the video in an iframe on a page whose origin is youtube.com, so
    // the embed has a valid parent origin/referer (fixes errors 152 / 153).
    _controller.loadHtmlString(_embedHtml(widget.videoId), baseUrl: 'https://www.youtube.com');
  }

  String _embedHtml(String videoId) {
    // youtube-nocookie + referrer policy: since late 2025 YouTube rejects embeds
    // that don't send a proper Referer (errors 152 / 153). The meta tag + the
    // iframe referrerpolicy make the WebView send strict-origin-when-cross-origin.
    final src = 'https://www.youtube-nocookie.com/embed/$videoId'
        '?autoplay=1&playsinline=1&rel=0&fs=1&modestbranding=1';
    return '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
<meta name="referrer" content="strict-origin-when-cross-origin">
<style>
  html, body { margin: 0; padding: 0; background: #000; height: 100%; overflow: hidden; }
  .wrap { position: relative; width: 100%; height: 100%; }
  iframe { position: absolute; top: 0; left: 0; width: 100%; height: 100%; border: 0; }
</style>
</head>
<body>
  <div class="wrap">
    <iframe src="$src"
      referrerpolicy="strict-origin-when-cross-origin"
      allow="autoplay; encrypted-media; fullscreen; picture-in-picture"
      allowfullscreen></iframe>
  </div>
</body>
</html>
''';
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
