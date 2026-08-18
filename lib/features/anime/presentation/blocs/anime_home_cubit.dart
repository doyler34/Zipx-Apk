import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/dependency_injection/di.dart';
import '../../../../core/playback/domain/entities/playback_media_type.dart';
import '../../../../core/playback/domain/entities/playback_request.dart';
import '../../../../core/playback/services/availability_prober.dart';
import '../../../movies/data/datasources/remote/tmdb_datasource.dart';
import '../../../movies/data/models/movie_model.dart';
import '../../../tv/data/datasources/remote/tmdb_tv_datasource.dart';
import '../../../tv/data/models/tv_model.dart';

class AnimeHomeState extends Equatable {
  const AnimeHomeState({
    this.movies = const [],
    this.series = const [],
    this.searchResults = const [],
    this.query = '',
    this.isLoading = false,
    this.errorMessage,
  });

  final List<MovieModel> movies;
  final List<TvModel> series;
  final List<dynamic> searchResults; // MovieModel or TvModel
  final String query;
  final bool isLoading;
  final String? errorMessage;

  bool get isSearching => query.trim().isNotEmpty;

  AnimeHomeState copyWith({
    List<MovieModel>? movies,
    List<TvModel>? series,
    List<dynamic>? searchResults,
    String? query,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AnimeHomeState(
      movies: movies ?? this.movies,
      series: series ?? this.series,
      searchResults: searchResults ?? this.searchResults,
      query: query ?? this.query,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [movies, series, searchResults, query, isLoading, errorMessage];
}

/// A dedicated "Anime" home, split out from Movies/TV like those two are
/// split from each other. Anime has no dedicated TMDB flag - both rows use
/// TMDB's standard heuristic (Animation genre + Japanese origin) via
/// [TmdbDatasource.discoverAnimeMovies] / [TmdbTvDatasource.discoverAnimeTv].
class AnimeHomeCubit extends Cubit<AnimeHomeState> {
  AnimeHomeCubit(this._movieDatasource, this._tvDatasource) : super(const AnimeHomeState());

  final TmdbDatasource _movieDatasource;
  final TmdbTvDatasource _tvDatasource;

  // Bumped on every loadHome() call (e.g. pull-to-refresh while a previous
  // call's background availability fill is still running) so a superseded
  // in-flight load's emits are dropped instead of overwriting fresher rows.
  int _generation = 0;

  Future<void> loadHome() async {
    final gen = ++_generation;
    void safeEmit(AnimeHomeState s) {
      if (gen == _generation && !isClosed) emit(s);
    }

    safeEmit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      // Started together (not `await`ed until both are needed) so the two
      // TMDB calls run concurrently without needing a mixed-type Future.wait.
      final moviesFuture = _movieDatasource.discoverAnimeMovies();
      final tvFuture = _tvDatasource.discoverAnimeTv();
      final moviesResult = await moviesFuture;
      final tvResult = await tvFuture;
      final movies = moviesResult.movies ?? const <MovieModel>[];
      final series = tvResult.shows;

      safeEmit(state.copyWith(movies: movies, series: series, isLoading: false));

      // Background availability fill (same pattern as Movies/TV home): rows
      // are shown above; probe each title via AIOStreams and re-emit with
      // unstreamable titles removed.
      final prober = sl<AvailabilityProber>();
      PlaybackRequest movieReq(MovieModel m) => PlaybackRequest(
            tmdbId: m.id,
            mediaType: PlaybackMediaType.movie,
            title: m.title,
            posterPath: m.posterPath,
          );
      PlaybackRequest tvReq(TvModel s) => PlaybackRequest(
            tmdbId: s.id,
            mediaType: PlaybackMediaType.tv,
            title: s.name,
            seasonNumber: 1,
            episodeNumber: 1,
            posterPath: s.posterPath,
          );

      final List<MovieModel> moviesF;
      final List<TvModel> seriesF;
      try {
        moviesF = await prober.fillAvailable<MovieModel>(
          mediaType: PlaybackMediaType.movie,
          firstPage: movies,
          fetchPage: (p) => _movieDatasource.discoverAnimeMovies(page: p).then((r) => r.movies ?? const <MovieModel>[]),
          idOf: (m) => m.id,
          toRequest: movieReq,
        );
        seriesF = await prober.fillAvailable<TvModel>(
          mediaType: PlaybackMediaType.tv,
          firstPage: series,
          fetchPage: (p) => _tvDatasource.discoverAnimeTv(page: p).then((r) => r.shows),
          idOf: (s) => s.id,
          toRequest: tvReq,
        );
      } catch (_) {
        return; // fail-open - keep rows as first shown
      }
      // Superseded by a newer loadHome() (e.g. pull-to-refresh) while probing
      // ran - drop this result rather than overwrite the fresher one.
      if (gen != _generation || isClosed) return;
      emit(state.copyWith(movies: moviesF, series: seriesF));
    } catch (_) {
      safeEmit(state.copyWith(isLoading: false, errorMessage: 'Failed to load anime.'));
    }
  }

  Future<void> search(String query) async {
    emit(state.copyWith(query: query));
    if (query.trim().isEmpty) {
      emit(state.copyWith(searchResults: const []));
      return;
    }
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      final moviesFuture = _movieDatasource.searchMovies(query: query);
      final tvFuture = _tvDatasource.searchTv(query: query);
      final moviesResult = await moviesFuture;
      final tvResult = await tvFuture;
      // Client-side filter to anime only: TMDB search has no genre/origin
      // filter param, so narrow the plain search results down to Japanese-
      // animation titles (mirrors the discover rows' Animation+JP heuristic).
      final movies = (moviesResult.movies ?? const <MovieModel>[]).where((m) => m.genreIds.contains(16)).toList();
      final series = tvResult.shows.where((s) => s.genreIds.contains(16)).toList();
      emit(state.copyWith(searchResults: [...movies, ...series], isLoading: false));
    } catch (_) {
      emit(state.copyWith(isLoading: false, errorMessage: 'Search failed.'));
    }
  }
}
