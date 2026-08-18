import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../common/styles/zipx_ui.dart';
import '../../common/widgets/movie/movie_card.dart';
import '../widgets/hover_scale.dart';
import '../widgets/h_scroll_row.dart';
import '../../common/widgets/tv/tv_focusable.dart';
import '../../core/platform/tv.dart';
import '../../core/playback/domain/entities/playback_media_type.dart';
import '../../core/playback/domain/entities/playback_request.dart';
import '../../features/movies/data/models/movie_model.dart';
import '../../features/movies/data/models/movies_result_model.dart';
import '../../features/movies/presentation/blocs/home/home/home_bloc.dart';
import '../../features/personalization/presentation/blocs/bookmarks/bookmarks_bloc.dart';
import '../../features/personalization/presentation/blocs/settings/settings_bloc.dart';

/// Desktop Home: a cinematic backdrop hero plus horizontal poster rows, wired
/// to the real [HomeBloc]. Reuses [MovieCard] so posters, rating badges and
/// bookmark toggles are identical to the phone app.
class DesktopHomeScreen extends StatelessWidget {
  const DesktopHomeScreen({super.key});

  static String _backdrop(String path) => 'https://image.tmdb.org/t/p/w1280$path';

  List<MovieModel> _filter(MoviesResultModel result, bool showAdult) {
    final movies = result.movies ?? const <MovieModel>[];
    final visible = showAdult ? movies : movies.where((m) => !m.adult).toList();
    // Drop posterless entries, same rule as the rest of the app.
    return visible.where((m) => m.posterPath.trim().isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, settings) {
        final showAdult = settings is SettingsChanged && settings.showAdultContent;
        return BlocBuilder<HomeBloc, HomeState>(
          builder: (context, state) {
            if (state is HomeInitial) {
              context.read<HomeBloc>().add(LoadHome());
              context.read<BookmarksBloc>().add(LoadBookmarks());
              return const Center(child: CircularProgressIndicator(color: ZipxUi.red));
            }
            if (state is HomeLoading) {
              return const Center(child: CircularProgressIndicator(color: ZipxUi.red));
            }
            if (state is HomeError) {
              return Center(child: Text(state.message, style: const TextStyle(color: Colors.white70)));
            }
            if (state is HomeLoaded) {
              final trending = _filter(state.trendingMovies, showAdult);
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (trending.isNotEmpty) _Hero(movie: trending.first),
                    const SizedBox(height: 12),
                    _Row(title: 'Trending Now', movies: trending),
                    _Row(title: 'Top Rated', movies: _filter(state.topRatedMovies, showAdult)),
                    _Row(title: 'Popular', movies: _filter(state.popularMovies, showAdult)),
                    // Broad, well-established genres - deep catalogues, much
                    // better availability than the new-release rows (Upcoming/
                    // Now Playing) that used to be here.
                    for (final section in state.genreSections)
                      _Row(
                        title: '${section.$1} Movies',
                        movies: _filter(MoviesResultModel(movies: section.$2, totalPages: 1), showAdult),
                      ),
                    const SizedBox(height: 32),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          },
        );
      },
    );
  }
}

/// Full-width cinematic hero backed by the top trending title.
class _Hero extends StatelessWidget {
  const _Hero({required this.movie});

  final MovieModel movie;

  void _play(BuildContext context) {
    context.push(
      '/player',
      extra: PlaybackRequest(
        tmdbId: movie.id,
        mediaType: PlaybackMediaType.movie,
        title: movie.title,
        posterPath: movie.posterPath,
      ),
    );
  }

  void _moreInfo(BuildContext context) => context.push('/details/${movie.id}', extra: movie);

  @override
  Widget build(BuildContext context) {
    final year = movie.releaseDate.length >= 4 ? movie.releaseDate.substring(0, 4) : '';
    return LayoutBuilder(
      builder: (context, c) {
        final height = (c.maxWidth * 0.42).clamp(360.0, 560.0);
        return SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (movie.backdropPath.trim().isNotEmpty)
                ExtendedImage.network(
                  DesktopHomeScreen._backdrop(movie.backdropPath),
                  fit: BoxFit.cover,
                  cache: true,
                  printError: false,
                )
              else
                const ColoredBox(color: ZipxUi.surface),
              // Left-to-right + bottom scrims so text stays readable.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0xF20A0A0C), Color(0x660A0A0C), Colors.transparent],
                  ),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.center,
                    colors: [ZipxUi.bg, Colors.transparent],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(48, 0, 48, 44),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          movie.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w800, height: 1.05),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: ZipxUi.red, size: 20),
                            const SizedBox(width: 4),
                            Text(movie.voteAverage.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            if (year.isNotEmpty) ...[
                              const SizedBox(width: 12),
                              Text(year, style: const TextStyle(color: ZipxUi.textMuted)),
                            ],
                          ],
                        ),
                        if (movie.overview.trim().isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text(
                            movie.overview,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
                          ),
                        ],
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            _HeroButton(
                              icon: Icons.play_arrow_rounded,
                              label: 'Play',
                              filled: true,
                              autofocus: isAndroidTv, // land the remote here on open
                              onTap: () => _play(context),
                            ),
                            const SizedBox(width: 14),
                            _HeroButton(
                              icon: Icons.info_outline_rounded,
                              label: 'More Info',
                              filled: false,
                              onTap: () => _moreInfo(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeroButton extends StatelessWidget {
  const _HeroButton({required this.icon, required this.label, required this.filled, required this.onTap, this.autofocus = false});

  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      onPressed: onTap,
      autofocus: autofocus,
      borderRadius: 12,
      focusScale: 1.05,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
        decoration: BoxDecoration(
          color: filled ? ZipxUi.red : Colors.white10,
          borderRadius: BorderRadius.circular(12),
          border: filled ? null : Border.all(color: Colors.white24),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

/// A titled horizontal poster row built from reused [MovieCard]s.
class _Row extends StatelessWidget {
  const _Row({required this.title, required this.movies});

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
            child: HoverScale(child: MovieCard(movie: movies[i], isHomePage: true)),
          ),
        ),
      ],
    );
  }
}
