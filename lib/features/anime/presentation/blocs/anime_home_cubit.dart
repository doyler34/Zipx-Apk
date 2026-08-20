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

/// A titled anime row (e.g. "Popular" -> its movies/shows).
typedef AnimeMovieSection = (String title, List<MovieModel> movies);
typedef AnimeTvSection = (String title, List<TvModel> shows);

class AnimeHomeState extends Equatable {
  const AnimeHomeState({
    this.movieSections = const [],
    this.tvSections = const [],
    this.searchResults = const [],
    this.query = '',
    this.isLoading = false,
    this.errorMessage,
  });

  final List<AnimeMovieSection> movieSections;
  final List<AnimeTvSection> tvSections;
  final List<dynamic> searchResults; // MovieModel or TvModel
  final String query;
  final bool isLoading;
  final String? errorMessage;

  bool get isSearching => query.trim().isNotEmpty;
  bool get isEmpty => movieSections.isEmpty && tvSections.isEmpty;

  AnimeHomeState copyWith({
    List<AnimeMovieSection>? movieSections,
    List<AnimeTvSection>? tvSections,
    List<dynamic>? searchResults,
    String? query,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AnimeHomeState(
      movieSections: movieSections ?? this.movieSections,
      tvSections: tvSections ?? this.tvSections,
      searchResults: searchResults ?? this.searchResults,
      query: query ?? this.query,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [movieSections, tvSections, searchResults, query, isLoading, errorMessage];
}

/// One row's TMDB discover shape: title shown, the sort/filter that produces
/// it, and (for Top Rated) a minimum vote count so a single 9.5-rated OVA
/// with 3 votes doesn't outrank everything else.
typedef _RowSpec = (String title, String sortBy, int? extraGenreId, int? minVoteCount, Map<String, dynamic>? extraParams);

/// A dedicated "Anime" home, split out from Movies/TV like those two are
/// split from each other. Anime has no dedicated TMDB flag - every row uses
/// TMDB's standard heuristic (Animation genre + Japanese origin) via
/// [TmdbDatasource.discoverAnimeMovies] / [TmdbTvDatasource.discoverAnimeTv],
/// narrowed further per row (Popular/New/Top Rated, plus a few genres) the
/// same way Movies/TV Home browse several rows instead of just one.
class AnimeHomeCubit extends Cubit<AnimeHomeState> {
  AnimeHomeCubit(this._movieDatasource, this._tvDatasource) : super(const AnimeHomeState());

  final TmdbDatasource _movieDatasource;
  final TmdbTvDatasource _tvDatasource;

  // Bumped on every loadHome() call (e.g. pull-to-refresh while a previous
  // call's background availability fill is still running) so a superseded
  // in-flight load's emits are dropped instead of overwriting fresher rows.
  int _generation = 0;

  static final String _today = DateTime.now().toIso8601String().substring(0, 10);

  /// Extra genre-flavoured movie rows, using TMDB's movie genre ids.
  static const List<(int, String)> _movieGenres = [
    (28, 'Action'),
    (35, 'Comedy'),
    (10749, 'Romance'),
    (14, 'Fantasy'),
  ];

  /// Extra genre-flavoured series rows, using TMDB's (different) TV genre ids.
  static const List<(int, String)> _tvGenres = [
    (10759, 'Action & Adventure'),
    (35, 'Comedy'),
    (10765, 'Sci-Fi & Fantasy'),
    (18, 'Drama'),
  ];

  List<_RowSpec> get _movieRowSpecs => [
        ('Popular', 'popularity.desc', null, null, null),
        ('New', 'primary_release_date.desc', null, null, {'primary_release_date.lte': _today}),
        ('Top Rated', 'vote_average.desc', null, 50, null),
        for (final g in _movieGenres) (g.$2, 'popularity.desc', g.$1, null, null),
      ];

  List<_RowSpec> get _tvRowSpecs => [
        ('Popular', 'popularity.desc', null, null, null),
        ('New', 'first_air_date.desc', null, null, {'first_air_date.lte': _today}),
        ('Top Rated', 'vote_average.desc', null, 50, null),
        for (final g in _tvGenres) (g.$2, 'popularity.desc', g.$1, null, null),
      ];

  Future<void> loadHome() async {
    final gen = ++_generation;
    void safeEmit(AnimeHomeState s) {
      if (gen == _generation && !isClosed) emit(s);
    }

    safeEmit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      final movieRowSpecs = _movieRowSpecs;
      final tvRowSpecs = _tvRowSpecs;

      // Every row's first page is fetched concurrently - one slow/failing row
      // shouldn't hold up the rest, and a failure just yields an empty (and
      // therefore hidden) row instead of blanking the whole screen.
      final movieRowsFuture = Future.wait(movieRowSpecs.map((spec) async {
        try {
          final r = await _movieDatasource.discoverAnimeMovies(
            sortBy: spec.$2,
            extraGenreId: spec.$3,
            minVoteCount: spec.$4,
            extraParams: spec.$5,
          );
          return (spec, r.movies ?? const <MovieModel>[]);
        } catch (_) {
          return (spec, const <MovieModel>[]);
        }
      }));
      final tvRowsFuture = Future.wait(tvRowSpecs.map((spec) async {
        try {
          final r = await _tvDatasource.discoverAnimeTv(
            sortBy: spec.$2,
            extraGenreId: spec.$3,
            minVoteCount: spec.$4,
            extraParams: spec.$5,
          );
          return (spec, r.shows);
        } catch (_) {
          return (spec, const <TvModel>[]);
        }
      }));

      final movieRowsRaw = (await movieRowsFuture).where((r) => r.$2.isNotEmpty).toList();
      final tvRowsRaw = (await tvRowsFuture).where((r) => r.$2.isNotEmpty).toList();

      var movieSections = [for (final r in movieRowsRaw) (r.$1.$1, r.$2)];
      var tvSections = [for (final r in tvRowsRaw) (r.$1.$1, r.$2)];

      safeEmit(state.copyWith(movieSections: movieSections, tvSections: tvSections, isLoading: false));

      // Background availability fill (same pattern as Movies/TV home): every
      // row fills concurrently and re-emits the instant it lands, sharing
      // AvailabilityProber's global request gate so this finishes sooner
      // without multiplying total AIOStreams load.
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

      void safeEmitRow() {
        // Superseded by a newer loadHome() (e.g. pull-to-refresh) while
        // probing ran - drop this result rather than overwrite the fresher one.
        if (gen != _generation || isClosed) return;
        emit(state.copyWith(movieSections: movieSections, tvSections: tvSections));
      }

      final futures = <Future<void>>[];
      for (var i = 0; i < movieRowsRaw.length; i++) {
        final spec = movieRowsRaw[i].$1;
        final firstPage = movieRowsRaw[i].$2;
        futures.add(prober.fillAvailable<MovieModel>(
          mediaType: PlaybackMediaType.movie,
          firstPage: firstPage,
          fetchPage: (p) => _movieDatasource
              .discoverAnimeMovies(page: p, sortBy: spec.$2, extraGenreId: spec.$3, minVoteCount: spec.$4, extraParams: spec.$5)
              .then((r) => r.movies ?? const <MovieModel>[]),
          idOf: (m) => m.id,
          toRequest: movieReq,
        ).then((filled) {
          movieSections = [
            for (var j = 0; j < movieSections.length; j++) j == i ? (spec.$1, filled) : movieSections[j],
          ];
          safeEmitRow();
        }).catchError((_) {})); // fail-open: keep this row as first shown
      }
      for (var i = 0; i < tvRowsRaw.length; i++) {
        final spec = tvRowsRaw[i].$1;
        final firstPage = tvRowsRaw[i].$2;
        futures.add(prober.fillAvailable<TvModel>(
          mediaType: PlaybackMediaType.tv,
          firstPage: firstPage,
          fetchPage: (p) => _tvDatasource
              .discoverAnimeTv(page: p, sortBy: spec.$2, extraGenreId: spec.$3, minVoteCount: spec.$4, extraParams: spec.$5)
              .then((r) => r.shows),
          idOf: (s) => s.id,
          toRequest: tvReq,
        ).then((filled) {
          tvSections = [
            for (var j = 0; j < tvSections.length; j++) j == i ? (spec.$1, filled) : tvSections[j],
          ];
          safeEmitRow();
        }).catchError((_) {})); // fail-open: keep this row as first shown
      }
      await Future.wait(futures);
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
      // This is what keeps the Anime tab's search bar from ever surfacing
      // non-anime movies/shows, unlike the plain Movies/TV search.
      final movies = (moviesResult.movies ?? const <MovieModel>[]).where((m) => m.genreIds.contains(16)).toList();
      final series = tvResult.shows.where((s) => s.genreIds.contains(16)).toList();
      emit(state.copyWith(searchResults: [...movies, ...series], isLoading: false));
    } catch (_) {
      emit(state.copyWith(isLoading: false, errorMessage: 'Search failed.'));
    }
  }
}
