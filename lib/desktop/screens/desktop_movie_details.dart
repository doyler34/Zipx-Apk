import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../common/styles/zipx_ui.dart';
import '../../common/widgets/movie/mark_widget.dart';
import '../../common/widgets/movie/movie_card.dart';
import '../../common/widgets/youtube_player/trailer_preview.dart';
import '../../core/dependency_injection/di.dart';
import '../../core/playback/domain/entities/playback_media_type.dart';
import '../../core/playback/domain/entities/playback_request.dart';
import '../../core/utils/strings/url_strings.dart';
import '../../features/movies/data/models/actor_model.dart';
import '../../features/movies/data/models/movie_model.dart';
import '../../features/movies/data/models/reviews_result_model.dart';
import '../../features/movies/presentation/blocs/details/details/details_bloc.dart';
import '../widgets/hover_scale.dart';
import '../widgets/h_scroll_row.dart';

/// Desktop movie details: a full-width backdrop banner, then the poster beside
/// the title/meta/overview and actions, then the full detail set - facts, cast,
/// trailer, "More Like This" and reviews. Renders instantly from the tapped
/// [movie] and enriches with everything else once [DetailsBloc] loads.
class DesktopMovieDetails extends StatelessWidget {
  const DesktopMovieDetails({super.key, required this.movie});

  final MovieModel movie;

  static String _backdrop(String path) => 'https://image.tmdb.org/t/p/w1280$path';

  static const double _pad = 48;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<DetailsBloc>()..add(GetMovieDetailsEvent(movie.id)),
      child: Scaffold(
        backgroundColor: ZipxUi.bg,
        body: BlocBuilder<DetailsBloc, DetailsState>(
          builder: (context, state) {
            final loaded = state is DetailsLoaded ? state : null;
            final genres =
                loaded?.details.genres.map((g) => g.name).where((n) => n.trim().isNotEmpty).take(3).toList() ?? const <String>[];
            final runtime = loaded?.details.runtime ?? 0;
            final budget = loaded?.details.budget ?? -1;
            final language = loaded?.details.originalLanguage ?? '';
            final actors = loaded?.details.actors ?? const <ActorModel>[];
            final similar = loaded?.similar.movies
                    ?.where((m) => m.posterPath.trim().isNotEmpty && m.id != movie.id)
                    .toList() ??
                const <MovieModel>[];
            final reviews = loaded?.details.reviews;
            final trailer = _trailerKey(loaded);

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _banner(context),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(_pad, 0, _pad, 8),
                    child: _info(context, genres: genres, runtime: runtime),
                  ),
                  _Facts(
                    year: movie.releaseDate.length >= 4 ? movie.releaseDate.substring(0, 4) : '',
                    runtime: runtime,
                    language: language,
                    budget: budget,
                    rating: movie.voteAverage,
                  ),
                  if (actors.isNotEmpty) _Cast(actors: actors),
                  if (trailer != null) _Trailer(videoId: trailer),
                  if (similar.isNotEmpty) _MoreLikeThis(movies: similar),
                  if (reviews != null && reviews.reviews.isNotEmpty)
                    _Reviews(reviews: reviews, movieId: movie.id.toString()),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String? _trailerKey(DetailsLoaded? loaded) {
    if (loaded == null) return null;
    for (final v in loaded.details.videos) {
      if (v.type == 'Trailer' && v.site == 'YouTube' && v.key.trim().isNotEmpty) return v.key;
    }
    return null;
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

/// A compact quick-facts strip (rating / year / runtime / language / budget),
/// each as a labelled pill. Skips anything the API didn't supply.
class _Facts extends StatelessWidget {
  const _Facts({
    required this.year,
    required this.runtime,
    required this.language,
    required this.budget,
    required this.rating,
  });

  final String year;
  final int runtime;
  final String language;
  final int budget;
  final double rating;

  @override
  Widget build(BuildContext context) {
    final facts = <(String, String)>[
      if (rating > 0) ('Rating', '${rating.toStringAsFixed(1)} / 10'),
      if (year.isNotEmpty) ('Year', year),
      if (runtime > 0) ('Runtime', '${runtime ~/ 60}h ${runtime % 60}m'),
      if (language.trim().isNotEmpty && language.trim().toUpperCase() != 'UNKNOWN') ('Language', language.toUpperCase()),
      if (budget > 0) ('Budget', _money(budget)),
    ];
    if (facts.isEmpty) return const SizedBox.shrink();
    return Transform.translate(
      offset: const Offset(0, -44),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DesktopMovieDetails._pad),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [for (final f in facts) _pill(f.$1, f.$2)],
        ),
      ),
    );
  }

  Widget _pill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: ZipxUi.surface, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(color: ZipxUi.textMuted, fontSize: 10, letterSpacing: 1)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  static String _money(int v) {
    if (v >= 1000000000) return '\$${(v / 1000000000).toStringAsFixed(1)}B';
    if (v >= 1000000) return '\$${(v / 1000000).toStringAsFixed(0)}M';
    if (v >= 1000) return '\$${(v / 1000).toStringAsFixed(0)}K';
    return '\$$v';
  }
}

/// Horizontal cast row with circular headshots, name and character.
class _Cast extends StatelessWidget {
  const _Cast({required this.actors});

