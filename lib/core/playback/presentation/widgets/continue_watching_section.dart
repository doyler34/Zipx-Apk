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
          height: 190,
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
                  width: 210,
                  margin: const EdgeInsets.only(right: 14),
                  decoration: BoxDecoration(
                    color: ZipxUi.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (poster.isNotEmpty)
                                Image(
                                  image: ExtendedNetworkImageProvider(UrlStrings.imageUrl + poster, cache: true, printError: false),
                                  fit: BoxFit.cover,
                                )
                              else
                                Container(color: ZipxUi.surfaceHigh),
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, Color(0x66000000)],
                                  ),
                                ),
                              ),
                              Center(
                                child: Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.35),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              isTv ? 'S${entry.seasonNumber} E${entry.episodeNumber}' : 'Movie',
                              style: const TextStyle(color: ZipxUi.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
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
