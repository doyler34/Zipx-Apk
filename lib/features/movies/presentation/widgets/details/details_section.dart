import 'package:animate_do/animate_do.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:movie_bloc_app/common/responsive/responsive.dart';
import 'package:movie_bloc_app/common/widgets/movie/movies_section.dart';
import 'package:movie_bloc_app/features/movies/data/models/movie_model.dart';

import '../../../../../common/widgets/texts/centered_message.dart';
import '../../blocs/details/details/details_bloc.dart';
import 'movie_actors_section.dart';
import 'movie_genres_section.dart';
import 'movie_image_section.dart';
import 'movie_overview_section.dart';
import 'movie_production_companies_section.dart';
import 'movie_reviews_section.dart';
import 'movie_title_section.dart';
import 'movie_video_section.dart';
import 'movie_year_section.dart';
import 'watch_now_button.dart';

class DetailsSection extends StatelessWidget {
  const DetailsSection({super.key, required this.movie});

  final MovieModel movie;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder(
      bloc: context.read<DetailsBloc>(),
      builder: (context, state) {
        if (state is DetailsInitial) {
          return const CenteredMessage(message: 'Please wait...');
        } else if (state is DetailsLoading) {
          return const CenteredMessage(message: 'Loading...');
        } else if (state is DetailsError) {
          return FadeIn(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CenteredMessage(message: state.message),
                ElevatedButton(
                  onPressed: () => context.read<DetailsBloc>().add(GetMovieDetailsEvent(movie.id)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        } else if (state is DetailsLoaded) {
          String trailer = '';
          try {
            trailer = state.details.videos.firstWhere((video) => video.type == 'Trailer' && video.site == 'YouTube').key;
          } catch (e) {
            if (kDebugMode) print('No trailer available.');
          }

          final Widget body;
          if (Responsive.isDesktop(context)) {
            body = Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: Responsive.maxContentWidth),
                child: _desktopLayout(context, state, trailer),
              ),
            );
          } else {
            body = _mobileLayout(context, state, trailer);
          }

          return SingleChildScrollView(child: FadeIn(child: body));
        }
        return const SizedBox.shrink();
      },
    );
  }

  /// Original stacked phone layout - every section in one column.
  Widget _mobileLayout(BuildContext context, DetailsLoaded state, String trailer) {
    return Column(
      children: [
        MovieImageSection(movie: movie),
        WatchNowButton(movie: movie),
        if (movie.title.trim() != '') MovieTitleSection(title: movie.title),
        if (_hasFacts(state))
          MovieYearSection(
            year: movie.releaseDate,
            budget: state.details.budget,
            language: state.details.originalLanguage,
            runtime: state.details.runtime,
          ),
        if (movie.overview.trim().isNotEmpty) MovieOverviewSection(overview: movie.overview),
        if (state.details.genres.isNotEmpty) MovieGenresSection(genres: state.details.genres),
        if (state.details.actors.isNotEmpty) MovieActorsSection(actors: state.details.actors),
        if (state.details.productionCompanies.isNotEmpty) MovieProductionCompaniesSection(productionCompanies: state.details.productionCompanies),
        if (state.details.videos.isNotEmpty && trailer != '') MovieVideoSection(trailer: trailer),
        if (state.similar.movies!.isNotEmpty) MoviesSection(movies: state.similar.movies!, isSimilar: true, isMaxPage: state.isMaxPageSimilar),
        if (state.details.reviews.totalPages > 0) MovieReviewsSection(reviews: state.details.reviews, movieId: movie.id.toString()),
        SizedBox(height: MediaQuery.of(context).size.height * 0.05),
      ],
    );
  }

  /// Desktop layout: a full-width hero, then two columns - a narrow left rail
  /// (Watch Now + quick facts) and a wide right column (title, overview, cast,
  /// trailer, similar). Stops the metadata rendering as giant empty bars.
  Widget _desktopLayout(BuildContext context, DetailsLoaded state, String trailer) {
    final leftColumn = <Widget>[
      WatchNowButton(movie: movie),
      if (_hasFacts(state))
        MovieYearSection(
          year: movie.releaseDate,
          budget: state.details.budget,
          language: state.details.originalLanguage,
          runtime: state.details.runtime,
        ),
    ];

    final rightColumn = <Widget>[
      if (movie.title.trim() != '') MovieTitleSection(title: movie.title),
      if (movie.overview.trim().isNotEmpty) MovieOverviewSection(overview: movie.overview),
      if (state.details.genres.isNotEmpty) MovieGenresSection(genres: state.details.genres),
      if (state.details.actors.isNotEmpty) MovieActorsSection(actors: state.details.actors),
      if (state.details.productionCompanies.isNotEmpty) MovieProductionCompaniesSection(productionCompanies: state.details.productionCompanies),
      if (state.details.videos.isNotEmpty && trailer != '') MovieVideoSection(trailer: trailer),
      if (state.similar.movies!.isNotEmpty) MoviesSection(movies: state.similar.movies!, isSimilar: true, isMaxPage: state.isMaxPageSimilar),
      if (state.details.reviews.totalPages > 0) MovieReviewsSection(reviews: state.details.reviews, movieId: movie.id.toString()),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MovieImageSection(movie: movie),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 40),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 340,
                child: Column(mainAxisSize: MainAxisSize.min, children: leftColumn),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: rightColumn,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _hasFacts(DetailsLoaded state) =>
      movie.releaseDate.trim() != '' ||
      state.details.budget != -1 ||
      state.details.originalLanguage.trim() != 'UNKNOWN' ||
      state.details.runtime != -1;
}