  final List<ActorModel> actors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Cast'),
        HScrollRow(
          height: 176,
          padding: const EdgeInsets.symmetric(horizontal: DesktopMovieDetails._pad - 4),
          itemCount: actors.length,
          itemBuilder: (context, i) {
              final a = actors[i];
              return Container(
                width: 104,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  children: [
                    ClipOval(
                      child: SizedBox(
                        width: 88,
                        height: 88,
                        child: a.profilePath.trim().isEmpty
                            ? Container(
                                color: ZipxUi.surfaceHigh,
                                child: const Icon(Icons.person, color: Colors.white24, size: 34),
                              )
                            : ExtendedImage.network(UrlStrings.imageUrl + a.profilePath, fit: BoxFit.cover, cache: true, printError: false),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(a.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    if (a.character.trim().isNotEmpty)
                      Text(a.character,
                          maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                          style: const TextStyle(color: ZipxUi.textMuted, fontSize: 11)),
                  ],
                ),
              );
            },
        ),
      ],
    );
  }
}

/// Embedded YouTube trailer, width-constrained so it doesn't stretch across the
/// whole desktop window.
class _Trailer extends StatelessWidget {
  const _Trailer({required this.videoId});

  final String videoId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Trailer'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DesktopMovieDetails._pad),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: TrailerPreview(videoId: videoId),
            ),
          ),
        ),
      ],
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
        const _SectionTitle('More Like This'),
        HScrollRow(
          height: 360,
          padding: const EdgeInsets.symmetric(horizontal: DesktopMovieDetails._pad - 4),
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

/// Up to three reviews as cards, with a "See all" link when there are more.
class _Reviews extends StatelessWidget {
  const _Reviews({required this.reviews, required this.movieId});

  final ReviewsResultModel reviews;
  final String movieId;

  @override
  Widget build(BuildContext context) {
    final shown = reviews.reviews.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Reviews', onSeeAll: reviews.reviews.length > 3 ? () => context.push('/reviews/$movieId') : null),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DesktopMovieDetails._pad),
          child: Column(children: [for (final r in shown) _card(r)]),
        ),
      ],
    );
  }

  Widget _card(dynamic r) {
    final initial = (r.author as String).trim().isNotEmpty ? (r.author as String).trim()[0].toUpperCase() : '?';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: ZipxUi.surface, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: ZipxUi.surfaceHigh,
                child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(r.author as String,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
              if ((r.rating as num) > 0) ...[
                const Icon(Icons.star_rounded, color: ZipxUi.red, size: 18),
                const SizedBox(width: 3),
                Text('${r.rating}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(r.content as String,
              maxLines: 5, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }
}

/// Shared section header ("Cast", "Trailer", …) with an optional "See all".
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.onSeeAll});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(DesktopMovieDetails._pad, 26, DesktopMovieDetails._pad, 12),
      child: Row(
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w700)),
          const Spacer(),
          if (onSeeAll != null)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onSeeAll,
                child: const Text('See all', style: TextStyle(color: ZipxUi.red, fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
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
