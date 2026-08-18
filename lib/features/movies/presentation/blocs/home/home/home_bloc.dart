import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:movie_bloc_app/features/movies/data/datasources/remote/tmdb_datasource.dart';
import 'package:movie_bloc_app/features/movies/data/models/movies_result_model.dart';
import 'package:movie_bloc_app/features/movies/domain/entities/params/params.dart';
import 'package:movie_bloc_app/features/movies/domain/usecases/get_genres.dart';
import 'package:movie_bloc_app/features/movies/domain/usecases/get_popular.dart';
import 'package:movie_bloc_app/features/movies/domain/usecases/get_toprated.dart';
import 'package:movie_bloc_app/features/movies/domain/usecases/get_trending.dart';

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
  final GetPopular getPopular;
  final GetToprated getTopRated;
  final GetTrending getTrending;
  final TmdbDatasource tmdbDatasource;

  /// Extra genre rows so Home has plenty to browse. Upcoming/Now Playing were
  /// dropped entirely (not just supplemented) - those skew toward brand-new
  /// releases, which are genuinely thin on torrent availability once
  /// CAM/TS/SCR are excluded, so they were frequently just empty. These are
  /// broad, well-established genres with deep catalogues instead. Animation
  /// (16) is deliberately excluded - it lives in the dedicated Anime section
  /// instead of duplicating that content here.
  static const List<(int, String)> _homeGenres = [
    (28, 'Action'),
    (35, 'Comedy'),
    (27, 'Horror'),
    (53, 'Thriller'),
    (878, 'Science Fiction'),
    (18, 'Drama'),
    (80, 'Crime'),
    (10749, 'Romance'),
  ];

  //Popular
  List<MovieModel> popularMovies = [];

  //Genres
  List<GenreModel> genres = [];

  //Top Rated
  List<MovieModel> topRatedMovies = [];

  //Trending
  List<MovieModel> trendingMovies = [];

  // Bumped on every LoadHome dispatch (e.g. pull-to-refresh while a previous
  // load's background availability fill is still running) so a stale
  // in-flight load's emits are dropped instead of overwriting fresher rows.
  int _generation = 0;

  HomeBloc({
    required this.getGenres,
    required this.getPopular,
    required this.getTopRated,
    required this.getTrending,
    required this.tmdbDatasource,
  }) : super(HomeInitial()) {
    on<LoadHome>((event, emit) async {
      // This load's generation: if another LoadHome is dispatched (e.g.
      // pull-to-refresh) before this one finishes, `_generation` moves past
      // `gen` and every emit below becomes a no-op - the newer load wins and
      // this one's (possibly stale) results never overwrite it.
      final gen = ++_generation;
      void safeEmit(HomeState s) {
        if (gen == _generation && !emit.isDone) emit(s);
      }

      final hasConnection = await HelperFunctions.hasConnection();
      if (!hasConnection) {
        safeEmit(const HomeError('No internet connection'));
        return;
      }

      safeEmit(HomeLoading());

      try {
        // Started early (not awaited yet) so it runs alongside the sequential
        // fetches below instead of adding its own wait on top. Each genre is
        // independent - one genre failing shouldn't blank the rest.
        final genreRowsFuture = Future.wait(_homeGenres.map((g) async {
          try {
            final r = await tmdbDatasource.discoverMoviesByGenre(genreId: g.$1);
            return (g.$1, g.$2, r.movies ?? const <MovieModel>[]);
          } catch (_) {
            return (g.$1, g.$2, const <MovieModel>[]);
          }
        }));

        final popularResult = await getPopular(Params());

        if (popularResult.movies!.isEmpty) {
          safeEmit(const HomeError('Error while fetching data'));
        } else {
          popularMovies = popularResult.movies!;
        }

        final genresResult = await getGenres(NoParams());

        if (genresResult.isEmpty) {
          safeEmit(const HomeError('Error while fetching data'));
        } else {
          genres = genresResult;
        }

        final topRatedResult = await getTopRated(Params());
        if (topRatedResult.movies!.isEmpty) {
          safeEmit(const HomeError('Error while fetching data'));
        } else {
          topRatedMovies = topRatedResult.movies!;
        }

        final trendingResult = await getTrending(NoParams());
        final genreRowsRaw = (await genreRowsFuture).where((g) => g.$3.isNotEmpty).toList();

        if (trendingResult.movies!.isEmpty) {
          safeEmit(const HomeError('Error while fetching data'));
        } else {
          trendingMovies = trendingResult.movies!;

          // Pre-filter using cache (known unavailable titles are hidden even on
          // first render) so subsequent loads don't show unfiltered TMDB while
          // waiting for background probing to complete.
          final avail = sl<StreamAvailabilityService>();
          final popularPre = (popularResult.movies ?? const <MovieModel>[])
              .where((m) => !avail.isKnownUnavailable(PlaybackMediaType.movie, m.id))
              .toList();
          final topRatedPre = (topRatedResult.movies ?? const <MovieModel>[])
              .where((m) => !avail.isKnownUnavailable(PlaybackMediaType.movie, m.id))
              .toList();
          final trendingPre = (trendingResult.movies ?? const <MovieModel>[])
              .where((m) => !avail.isKnownUnavailable(PlaybackMediaType.movie, m.id))
              .toList();
          final genreSectionsPre = genreRowsRaw
              .map((g) => (g.$2, g.$3.where((m) => !avail.isKnownUnavailable(PlaybackMediaType.movie, m.id)).toList()))
              .toList();

          safeEmit(HomeLoaded(
            popularMovies: MoviesResultModel(movies: popularPre, totalPages: popularResult.totalPages),
            genres: genresResult,
            topRatedMovies: MoviesResultModel(movies: topRatedPre, totalPages: topRatedResult.totalPages),
            trendingMovies: MoviesResultModel(movies: trendingPre, totalPages: trendingResult.totalPages),
            genreSections: genreSectionsPre,
          ));
          // Background availability fill (option B): rows are shown above with
          // cache-known-unavailable titles already hidden; now probe each title
          // via AIOStreams, top up the pageable rows to their target across a
          // few pages, and re-emit with newly-discovered unavailable titles
          // removed. Guarded by `gen` so a superseded load's fill can never land
          // after a fresher one.
          await _fillAvailability(
            emit,
            gen: gen,
            genres: genresResult,
            popular: popularResult,
            topRated: topRatedResult,
            trending: trendingResult,
            genreRows: genreRowsRaw,
          );
        }
      } catch (e) {
        safeEmit(const HomeError('Error while fetching data'));
      }
    });
  }

  /// Probes each row's titles for a playable stream (concurrently, cache-first),
  /// tops the pageable rows up to their target across a few TMDB pages, and
  /// re-emits [HomeLoaded] with the dead-ends filtered out. Fail-open: any error
  /// just leaves the rows as first shown.
  Future<void> _fillAvailability(
    Emitter<HomeState> emit, {
    required int gen,
    required List<GenreModel> genres,
    required MoviesResultModel popular,
    required MoviesResultModel topRated,
    required MoviesResultModel trending,
    required List<(int, String, List<MovieModel>)> genreRows,
  }) async {
    final prober = sl<AvailabilityProber>();
    PlaybackRequest req(MovieModel m) => PlaybackRequest(
          tmdbId: m.id,
          mediaType: PlaybackMediaType.movie,
          title: m.title,
          posterPath: m.posterPath,
        );

    // A pageable row: probe + top up to target across up to [maxPages] pages.
    Future<List<MovieModel>> fill(
      MoviesResultModel first,
      Future<MoviesResultModel> Function(int) fetch, {
      int maxPages = 3,
    }) =>
        prober.fillAvailable<MovieModel>(
          mediaType: PlaybackMediaType.movie,
          firstPage: first.movies,
          fetchPage: (p) => fetch(p).then((r) => r.movies ?? const <MovieModel>[]),
          idOf: (m) => m.id,
          toRequest: req,
          maxPages: maxPages,
        );

    final List<MovieModel> popularF, topRatedF, trendingF;
    final List<MovieSection> genreSectionsF;
    try {
      popularF = await fill(popular, (p) => getPopular(Params(page: p)));
      topRatedF = await fill(topRated, (p) => getTopRated(Params(page: p)));
      // Trending isn't pageable (NoParams) - just probe this page + filter it.
      await prober.probe(PlaybackMediaType.movie, (trending.movies ?? const <MovieModel>[]).map(req).toList());
      final avail = sl<StreamAvailabilityService>();
      trendingF = (trending.movies ?? const <MovieModel>[])
          .where((m) => !avail.isKnownUnavailable(PlaybackMediaType.movie, m.id))
          .toList();
      // Genre rows top up too - without this, a genre whose page-1 picks skew
      // unavailable ends up sparser than it needs to be instead of refilled.
      genreSectionsF = await Future.wait(genreRows.map((g) async {
        try {
          final filled = await fill(
            MoviesResultModel(movies: g.$3, totalPages: 1),
            (p) => tmdbDatasource.discoverMoviesByGenre(genreId: g.$1, page: p),
          );
          return (g.$2, filled);
        } catch (_) {
          return (g.$2, g.$3); // fail-open: keep this genre row as first shown
        }
      }));
    } catch (_) {
      return; // fail-open
    }
    // Superseded by a newer LoadHome (e.g. pull-to-refresh) while probing ran -
    // drop this result rather than overwrite the fresher one.
    if (gen != _generation || emit.isDone) return;
    MoviesResultModel wrap(List<MovieModel> ms, MoviesResultModel src) =>
        MoviesResultModel(movies: ms, totalPages: src.totalPages);
    emit(HomeLoaded(
      popularMovies: wrap(popularF, popular),
      genres: genres,
      topRatedMovies: wrap(topRatedF, topRated),
      trendingMovies: wrap(trendingF, trending),
      genreSections: genreSectionsF,
    ));
  }
}
