import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:movie_bloc_app/features/movies/data/models/movies_result_model.dart';
import 'package:movie_bloc_app/features/movies/domain/entities/params/params.dart';
import 'package:movie_bloc_app/features/movies/domain/usecases/get_genres.dart';
import 'package:movie_bloc_app/features/movies/domain/usecases/get_nowplaying.dart';
import 'package:movie_bloc_app/features/movies/domain/usecases/get_popular.dart';
import 'package:movie_bloc_app/features/movies/domain/usecases/get_toprated.dart';
import 'package:movie_bloc_app/features/movies/domain/usecases/get_trending.dart';
import 'package:movie_bloc_app/features/movies/domain/usecases/get_upcoming.dart';

import '../../../../../../core/dependency_injection/di.dart';
import '../../../../../../core/playback/domain/entities/playback_media_type.dart';
import '../../../../../../core/playback/domain/entities/playback_request.dart';
import '../../../../../../core/playback/services/availability_prober.dart';
import '../../../../../../core/playback/services/stream_availability_service.dart';
import '../../../../../../core/utils/helpers/helper_functions.dart';
import '../../../../data/models/genre_model.dart';
import '../../../../data/models/movie_model.dart';
import '../../../../domain/entities/params/no_params.dart';

part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final GetGenres getGenres;
  final GetUpcoming getUpcoming;
  final GetPopular getPopular;
  final GetNowplaying getNowPlaying;
  final GetToprated getTopRated;
  final GetTrending getTrending;

  //Popular
  List<MovieModel> popularMovies = [];

  //Upcoming
  List<MovieModel> upcomingMovies = [];

  //Genres
  List<GenreModel> genres = [];

  //Now Playing
  List<MovieModel> nowPlayingMovies = [];

  //Top Rated
  List<MovieModel> topRatedMovies = [];

  //Trending
  List<MovieModel> trendingMovies = [];

  HomeBloc({
    required this.getGenres,
    required this.getPopular,
    required this.getUpcoming,
    required this.getNowPlaying,
    required this.getTopRated,
    required this.getTrending,
  }) : super(HomeInitial()) {
    on<LoadHome>((event, emit) async {
      final hasConnection = await HelperFunctions.hasConnection();
      if (!hasConnection) {
        emit(const HomeError('No internet connection'));
        return;
      }

      emit(HomeLoading());

      try {
        final popularResult = await getPopular(Params());

        if (popularResult.movies!.isEmpty) {
          emit(const HomeError('Error while fetching data'));
        } else {
          popularMovies = popularResult.movies!;
        }

        final upcomingResult = await getUpcoming(Params());

        if (upcomingResult.movies!.isEmpty) {
          emit(const HomeError('Error while fetching data'));
        } else {
          upcomingMovies = upcomingResult.movies!;
        }

        final genresResult = await getGenres(NoParams());

        if (genresResult.isEmpty) {
          emit(const HomeError('Error while fetching data'));
        } else {
          genres = genresResult;
        }

        final nowPlayingResult = await getNowPlaying(Params());

        if (nowPlayingResult.movies!.isEmpty) {
          emit(const HomeError('Error while fetching data'));
        } else {
          nowPlayingMovies = nowPlayingResult.movies!;
        }

        final topRatedResult = await getTopRated(Params());
        if (topRatedResult.movies!.isEmpty) {
          emit(const HomeError('Error while fetching data'));
        } else {
          topRatedMovies = topRatedResult.movies!;
        }

        final trendingResult = await getTrending(NoParams());

        if (trendingResult.movies!.isEmpty) {
          emit(const HomeError('Error while fetching data'));
        } else {
          trendingMovies = trendingResult.movies!;
          emit(HomeLoaded(
            popularMovies: popularResult,
            upcomingMovies: upcomingResult,
            genres: genresResult,
            nowPlayingMovies: nowPlayingResult,
            topRatedMovies: topRatedResult,
            trendingMovies: trendingResult,
          ));
          // Background availability fill (option B): the rows are already shown
          // above; now probe each title via AIOStreams and re-emit with the
          // titles that have no playable stream removed.
          await _fillAvailability(
            emit,
            genres: genresResult,
            rows: [popularResult, upcomingResult, nowPlayingResult, topRatedResult, trendingResult],
          );
        }
      } catch (e) {
        emit(const HomeError('Error while fetching data'));
      }
    });
  }

  /// Probes every movie in the loaded rows for a playable stream (concurrently,
  /// cache-first) and re-emits [HomeLoaded] with the dead-ends filtered out.
  /// Fail-open: any error just leaves the rows as first shown.
  Future<void> _fillAvailability(
    Emitter<HomeState> emit, {
    required List<GenreModel> genres,
    required List<MoviesResultModel> rows,
  }) async {
    final requests = <PlaybackRequest>[];
    for (final r in rows) {
      for (final m in r.movies ?? const <MovieModel>[]) {
        requests.add(PlaybackRequest(
          tmdbId: m.id,
          mediaType: PlaybackMediaType.movie,
          title: m.title,
          posterPath: m.posterPath,
        ));
      }
    }
    if (requests.isEmpty) return;
    try {
      await sl<AvailabilityProber>().probe(PlaybackMediaType.movie, requests);
    } catch (_) {
      return; // fail-open
    }
    if (emit.isDone) return;
    final avail = sl<StreamAvailabilityService>();
    MoviesResultModel keep(MoviesResultModel r) => MoviesResultModel(
          movies: (r.movies ?? const <MovieModel>[])
              .where((m) => !avail.isKnownUnavailable(PlaybackMediaType.movie, m.id))
              .toList(),
          totalPages: r.totalPages,
        );
    emit(HomeLoaded(
      popularMovies: keep(rows[0]),
      upcomingMovies: keep(rows[1]),
      genres: genres,
      nowPlayingMovies: keep(rows[2]),
      topRatedMovies: keep(rows[3]),
      trendingMovies: keep(rows[4]),
    ));
  }
}
