import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class YtPlayerWidget extends StatefulWidget {
  const YtPlayerWidget({
    super.key,
    required this.trailerId,
  });

  final String trailerId;

  @override
  State<YtPlayerWidget> createState() => _YtPlayerWidgetState();
}

class _YtPlayerWidgetState extends State<YtPlayerWidget> {
  late final YoutubePlayerController controller;

  @override
  void initState() {
    super.initState();
    controller = YoutubePlayerController.fromVideoId(
      videoId: widget.trailerId,
      autoPlay: false,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        strictRelatedVideos: true,
      ),
    );
  }

  @override
  void dispose() {
    controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) => controller.pauseVideo(),
      child: YoutubeValueBuilder(
        controller: controller,
        builder: (context, value) {
          if (value.hasError) {
            return _TrailerUnavailable(videoId: widget.trailerId, error: value.error);
          }
          return YoutubePlayer(controller: controller, aspectRatio: 16 / 9);
        },
      ),
    );
  }
}

/// Shown when YouTube's IFrame API reports the video can't be played here
/// (embedding disabled by the uploader, region-locked, removed, etc) - not
/// something this app can work around, so it offers a way to watch it
/// directly on YouTube instead of a dead player.
class _TrailerUnavailable extends StatelessWidget {
  const _TrailerUnavailable({required this.videoId, required this.error});

  final String videoId;
  final YoutubeError error;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: Colors.black,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_outlined, color: Colors.white54, size: 32),
            const SizedBox(height: 8),
            const Text(
              "This trailer can't be played here.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => launchUrl(
                Uri.https('www.youtube.com', '/watch', {'v': videoId}),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new, color: Colors.white),
              label: const Text('Watch on YouTube', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
