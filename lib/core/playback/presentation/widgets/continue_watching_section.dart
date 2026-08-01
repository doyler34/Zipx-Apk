import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../common/styles/zipx_ui.dart';
import '../../../../common/widgets/tv/tv_focusable.dart';
import '../../../../core/utils/strings/url_strings.dart';
import '../../domain/entities/playback_media_type.dart';
import '../../services/playback_history_service.dart';

/// "Continue Watching" row, backed by [PlaybackHistoryService]. Restyled to
/// the ZIPX mockup: wide landscape cards with a play overlay, title and (for
/// TV) the last SxEx. Tapping resumes straight into the player.
///
/// Note: real resume progress isn't tracked yet (history only records that a
/// title was started), so the mockup's progress bar / "Xm left" is
/// intentionally omitted rather than faked.
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
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Text(
            'Continue Watching',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 176,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: history.length,
            itemBuilder: (context, index) {
              final entry = history[index];
              final isTv = entry.mediaType == PlaybackMediaType.tv && entry.seasonNumber != null;
              final poster = (entry.posterPath ?? '').trim();

              return TvFocusable(
                onPressed: () => context.push('/player', extra: entry.toPlaybackRequest()),
                child: Container(
                  width: 208,
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (poster.isNotEmpty)
                                Image(
                                  image: ExtendedNetworkImageProvider(UrlStrings.imageUrl + poster, cache: true, printError: false),
                                  fit: BoxFit.cover,
                                )
                              else
                                Container(color: ZipxUi.surface),
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, Color(0x99000000)],
                                  ),
                                ),
                              ),
                              const Center(
                                child: Icon(Icons.play_circle_fill, color: Colors.white, size: 40),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isTv ? 'S${entry.seasonNumber} E${entry.episodeNumber}' : 'Movie',
                        style: const TextStyle(color: ZipxUi.textMuted, fontSize: 12),
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
