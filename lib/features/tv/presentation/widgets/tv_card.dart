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
  const TvCard({super.key, required this.show, this.aspectRatio = 10 / 16, this.autofocus = false});

  final TvModel show;
  final double aspectRatio;
  final bool autofocus;

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
                  _TvFavouriteBadge(show: show),
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

/// Compact save toggle in the poster's top-right corner, matching the movie
/// card's bookmark badge. TV shows use the shared [FavouriteService] (which
/// already backs the TV details heart) rather than the movie-only bookmarks
/// feature, so saving from a card and from the details screen stay in sync.
class _TvFavouriteBadge extends StatefulWidget {
  const _TvFavouriteBadge({required this.show});

  final TvModel show;

  @override
  State<_TvFavouriteBadge> createState() => _TvFavouriteBadgeState();
}

class _TvFavouriteBadgeState extends State<_TvFavouriteBadge> {
  late bool _isFavourite = sl<FavouriteService>().isFavourite(PlaybackMediaType.tv, widget.show.id);

  Future<void> _toggle() async {
    await sl<FavouriteService>().toggleFavourite(
      FavouriteEntry(
        tmdbId: widget.show.id,
        mediaType: PlaybackMediaType.tv,
        title: widget.show.name,
        posterPath: widget.show.posterPath,
      ),
    );
    if (!mounted) return;
    setState(() => _isFavourite = !_isFavourite);
    HelperFunctions.showSnackBar(context, _isFavourite ? 'Added to favourites' : 'Removed from favourites');
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
              _isFavourite ? Icons.favorite : Icons.favorite_border,
              color: _isFavourite ? ZipxUi.red : Colors.white,
              size: 16,
            ),
          ),
        ),
      ),
    );
  }
}
