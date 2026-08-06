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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Placeholder issue-report URL for the beta popup - replace with your own.
  static const String _betaReportUrl = 'https://github.com/doyler34/Zipx-Apk/issues/new';

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
                            HeroCarousel(movies: state2.showAdultContent ? state.trendingMovies.movies! : state.trendingMovies.movies!.where((movie) => !movie.adult).toList()),
                            ContinueWatchingSection(historyService: sl<PlaybackHistoryService>()),
                            Header(
                              title: 'Upcoming Movies',
                              onTap: () {
                                context.push('/all/upcoming', extra: 'Upcoming Movies');
                              },
                            ),
                            MoviesSection(
                              movies: state2.showAdultContent ? state.upcomingMovies.movies! : state.upcomingMovies.movies!.where((movie) => !movie.adult).toList(),
                              isHomePage: true,
                            ),
                            const Header(title: 'Movie Genres'),
                            MovieGenres(genres: state.genres),
                            Header(
                              title: 'Now Playing Movies',
                              onTap: () {
                                context.push('/all/now_playing', extra: 'Now Playing Movies');
                              },
                            ),
                            MoviesSection(
                              movies: state2.showAdultContent ? state.nowPlayingMovies.movies! : state.nowPlayingMovies.movies!.where((movie) => !movie.adult).toList(),
                              isHomePage: true,
                            ),
                            Header(
                              title: 'Top Rated Movies',
                              onTap: () {
                                context.push('/all/top_rated', extra: 'Top Rated Movies');
                              },
                            ),
                            MoviesSection(
                              movies: state2.showAdultContent ? state.topRatedMovies.movies! : state.topRatedMovies.movies!.where((movie) => !movie.adult).toList(),
                              isHomePage: true,
                            ),
                            Header(
                              title: 'Popular Movies',
                              onTap: () {
                                context.push('/all/popular', extra: 'Popular Movies');
                              },
                            ),
                            MoviesSection(
                              movies: state2.showAdultContent ? state.popularMovies.movies! : state.popularMovies.movies!.where((movie) => !movie.adult).toList(),
                              isHomePage: true,
                            ),
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
