import 'package:extended_image/extended_image.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../styles/zipx_ui.dart';
import '../tv/tv_focusable.dart';
import 'trailer_player_page.dart';

/// A trailer preview: a 16:9 YouTube thumbnail with a red play button that
/// opens the trailer in an in-app full-screen player on tap.
///
/// Replaces the inline iframe embed, which rendered blank on some devices.
/// Focusable for TV-remote / keyboard use.
class TrailerPreview extends StatelessWidget {
  const TrailerPreview({super.key, required this.videoId, this.title});

  final String videoId;
  final String? title;

  void _open(BuildContext context) {
    // Desktop (Windows/Linux/macOS) has no webview_flutter, so open the trailer
    // in the system browser there; play in-app on mobile.
    const desktop = {TargetPlatform.windows, TargetPlatform.linux, TargetPlatform.macOS};
    if (desktop.contains(defaultTargetPlatform)) {
      launchUrl(Uri.https('www.youtube.com', '/watch', {'v': videoId}), mode: LaunchMode.externalApplication);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TrailerPlayerPage(videoId: videoId, title: title)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TvFocusable(
        onPressed: () => _open(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ExtendedImage.network(
                  'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
                  fit: BoxFit.cover,
                  cache: true,
                  printError: false,
                  loadStateChanged: (state) {
                    if (state.extendedImageLoadState == LoadState.failed) {
                      return const ColoredBox(color: ZipxUi.surface);
                    }
                    return null;
                  },
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black26, Colors.black54],
                    ),
                  ),
                ),
                Center(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      // Scale the play button to the preview size, clamped.
                      final d = (c.maxWidth * 0.16).clamp(48.0, 88.0);
                      return Container(
                        width: d,
                        height: d,
                        decoration: BoxDecoration(
                          color: ZipxUi.red,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 12)],
                        ),
                        child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: d * 0.6),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
