import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import '../../../../../common/styles/styles.dart';
import '../../../../../common/widgets/texts/centered_message.dart';
import '../../../../../core/dependency_injection/di.dart';
import '../../../../../core/playback/domain/entities/playback_media_type.dart';
import '../../../../../core/playback/domain/entities/playback_request.dart';
import '../../../../../core/utils/strings/url_strings.dart';
import '../../../../tv/presentation/widgets/tv_poster_card.dart';
import '../../../../tv/presentation/widgets/tv_row.dart';
import '../../../data/models/movie_model.dart';
import '../../blocs/details/details/details_bloc.dart';

/// Dedicated 10-foot movie details screen used only on TV. Poster on the
/// left, info + Watch Now on the right, similar movies row below - all
/// D-pad navigable. Replaces the phone details layout on TV.
class DetailsTvScreen extends StatelessWidget {
  const DetailsTvScreen({super.key, required this.movie});

  final MovieModel movie;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<DetailsBloc>()..add(GetMovieDetailsEvent(movie.id)),
      child: Scaffold(
        body: SafeArea(
          child: BlocBuilder<DetailsBloc, DetailsState>(
            builder: (context, state) {
              if (state is DetailsError) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CenteredMessage(message: state.message),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      autofocus: true,
                      onPressed: () => context.read<DetailsBloc>().add(GetMovieDetailsEvent(movie.id)),
                      child: const Text('Retry'),
                    ),
                  ],
                );
              }
              if (state is! DetailsLoaded) {
                return Center(child: LoadingAnimationWidget.beat(color: Theme.of(context).colorScheme.tertiary, size: 50));
              }
              return _Content(movie: movie, state: state);
            },
          ),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.movie, required this.state});

  final MovieModel movie;
  final DetailsLoaded state;

  @override
  Widget build(BuildContext context) {
    final details = state.details;
    final meta = <String>[
      if (movie.releaseDate.trim().isNotEmpty) movie.releaseDate.split('-').first,
      if (details.runtime > 0) '${details.runtime} min',
      if (details.originalLanguage.trim().isNotEmpty && details.originalLanguage != 'UNKNOWN') details.originalLanguage.toUpperCase(),
      if (movie.voteAverage > 0) '★ ${movie.voteAverage.toStringAsFixed(1)}',
    ];
    final similar = (state.similar.movies ?? const <MovieModel>[]);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 200,
                height: 300,
                child: Container(
                  decoration: Styles(context: context).cardBoxDecoration.copyWith(
                        image: movie.posterPath.trim().isNotEmpty
                            ? DecorationImage(
                                image: ExtendedNetworkImageProvider(UrlStrings.imageUrl + movie.posterPath, cache: true, printError: false),
                                fit: BoxFit.cover,
                                onError: (_, __) {},
                              )
                            : null,
                      ),
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie.title,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(meta.join('  •  '), style: const TextStyle(color: Colors.white70, fontSize: 15)),
                    ],
                    if (details.genres.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(details.genres.map((g) => g.name).join(', '), style: const TextStyle(color: Colors.white54, fontSize: 14)),
                    ],
                    if (movie.overview.trim().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(movie.overview, style: const TextStyle(color: Colors.white, height: 1.4), maxLines: 6, overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        autofocus: true,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.tertiary,
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                        ),
                        onPressed: () {
                          context.push(
                            '/player',
                            extra: PlaybackRequest(
                              tmdbId: movie.id,
                              mediaType: PlaybackMediaType.movie,
                              title: movie.title,
                              posterPath: movie.posterPath,
                            ),
                          );
                        },
                        icon: const Icon(Icons.play_arrow, color: Colors.white),
                        label: const Text('Watch Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TvRow(
            title: 'Similar Movies',
            cards: [
              for (final m in similar)
                TvPosterCard(
                  posterPath: m.posterPath,
                  voteAverage: m.voteAverage,
                  onPressed: () => context.pushReplacement('/details/${m.id}', extra: m),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
