import 'package:animate_do/animate_do.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:movie_bloc_app/common/widgets/texts/centered_message.dart';
import 'package:movie_bloc_app/common/widgets/texts/header.dart';
import 'package:movie_bloc_app/features/movies/presentation/blocs/home/home/home_bloc.dart';
import 'package:movie_bloc_app/features/personalization/presentation/blocs/bookmarks/bookmarks_bloc.dart';
import 'package:movie_bloc_app/features/personalization/presentation/blocs/settings/settings_bloc.dart';

import '../../widgets/home/hero_carousel.dart';
import '../../widgets/home/movie_genres.dart';
import '../../../../../common/widgets/beta/beta_v1_popup.dart';
import '../../../../../common/widgets/movie/movies_section.dart';
import '../../../../../core/dependency_injection/di.dart';
import '../../../../../core/playback/presentation/widgets/continue_watching_section.dart';
import '../../../../../core/playback/services/playback_history_service.dart';
import '../../../data/models/movie_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Beta issue reports open the user's email app to this address.
  static const String _betaReportUrl = 'mailto:garethark@outlook.com?subject=Zipx%20Movies%20Beta%20V1%20Issue';

  @override
  void initState() {
    super.initState();
    // Show the Beta V1 popup once (throttled by BetaPopupService) after the
    // first frame, so it appears over the home screen right after launch.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) BetaV1Popup.showIfNeeded(context, reportUrl: _betaReportUrl);
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state2) {
        if (state2 is SettingsChanged) {
          return BlocBuilder(
            bloc: context.read<HomeBloc>(),
            builder: (context, state) {
              if (state is HomeInitial) {
                context.read<HomeBloc>().add(LoadHome());
                context.read<BookmarksBloc>().add(LoadBookmarks());
                return const CenteredMessage(message: 'Please wait...');
              } else if (state is HomeLoading) {
                return FadeIn(
                  child: CustomMaterialIndicator(
                    indicatorBuilder: (context, _) {
                      return LoadingAnimationWidget.beat(
                        color: Theme.of(context).colorScheme.primary,
                        size: 50,
                      );
                    },
                    onRefresh: () {
                      context.read<HomeBloc>().add(LoadHome());
                      return Future.delayed(const Duration(seconds: 1));
                    },
                    child: SingleChildScrollView(
                      child: SizedBox(
                        width: size.width,
                        height: size.height,
                        child: const CenteredMessage(message: 'Loading...'),
                      ),
                    ),
                  ),
                );
              } else if (state is HomeError) {
                return FadeIn(
                  child: CustomMaterialIndicator(
                    indicatorBuilder: (context, _) {
                      return LoadingAnimationWidget.beat(
                        color: Theme.of(context).colorScheme.primary,
                        size: 50,
                      );
                    },
                    onRefresh: () {
                      context.read<HomeBloc>().add(LoadHome());
                      return Future.delayed(const Duration(seconds: 1));
                    },
                    child: SingleChildScrollView(
                      child: SizedBox(
                        width: size.width,
                        height: size.height,
                        child: CenteredMessage(message: state.message),
                      ),
                    ),
                  ),
                );
              } else if (state is HomeLoaded) {
                final trending = state2.showAdultContent ? state.trendingMovies.movies! : state.trendingMovies.movies!.where((movie) => !movie.adult).toList();
                final topRated = state2.showAdultContent ? state.topRatedMovies.movies! : state.topRatedMovies.movies!.where((movie) => !movie.adult).toList();
                final popular = state2.showAdultContent ? state.popularMovies.movies! : state.popularMovies.movies!.where((movie) => !movie.adult).toList();
                List<MovieModel> cleanGenre(List<MovieModel> movies) =>
                    state2.showAdultContent ? movies : movies.where((movie) => !movie.adult).toList();
                // A row this thin (after adult-content filtering on top of
                // the availability/language filtering already applied
                // upstream) reads as broken rather than intentional - hide it
                // instead of showing a couple of posters trailing into empty
                // space. Matches the bar genre sections are already held to.
                const minRowSize = 6;
                return FadeIn(
                  child: CustomMaterialIndicator(
                    indicatorBuilder: (context, _) {
                      return LoadingAnimationWidget.beat(
                        color: Theme.of(context).colorScheme.primary,
                        size: 50,
                      );
                    },
                    onRefresh: () {
                      context.read<HomeBloc>().add(LoadHome());
                      return Future.delayed(const Duration(seconds: 1));
                    },
                    child: SafeArea(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            // Fewer than 3 titles isn't enough for a peeking
                            // carousel to feel intentional - the left/right
                            // slots would just repeat the same 1-2 posters.
                            HeroCarousel(movies: trending.length >= 3 ? trending : const []),
                            ContinueWatchingSection(historyService: sl<PlaybackHistoryService>()),
                            // Each row (header + section) only renders when it
                            // actually has titles - an availability fill that
                            // couldn't refill a row to any titles hides it
                            // instead of showing an empty header. Upcoming/Now
                            // Playing were dropped entirely (not just topped up
                            // deeper) - brand-new releases are genuinely thin on
                            // torrent availability once CAM/TS/SCR are excluded,
                            // so they were frequently just empty rows.
                            const Header(title: 'Movie Genres'),
                            MovieGenres(genres: state.genres),
                            if (topRated.length >= minRowSize) ...[
                              Header(
                                title: 'Top Rated Movies',
                                onTap: () {
                                  context.push('/all/top_rated', extra: 'Top Rated Movies');
                                },
                              ),
                              MoviesSection(movies: topRated, isHomePage: true),
                            ],
                            if (popular.length >= minRowSize) ...[
                              Header(
                                title: 'Popular Movies',
                                onTap: () {
                                  context.push('/all/popular', extra: 'Popular Movies');
                                },
                              ),
                              MoviesSection(movies: popular, isHomePage: true),
                            ],
                            // Broad, well-established genres - deep catalogues,
                            // much better availability than the new-release rows
                            // that used to be here.
                            for (final section in state.genreSections)
                              if (cleanGenre(section.$2).length >= minRowSize) ...[
                                Header(title: '${section.$1} Movies'),
                                MoviesSection(movies: cleanGenre(section.$2), isHomePage: true),
                              ],
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          );
        } else {
          return const SizedBox.shrink();
        }
      },
    );
  }
}
