import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../common/styles/zipx_ui.dart';
import '../../common/widgets/movie/mark_widget.dart';
import '../../common/widgets/movie/movie_card.dart';
import '../../core/dependency_injection/di.dart';
import '../../core/playback/domain/entities/playback_media_type.dart';
import '../../core/playback/domain/entities/playback_request.dart';
import '../../core/utils/strings/url_strings.dart';
import '../../features/movies/data/models/movie_model.dart';
import '../../features/movies/presentation/blocs/details/details/details_bloc.dart';
import '../widgets/hover_scale.dart';

/// Desktop movie details: a full-width backdrop banner, then the poster beside
/// the title/meta/overview and actions, then a "More Like This" row. Renders
/// instantly from the tapped [movie] and enriches with genres/runtime/similar
/// once [DetailsBloc] loads.
class DesktopMovieDetails extends StatelessWidget {
  const DesktopMovieDetails({super.key, required this.movie});

  final MovieModel movie;

  static String _backdrop(String path) => 'https://image.tmdb.org/t/p/w1280$path';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<DetailsBloc>()..add(GetMovieDetailsEvent(movie.id)),
      child: Scaffold(
        backgroundColor: ZipxUi.bg,
        body: BlocBuilder<DetailsBloc, DetailsState>(
          builder: (context, state) {
            final loaded = state is DetailsLoaded ? state : null;
            final genres = loaded?.details.genres.map((g) => g.name).where((n) => n.trim().isNotEmpty).take(3).toList() ?? const <String>[];
            final runtime = loaded?.details.runtime ?? 0;
            final similar = loaded?.similar.movies
                    ?.where((m) => m.posterPath.trim().isNotEmpty && m.id != movie.id)
                    .toList() ??
                const <MovieModel>[];

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _banner(context),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(48, 0, 48, 8),
                    child: _info(context, genres: genres, runtime: runtime),
                  ),
                  if (similar.isNotEmpty) _MoreLikeThis(movies: similar),
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _banner(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final height = (c.maxWidth * 0.38).clamp(320.0, 480.0);
        return SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (movie.backdropPath.trim().isNotEmpty)
                ExtendedImage.network(_backdrop(movie.backdropPath), fit: BoxFit.cover, cache: true, printError: false)
              else
                const ColoredBox(color: ZipxUi.surface),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [ZipxUi.bg, Colors.transparent, Color(0x330A0A0C)],
                  ),
                ),
              ),
              Positioned(
                top: 16,
                left: 16,
                child: _CircleButton(icon: Icons.arrow_back, onTap: () => context.pop()),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _info(BuildContext context, {required List<String> genres, required int runtime}) {
    final year = movie.releaseDate.length >= 4 ? movie.releaseDate.substring(0, 4) : '';
    final meta = <String>[
      if (year.isNotEmpty) year,
      if (runtime > 0) '${runtime ~/ 60}h ${runtime % 60}m',
      ...genres,
    ];
    return Transform.translate(
      offset: const Offset(0, -64),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poster.
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 200,
              height: 300,
              child: movie.posterPath.trim().isEmpty
                  ? const ColoredBox(color: ZipxUi.surface, child: Icon(Icons.movie, color: Colors.white24))
                  : ExtendedImage.network(UrlStrings.imageUrl + movie.posterPath, fit: BoxFit.cover, cache: true, printError: false),
            ),
          ),
          const SizedBox(width: 28),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 84),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(movie.title,
                      style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800, height: 1.1)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: ZipxUi.red, size: 20),
                      const SizedBox(width: 4),
                      Text(movie.voteAverage.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(meta.join('  ·  '),
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ZipxUi.textMuted)),
                        ),
                      ],
                    ],
                  ),
                  if (movie.overview.trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Text(movie.overview,
                          style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.5)),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      _ActionButton(
                        icon: Icons.play_arrow_rounded,
                        label: 'Play',
                        filled: true,
                        onTap: () => context.push(
                          '/player',
                          extra: PlaybackRequest(
                            tmdbId: movie.id,
                            mediaType: PlaybackMediaType.movie,
                            title: movie.title,
                            posterPath: movie.posterPath,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      MarkWidget(movie: movie, align: false),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreLikeThis extends StatelessWidget {
  const _MoreLikeThis({required this.movies});

  final List<MovieModel> movies;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(48, 4, 48, 10),
          child: Text('More Like This', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w700)),
        ),
        SizedBox(
          height: 360,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 44),
            itemCount: movies.length,
            itemBuilder: (context, i) => SizedBox(
              width: 215,
              child: HoverScale(child: MovieCard(movie: movies[i], isHomePage: true)),
            ),
          ),
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x99000000)),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.filled, required this.onTap});

  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
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
      ),
    );
  }
}
