import 'package:animate_do/animate_do.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../../common/styles/zipx_ui.dart';
import '../../../../common/widgets/movie/adult_widget.dart';
import '../../../../common/widgets/movie/vote_avg_widget.dart';
import '../../../../core/dependency_injection/di.dart';
import '../../../../core/playback/domain/entities/favourite_entry.dart';
import '../../../../core/playback/domain/entities/playback_media_type.dart';
import '../../../../core/playback/services/favourite_service.dart';
import '../../../../core/utils/helpers/helper_functions.dart';
import '../../../../core/utils/strings/url_strings.dart';
import '../../../movies/data/models/movie_model.dart';

/// Anime movie poster card, matching [BookmarkCard]'s look but bookmarking
/// into [FavouriteService]'s separate anime store instead of the regular
/// movie-only `BookmarksBloc`, so anime movies don't mix into the Movies
/// watchlist.
class AnimeMovieCard extends StatelessWidget {
  const AnimeMovieCard({super.key, required this.movie});

  final MovieModel movie;

  @override
  Widget build(BuildContext context) {
    return FadeIn(
      child: Stack(
        children: [
          GestureDetector(
            onTap: () {
              context.push('/details/${movie.id}', extra: movie);
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                decoration: BoxDecoration(
                  color: ZipxUi.surface,
                  image: movie.posterPath.trim() != ''
                      ? DecorationImage(
                          image: ExtendedNetworkImageProvider(UrlStrings.imageUrl + movie.posterPath, cache: true, printError: false),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: movie.posterPath.trim() == '' ? const Center(child: FaIcon(FontAwesomeIcons.film, color: Colors.white24, size: 40)) : null,
              ),
            ),
          ),
          _AnimeMovieBookmarkBadge(movie: movie),
          VoteAvgWidget(voteAvg: movie.voteAverage, alignment: Alignment.bottomRight, width: 30, height: 30),
          if (movie.adult) const AdultWidget(width: 30, height: 30),
        ],
      ),
    );
  }
}

/// App-bar-style bookmark toggle for the movie details screen, used instead
/// of the regular [MarkWidget] when the movie is anime (see
/// `MovieModel.isAnimation`) so the toggle there stays in sync with the same
/// separate anime store [AnimeMovieCard]'s badge uses.
class AnimeMovieBookmarkToggle extends StatefulWidget {
  const AnimeMovieBookmarkToggle({super.key, required this.movie});

  final MovieModel movie;

  @override
  State<AnimeMovieBookmarkToggle> createState() => _AnimeMovieBookmarkToggleState();
}

class _AnimeMovieBookmarkToggleState extends State<AnimeMovieBookmarkToggle> {
  late bool _isBookmarked = sl<FavouriteService>().isFavourite(PlaybackMediaType.movie, widget.movie.id, isAnime: true);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        _isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
        color: _isBookmarked ? ZipxUi.red : Colors.white,
      ),
      onPressed: () async {
        await sl<FavouriteService>().toggleFavourite(
          FavouriteEntry(
            tmdbId: widget.movie.id,
            mediaType: PlaybackMediaType.movie,
            title: widget.movie.title,
            posterPath: widget.movie.posterPath,
            isAnime: true,
          ),
        );
        setState(() => _isBookmarked = !_isBookmarked);
      },
    );
  }
}

class _AnimeMovieBookmarkBadge extends StatefulWidget {
  const _AnimeMovieBookmarkBadge({required this.movie});

  final MovieModel movie;

  @override
  State<_AnimeMovieBookmarkBadge> createState() => _AnimeMovieBookmarkBadgeState();
}

class _AnimeMovieBookmarkBadgeState extends State<_AnimeMovieBookmarkBadge> {
  late bool _isBookmarked = sl<FavouriteService>().isFavourite(PlaybackMediaType.movie, widget.movie.id, isAnime: true);

  Future<void> _toggle() async {
    await sl<FavouriteService>().toggleFavourite(
      FavouriteEntry(
        tmdbId: widget.movie.id,
        mediaType: PlaybackMediaType.movie,
        title: widget.movie.title,
        posterPath: widget.movie.posterPath,
        isAnime: true,
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
