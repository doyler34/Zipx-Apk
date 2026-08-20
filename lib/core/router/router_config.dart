import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:movie_bloc_app/common/blocs/bloc/nav_bar_bloc.dart';
import 'package:movie_bloc_app/common/widgets/splash/splash_screen.dart';
import 'package:movie_bloc_app/features/movies/data/models/movie_model.dart';
import 'package:movie_bloc_app/features/movies/presentation/pages/details/all_reviews_screen.dart';
import 'package:movie_bloc_app/features/movies/presentation/pages/home/all_movies_screen.dart';
import 'package:movie_bloc_app/features/movies/presentation/pages/details/details_screen.dart';
import 'package:movie_bloc_app/features/movies/presentation/pages/home/genre_movies_screen.dart';
import 'package:movie_bloc_app/features/tv/data/models/tv_model.dart';
import 'package:movie_bloc_app/features/tv/presentation/pages/tv_details_screen.dart';
import 'package:movie_bloc_app/features/personalization/presentation/pages/about/about_screen.dart';
import 'package:movie_bloc_app/features/personalization/presentation/pages/downloads/downloads_screen.dart';
import 'package:movie_bloc_app/navigation_menu.dart';

import '../../common/responsive/responsive.dart';
import '../../core/playback/domain/entities/playback_request.dart';
import '../../core/playback/domain/entities/player_args.dart';
import '../../core/playback/presentation/pages/native_player_screen.dart';
import '../../desktop/desktop_shell.dart';
import '../../desktop/screens/desktop_movie_details.dart';
import '../../desktop/screens/desktop_tv_details.dart';

class CustomGoRouterConfig {
  final GoRouter config = GoRouter(
    initialLocation: '/splash',
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
        path: '/splash',
        builder: (BuildContext context, GoRouterState state) {
          return const SplashScreen();
        },
      ),
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) {
          // Desktop-class windows get the dedicated desktop UI; phones/tablets
          // keep the original bottom-bar app.
          return Responsive.isDesktop(context) ? const DesktopShell() : const NavigationMenu();
        },
      ),
      GoRoute(
        path: '/details/:id',
        builder: (BuildContext context, GoRouterState state) {
          final movie = state.extra as MovieModel;
          return Responsive.isDesktop(context)
              ? DesktopMovieDetails(movie: movie)
              : DetailsScreen(movie: movie, id: state.pathParameters['id']!);
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
          final show = state.extra as TvModel;
          return Responsive.isDesktop(context)
              ? DesktopTvDetails(show: show)
              : TvDetailsScreen(show: show);
        },
      ),
      GoRoute(
        path: '/player',
        builder: (BuildContext context, GoRouterState state) {
          // Accepts a bare PlaybackRequest, or PlayerArgs carrying a
          // pre-resolved direct URL (a ready Download plays that first).
          final extra = state.extra;
          if (extra is PlayerArgs) {
            return NativePlayerScreen(request: extra.request, primaryUrl: extra.primaryUrl);
          }
          return NativePlayerScreen(request: extra as PlaybackRequest);
        },
      ),
      GoRoute(
        path: '/downloads',
        builder: (BuildContext context, GoRouterState state) => const DownloadsScreen(),
      ),
      GoRoute(
        path: '/about',
        builder: (BuildContext context, GoRouterState state) => const AboutScreen(),
      ),
    ],
  );
}
