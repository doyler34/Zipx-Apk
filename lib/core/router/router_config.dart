import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:movie_bloc_app/common/blocs/bloc/nav_bar_bloc.dart';
import 'package:movie_bloc_app/features/movies/data/models/movie_model.dart';
import 'package:movie_bloc_app/features/movies/presentation/pages/details/all_reviews_screen.dart';
import 'package:movie_bloc_app/features/movies/presentation/pages/home/all_movies_screen.dart';
import 'package:movie_bloc_app/features/movies/presentation/pages/details/details_screen.dart';
import 'package:movie_bloc_app/features/movies/presentation/pages/home/genre_movies_screen.dart';
import 'package:movie_bloc_app/features/tv/data/models/tv_model.dart';
import 'package:movie_bloc_app/features/tv/presentation/pages/tv_details_screen.dart';
import 'package:movie_bloc_app/navigation_menu.dart';

import '../../core/dependency_injection/di.dart';
import '../../core/playback/domain/entities/playback_request.dart';
import '../../core/playback/presentation/pages/player_screen.dart';
import '../../core/playback/services/playback_history_service.dart';
import '../../core/playback/services/playback_provider_service.dart';

class CustomGoRouterConfig {
  final GoRouter config = GoRouter(
    errorBuilder: (context, state) {
      return BlocBuilder<NavBarBloc, NavBarState>(
        builder: (_, state2) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text('Page not found'),
                  ElevatedButton(
                    onPressed: () {
                      context.go('/');
                      context.read<NavBarBloc>().add(const NavBarTapEvent(0));
                    },
                    child: const Text('Go back'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) {
          return const NavigationMenu();
        },
      ),
      GoRoute(
        path: '/details/:id',
        builder: (BuildContext context, GoRouterState state) {
          return DetailsScreen(movie: state.extra as MovieModel, id: state.pathParameters['id']!);
        },
      ),
      GoRoute(
        path: '/all/:section',
        builder: (BuildContext context, GoRouterState state) {
          return AllMoviesScreen(section: state.pathParameters['section']!, title: state.extra as String);
        },
      ),
      GoRoute(
        path: '/genre/:genreId',
        builder: (BuildContext context, GoRouterState state) {
          return GenreMoviesScreen(genreId: state.pathParameters['genreId']!, genreName: state.extra as String);
        },
      ),
      GoRoute(
        path: '/reviews/:movieId',
        builder: (BuildContext context, GoRouterState state) {
          return AllReviewsScreen(movieId: state.pathParameters['movieId']!);
        },
      ),
      GoRoute(
        path: '/tv/:id',
        builder: (BuildContext context, GoRouterState state) {
          return TvDetailsScreen(show: state.extra as TvModel);
        },
      ),
      GoRoute(
        path: '/player',
        builder: (BuildContext context, GoRouterState state) {
          return PlayerScreen(
            request: state.extra as PlaybackRequest,
            playbackProviderService: sl<PlaybackProviderService>(),
            historyService: sl<PlaybackHistoryService>(),
          );
        },
      ),
    ],
  );
}
