import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';

import '../../../../common/styles/styles.dart';
import '../../../../core/utils/strings/url_strings.dart';
import '../../data/models/tv_episode_model.dart';

/// Renders one episode row with a Play button. Purely presentational - the
/// tap callback is supplied by the screen, which is the only place that
/// knows how to build a [PlaybackRequest] for it.
class EpisodeTile extends StatelessWidget {
  const EpisodeTile({super.key, required this.episode, required this.onPlay});

  final TvEpisodeModel episode;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
            IconButton(
              icon: Icon(Icons.play_circle_fill, color: Theme.of(context).colorScheme.tertiary, size: 36),
              tooltip: 'Play episode',
              onPressed: onPlay,
            ),
          ],
        ),
      ),
    );
  }
}
