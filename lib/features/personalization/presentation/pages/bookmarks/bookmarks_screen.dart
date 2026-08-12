import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:movie_bloc_app/common/widgets/texts/centered_message.dart';
import 'package:movie_bloc_app/core/dependency_injection/di.dart';
import 'package:movie_bloc_app/core/playback/domain/entities/playback_media_type.dart';
import 'package:movie_bloc_app/core/playback/services/favourite_service.dart';
import 'package:movie_bloc_app/features/movies/data/models/movie_model.dart';
import 'package:movie_bloc_app/features/personalization/presentation/blocs/bookmarks/bookmarks_bloc.dart';
import 'package:movie_bloc_app/features/personalization/presentation/blocs/settings/settings_bloc.dart';
import 'package:movie_bloc_app/features/personalization/presentation/widgets/bookmarks/bookmark_card.dart';
import 'package:movie_bloc_app/features/tv/data/models/tv_model.dart';
import 'package:movie_bloc_app/features/tv/presentation/widgets/tv_card.dart';

/// Saved items, split into a TV Shows section (backed by [FavouriteService])
/// and a Movies section (backed by [BookmarksBloc]).
class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  // TV bookmarks are stored as lightweight entries; rebuild them into TvModels
  // so the shared TvCard renders them (and its badge can un-bookmark). Read on
  // build so the list reflects the latest saves each time the tab is shown.
  List<TvModel> _tvBookmarks() {
    return sl<FavouriteService>()
        .getFavourites()
        .where((e) => e.mediaType == PlaybackMediaType.tv)
        .map((e) => TvModel(
              id: e.tmdbId,
              name: e.title,
              overview: '',
              posterPath: e.posterPath ?? '',
              backdropPath: '',
              voteAverage: 0,
              firstAirDate: '',
            ))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BookmarksBloc, BookmarksState>(
          bloc: context.read<BookmarksBloc>(),
          builder: (context, state) {
            final List<MovieModel> movies = context.read<BookmarksBloc>().bookmarks;
            final tvShows = _tvBookmarks();

            if (movies.isEmpty && tvShows.isEmpty) {
              return const CenteredMessage(message: 'Your watchlist is empty');
            }

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (tvShows.isNotEmpty) ...[
                      _header('TV Shows'),
                      _grid([for (final show in tvShows.reversed) TvCard(show: show)]),
                    ],
                    if (movies.isNotEmpty) ...[
                      _header('Movies'),
                      BlocBuilder<SettingsBloc, SettingsState>(
                        builder: (context, s) {
                          final showAdult = s is SettingsChanged && s.showAdultContent;
                          final shown = showAdult ? movies : movies.where((m) => !m.adult).toList();
                          return _grid([for (final movie in shown.reversed) BookmarkCard(movie: movie)]);
                        },
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
    );
  }

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      );

  Widget _grid(List<Widget> cards) => GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 9 / 16,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        crossAxisCount: 3,
        children: cards,
      );
}
