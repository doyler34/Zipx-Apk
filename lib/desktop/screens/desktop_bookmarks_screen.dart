import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../common/styles/zipx_ui.dart';
import '../../core/dependency_injection/di.dart';
import '../../core/playback/domain/entities/playback_media_type.dart';
import '../../core/playback/services/favourite_service.dart';
import '../../features/movies/data/models/movie_model.dart';
import '../../features/personalization/presentation/blocs/bookmarks/bookmarks_bloc.dart';
import '../../features/personalization/presentation/blocs/settings/settings_bloc.dart';
import '../../features/personalization/presentation/widgets/bookmarks/bookmark_card.dart';
import '../../features/tv/data/models/tv_model.dart';
import '../../features/tv/presentation/widgets/tv_card.dart';
import '../widgets/hover_scale.dart';

/// Desktop Watchlist: the saved TV Shows and Movies in a wide, hover-aware poster
/// grid. Same data as the phone screen ([FavouriteService] for TV, [BookmarksBloc]
/// for movies) - just the desktop layout.
class DesktopBookmarksScreen extends StatefulWidget {
  const DesktopBookmarksScreen({super.key});

  @override
  State<DesktopBookmarksScreen> createState() => _DesktopBookmarksScreenState();
}

class _DesktopBookmarksScreenState extends State<DesktopBookmarksScreen> {
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
    return SafeArea(
      left: false,
      child: BlocBuilder<BookmarksBloc, BookmarksState>(
        bloc: context.read<BookmarksBloc>(),
        builder: (context, state) {
          final List<MovieModel> movies = context.read<BookmarksBloc>().bookmarks;
          final tvShows = _tvBookmarks();

          if (movies.isEmpty && tvShows.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bookmark_border_rounded, color: Colors.white24, size: 60),
                  SizedBox(height: 14),
                  Text('Your watchlist is empty', style: TextStyle(color: ZipxUi.textMuted, fontSize: 16)),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(48, 24, 48, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (tvShows.isNotEmpty) ...[
                  _header('TV Shows'),
                  _grid([for (final show in tvShows.reversed) HoverScale(child: TvCard(show: show))]),
                ],
                if (movies.isNotEmpty) ...[
                  if (tvShows.isNotEmpty) const SizedBox(height: 28),
                  _header('Movies'),
                  BlocBuilder<SettingsBloc, SettingsState>(
                    builder: (context, s) {
                      final showAdult = s is SettingsChanged && s.showAdultContent;
                      final shown = showAdult ? movies : movies.where((m) => !m.adult).toList();
                      return _grid([for (final movie in shown.reversed) HoverScale(child: BookmarkCard(movie: movie))]);
                    },
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
      );

  Widget _grid(List<Widget> cards) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          childAspectRatio: 0.58,
          crossAxisSpacing: 18,
          mainAxisSpacing: 18,
        ),
        itemCount: cards.length,
        itemBuilder: (context, i) => cards[i],
      );
}
