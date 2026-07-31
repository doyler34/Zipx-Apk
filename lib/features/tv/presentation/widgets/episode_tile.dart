import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';

import '../../../../common/styles/styles.dart';
import '../../../../common/widgets/tv/tv_focusable.dart';
import '../../../../core/utils/strings/url_strings.dart';
import '../../data/models/tv_episode_model.dart';

/// Renders one episode row. Tapping anywhere on the row (or pressing OK on a
/// TV remote when it's focused) plays the episode - the callback is supplied
/// by the screen, which is the only place that knows how to build a
/// [PlaybackRequest] for it.
class EpisodeTile extends StatelessWidget {
  const EpisodeTile({super.key, required this.episode, required this.onPlay, this.autofocus = false});

  final TvEpisodeModel episode;
  final VoidCallback onPlay;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: TvFocusable(
        onPressed: onPlay,
        autofocus: autofocus,
        borderRadius: 8,
        focusScale: 1.02,
        child: Container(
        decoration: Styles(context: context).cardBoxDecoration,
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 100,
                height: 60,
                child: episode.stillPath.trim() != ''
                    ? ExtendedImage.network(UrlStrings.imageUrl + episode.stillPath, fit: BoxFit.cover, cache: true)
                    : Container(color: Colors.black26, child: const Icon(Icons.tv, color: Colors.white54)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${episode.episodeNumber}. ${episode.name}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (episode.overview.trim().isNotEmpty)
                    Text(
                      episode.overview,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 4),
              child: Icon(Icons.play_circle_fill, color: Theme.of(context).colorScheme.tertiary, size: 36),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
