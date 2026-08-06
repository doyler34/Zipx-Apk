import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

/// Full-screen in-app trailer player.
///
/// Uses [YoutubePlayerScaffold] (the recommended full-page usage of
/// youtube_player_iframe) and renders the player directly - no FittedBox /
/// Transform around the WebView, which is what made the old inline embed render
/// blank on Android. An "Open in YouTube" action is kept as a fallback.
class TrailerPlayerPage extends StatefulWidget {
  const TrailerPlayerPage({super.key, required this.videoId, this.title});

  final String videoId;
  final String? title;

  @override
  State<TrailerPlayerPage> createState() => _TrailerPlayerPageState();
}

class _TrailerPlayerPageState extends State<TrailerPlayerPage> {
  late final YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        strictRelatedVideos: true,
      ),
    );
  }

  @override
  void dispose() {
    _controller.close();
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
    return YoutubePlayerScaffold(
      controller: _controller,
      aspectRatio: 16 / 9,
      builder: (context, player) {
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
          body: Center(child: player),
        );
      },
    );
  }
}
