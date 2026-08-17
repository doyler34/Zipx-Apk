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
          // above; now probe each title via AIOStreams, top up the pageable rows
          // to their target across a few pages, and re-emit with the titles that
          // have no playable stream removed.
          await _fillAvailability(
            emit,
            genres: genresResult,
            popular: popularResult,
            upcoming: upcomingResult,
            nowPlaying: nowPlayingResult,
            topRated: topRatedResult,
            trending: trendingResult,
          );
        }
      } catch (e) {
        emit(const HomeError('Error while fetching data'));
      }
    });
  }

  /// Probes each row's titles for a playable stream (concurrently, cache-first),
  /// tops the pageable rows up to their target across a few TMDB pages, and
  /// re-emits [HomeLoaded] with the dead-ends filtered out. Fail-open: any error
  /// just leaves the rows as first shown.
  Future<void> _fillAvailability(
    Emitter<HomeState> emit, {
    required List<GenreModel> genres,
    required MoviesResultModel popular,
    required MoviesResultModel upcoming,
    required MoviesResultModel nowPlaying,
    required MoviesResultModel topRated,
    required MoviesResultModel trending,
  }) async {
    final prober = sl<AvailabilityProber>();
    PlaybackRequest req(MovieModel m) => PlaybackRequest(
          tmdbId: m.id,
          mediaType: PlaybackMediaType.movie,
          title: m.title,
          posterPath: m.posterPath,
        );

    // A pageable row: probe + top up to target across up to 3 pages.
    Future<List<MovieModel>> fill(MoviesResultModel first, Future<MoviesResultModel> Function(int) fetch) =>
        prober.fillAvailable<MovieModel>(
          mediaType: PlaybackMediaType.movie,
          firstPage: first.movies,
          fetchPage: (p) => fetch(p).then((r) => r.movies ?? const <MovieModel>[]),
          idOf: (m) => m.id,
          toRequest: req,
        );

    final List<MovieModel> popularF, upcomingF, nowPlayingF, topRatedF, trendingF;
    try {
      popularF = await fill(popular, (p) => getPopular(Params(page: p)));
      upcomingF = await fill(upcoming, (p) => getUpcoming(Params(page: p)));
      nowPlayingF = await fill(nowPlaying, (p) => getNowPlaying(Params(page: p)));
      topRatedF = await fill(topRated, (p) => getTopRated(Params(page: p)));
      // Trending isn't pageable (NoParams) - just probe this page + filter it.
      await prober.probe(PlaybackMediaType.movie, (trending.movies ?? const <MovieModel>[]).map(req).toList());
      final avail = sl<StreamAvailabilityService>();
      trendingF = (trending.movies ?? const <MovieModel>[])
          .where((m) => !avail.isKnownUnavailable(PlaybackMediaType.movie, m.id))
          .toList();
    } catch (_) {
      return; // fail-open
    }
    if (emit.isDone) return;
    MoviesResultModel wrap(List<MovieModel> ms, MoviesResultModel src) =>
        MoviesResultModel(movies: ms, totalPages: src.totalPages);
    emit(HomeLoaded(
      popularMovies: wrap(popularF, popular),
      upcomingMovies: wrap(upcomingF, upcoming),
      genres: genres,
      nowPlayingMovies: wrap(nowPlayingF, nowPlaying),
      topRatedMovies: wrap(topRatedF, topRated),
      trendingMovies: wrap(trendingF, trending),
    ));
  }
}
