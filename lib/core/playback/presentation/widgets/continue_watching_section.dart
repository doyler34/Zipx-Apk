import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../common/styles/styles.dart';
import '../../../../common/widgets/tv/tv_focusable.dart';
import '../../../../common/widgets/texts/header.dart';
import '../../../../core/utils/strings/url_strings.dart';
import '../../domain/entities/playback_media_type.dart';
import '../../services/playback_history_service.dart';

/// "Continue Watching" row for the home screen, backed entirely by
/// [PlaybackHistoryService]. Reads whatever was last watched (regardless of
/// which provider played it) and resumes straight into the player with the
/// same request - closing the player never marked anything "completed", so
/// this always reflects genuinely-in-progress titles.
class ContinueWatchingSection extends StatelessWidget {
  const ContinueWatchingSection({super.key, required this.historyService});

  final PlaybackHistoryService historyService;

  @override
  Widget build(BuildContext context) {
    final history = historyService.getHistory();
    if (history.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Header(title: 'Continue Watching'),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: history.length,
            itemBuilder: (context, index) {
              final entry = history[index];
              return TvFocusable(
                onPressed: () => context.push('/player', extra: entry.toPlaybackRequest()),
                child: Container(
                  width: 110,
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: Styles(context: context).cardBoxDecoration.copyWith(
                                image: (entry.posterPath ?? '').trim().isNotEmpty
                                    ? DecorationImage(
                                        image: ExtendedNetworkImageProvider(UrlStrings.imageUrl + entry.posterPath!, cache: true, printError: false),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                          child: Stack(
                            children: [
                              const Align(
                                alignment: Alignment.center,
                                child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 32),
                              ),
                              if (entry.mediaType == PlaybackMediaType.tv && entry.seasonNumber != null)
                                Positioned(
                                  left: 4,
                                  bottom: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                                    child: Text(
                                      'S${entry.seasonNumber}E${entry.episodeNumber}',
                                      style: const TextStyle(color: Colors.white, fontSize: 10),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
