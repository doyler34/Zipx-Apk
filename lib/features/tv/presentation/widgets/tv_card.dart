import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../../common/styles/zipx_ui.dart';
import '../../../../common/widgets/tv/tv_focusable.dart';
import '../../../../common/widgets/movie/vote_avg_widget.dart';
import '../../../../core/dependency_injection/di.dart';
import '../../../../core/playback/domain/entities/favourite_entry.dart';
import '../../../../core/playback/domain/entities/playback_media_type.dart';
import '../../../../core/playback/services/favourite_service.dart';
import '../../../../core/utils/helpers/helper_functions.dart';
import '../../../../core/utils/strings/url_strings.dart';
import '../../data/models/tv_model.dart';

class TvCard extends StatelessWidget {
  const TvCard({super.key, required this.show, this.aspectRatio = 10 / 16, this.autofocus = false, this.isAnime = false});

  final TvModel show;
  final double aspectRatio;
  final bool autofocus;

  /// Anime series bookmark into their own store, separate from regular TV
  /// Shows bookmarks - see [_TvBookmarkBadge].
  final bool isAnime;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      autofocus: autofocus,
      onPressed: () => context.push('/tv/${show.id}', extra: show),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              decoration: BoxDecoration(
                color: ZipxUi.surface,
                image: show.posterPath.trim() != ''
                    ? DecorationImage(
                        image: ExtendedNetworkImageProvider(UrlStrings.imageUrl + show.posterPath, cache: true, printError: false),
                        fit: BoxFit.cover,
                        onError: (_, __) {},
                      )
                    : null,
              ),
              child: Stack(
                children: [
                  if (show.posterPath.trim() == '') const Center(child: FaIcon(FontAwesomeIcons.tv, color: Colors.white24, size: 40)),
                  _TvBookmarkBadge(show: show, isAnime: isAnime),
                  VoteAvgWidget(voteAvg: show.voteAverage, alignment: Alignment.bottomRight),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact bookmark toggle in the poster's top-right corner, matching the
/// movie card's bookmark badge. TV bookmarks are stored via [FavouriteService]
/// - regular shows in the shared TV store (surfaced in the Bookmarks tab's TV
/// Shows section), anime series in their own separate store ([isAnime]),
/// surfaced in the Bookmarks tab's Anime section instead.
class _TvBookmarkBadge extends StatefulWidget {
  const _TvBookmarkBadge({required this.show, this.isAnime = false});

  final TvModel show;
  final bool isAnime;

  @override
  State<_TvBookmarkBadge> createState() => _TvBookmarkBadgeState();
}

class _TvBookmarkBadgeState extends State<_TvBookmarkBadge> {
  late bool _isBookmarked = sl<FavouriteService>().isFavourite(PlaybackMediaType.tv, widget.show.id, isAnime: widget.isAnime);

  Future<void> _toggle() async {
    await sl<FavouriteService>().toggleFavourite(
      FavouriteEntry(
        tmdbId: widget.show.id,
        mediaType: PlaybackMediaType.tv,
        title: widget.show.name,
        posterPath: widget.show.posterPath,
        isAnime: widget.isAnime,
      ),
    );
    if (!mounted) return;
    setState(() => _isBookmarked = !_isBookmarked);
    HelperFunctions.showSnackBar(context, _isBookmarked ? 'Added to bookmarks' : 'Removed from bookmarks');
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: GestureDetector(
          onTap: _toggle,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 0.5),
            ),
            child: Icon(
              _isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: _isBookmarked ? ZipxUi.red : Colors.white,
              size: 17,
            ),
          ),
        ),
      ),
    );
  }
}
