import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// Full-screen in-app trailer player.
///
/// Loads YouTube's `/embed/` page directly in a WebView rather than going
/// through the IFrame JS API - the JS API verifies the embedding origin and
/// rejected the local player page (error 152) for every video. Navigating the
/// WebView top-level to youtube.com passes that check, so embeddable trailers
/// play. An "Open in YouTube" action is kept as a fallback.
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
    final url = 'https://www.youtube.com/embed/${widget.videoId}'
        '?autoplay=1&playsinline=1&rel=0&fs=1&modestbranding=1';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black);

    // Allow autoplay without a tap (Android only API).
    final platform = _controller.platform;
    if (platform is AndroidWebViewController) {
      platform.setMediaPlaybackRequiresUserGesture(false);
    }

    _controller.loadRequest(Uri.parse(url));
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
