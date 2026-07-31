import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import '../../../../common/widgets/texts/centered_message.dart';
import '../../../../core/dependency_injection/di.dart';
import '../../../../core/playback/services/playback_history_service.dart';
import '../../../movies/data/models/movie_model.dart';
import '../../../movies/presentation/blocs/home/home/home_bloc.dart';
import '../../../personalization/presentation/blocs/settings/settings_bloc.dart';
import '../widgets/tv_poster_card.dart';
import '../widgets/tv_row.dart';

/// Dedicated 10-foot home screen used only on TV (see NavigationMenu). Shows
/// the same data as the phone home ([HomeBloc]) but as focusable, TV-sized
/// horizontal poster rows instead of the phone's carousel/section layout.
class HomeTvScreen extends StatelessWidget {
  const HomeTvScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, settingsState) {
        if (settingsState is! SettingsChanged) return const SizedBox.shrink();
        final showAdult = settingsState.showAdultContent;

        return BlocBuilder<HomeBloc, HomeState>(
          bloc: context.read<HomeBloc>(),
          builder: (context, state) {
            if (state is HomeInitial) {
              context.read<HomeBloc>().add(LoadHome());
              return const CenteredMessage(message: 'Please wait...');
            }
            if (state is HomeLoading) {
              return Center(child: LoadingAnimationWidget.beat(color: Theme.of(context).colorScheme.tertiary, size: 50));
            }
            if (state is HomeError) {
              return CenteredMessage(message: state.message);
            }
            if (state is HomeLoaded) {
              return _TvHomeContent(state: state, showAdult: showAdult);
            }
            return const SizedBox.shrink();
          },
        );
      },
    );
  }
}

class _TvHomeContent extends StatelessWidget {
  const _TvHomeContent({required this.state, required this.showAdult});

  final HomeLoaded state;
  final bool showAdult;

  List<MovieModel> _filter(List<MovieModel>? movies) {
    final list = movies ?? const <MovieModel>[];
    return showAdult ? list : list.where((m) => !m.adult).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Tracks the very first card so it can autofocus, giving the remote a
    // starting point when the screen opens.
    var firstAssigned = false;
    bool takeFirst() {
      if (firstAssigned) return false;
      firstAssigned = true;
      return true;
    }

    List<Widget> movieCards(List<MovieModel> movies) {
      return [
        for (final movie in movies)
          TvPosterCard(
            posterPath: movie.posterPath,
            voteAverage: movie.voteAverage,
            autofocus: takeFirst(),
            onPressed: () => context.push('/details/${movie.id}', extra: movie),
          ),
      ];
    }

    final history = sl<PlaybackHistoryService>().getHistory();
    final continueCards = [
      for (final entry in history)
        TvPosterCard(
          posterPath: entry.posterPath ?? '',
          autofocus: takeFirst(),
          onPressed: () => context.push('/player', extra: entry.toPlaybackRequest()),
        ),
    ];

    return SafeArea(
      child: ListView(
        children: [
          TvRow(title: 'Continue Watching', cards: continueCards),
          TvRow(title: 'Trending', cards: movieCards(_filter(state.trendingMovies.movies))),
          TvRow(title: 'Upcoming Movies', cards: movieCards(_filter(state.upcomingMovies.movies))),
          TvRow(title: 'Now Playing', cards: movieCards(_filter(state.nowPlayingMovies.movies))),
          TvRow(title: 'Top Rated', cards: movieCards(_filter(state.topRatedMovies.movies))),
          TvRow(title: 'Popular', cards: movieCards(_filter(state.popularMovies.movies))),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
