import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../common/styles/zipx_ui.dart';
import '../../core/dependency_injection/di.dart';
import '../../features/anime/presentation/blocs/anime_home_cubit.dart';
import '../../features/movies/data/models/movie_model.dart';
import '../../features/personalization/presentation/widgets/bookmarks/bookmark_card.dart';
import '../../features/tv/data/models/tv_model.dart';
import '../../features/tv/presentation/widgets/tv_card.dart';
import '../widgets/hover_scale.dart';
import '../widgets/h_scroll_row.dart';

/// Desktop Anime: horizontal rows of anime movies + series, wired to
/// [AnimeHomeCubit]. Same shape as [DesktopTvScreen]'s rows, minus the hero
/// (anime is a smaller, secondary catalogue split out from Movies/TV).
class DesktopAnimeScreen extends StatelessWidget {
  const DesktopAnimeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<AnimeHomeCubit>()..loadHome(),
      child: BlocBuilder<AnimeHomeCubit, AnimeHomeState>(
        builder: (context, state) {
          if (state.isLoading && state.movies.isEmpty && state.series.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: ZipxUi.red));
          }
          if (state.errorMessage != null && state.movies.isEmpty && state.series.isEmpty) {
            return Center(child: Text(state.errorMessage!, style: const TextStyle(color: Colors.white70)));
          }
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                _MovieRow(title: 'Anime Movies', movies: state.movies),
                _TvRow(title: 'Anime Series', shows: state.series),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MovieRow extends StatelessWidget {
  const _MovieRow({required this.title, required this.movies});

  final String title;
  final List<MovieModel> movies;

  @override
  Widget build(BuildContext context) {
    if (movies.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(48, 20, 48, 10),
          child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w700)),
        ),
        HScrollRow(
          height: 360,
          padding: const EdgeInsets.symmetric(horizontal: 44),
          itemCount: movies.length,
          itemBuilder: (context, i) => SizedBox(
            width: 215,
            child: HoverScale(child: BookmarkCard(movie: movies[i])),
          ),
        ),
      ],
    );
  }
}

class _TvRow extends StatelessWidget {
  const _TvRow({required this.title, required this.shows});

  final String title;
  final List<TvModel> shows;

  @override
  Widget build(BuildContext context) {
    if (shows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(48, 20, 48, 10),
          child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w700)),
        ),
        HScrollRow(
          height: 360,
          padding: const EdgeInsets.symmetric(horizontal: 44),
          itemCount: shows.length,
          itemBuilder: (context, i) => SizedBox(
            width: 215,
            child: HoverScale(child: TvCard(show: shows[i])),
          ),
        ),
      ],
    );
  }
}
