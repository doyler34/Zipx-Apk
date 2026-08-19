import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/dependency_injection/di.dart';
import '../../../../core/playback/domain/entities/playback_media_type.dart';
import '../../../../core/playback/domain/entities/playback_request.dart';
import '../../../../core/playback/services/availability_prober.dart';
import '../../../../core/playback/services/stream_availability_service.dart';
import '../../../movies/data/models/genre_model.dart';
import '../../data/datasources/remote/tmdb_tv_datasource.dart';
import '../../data/models/tv_model.dart';

/// A titled home row built from a genre (e.g. "Comedy" -> its shows).
typedef TvSection = (String title, List<TvModel> shows);

class TvHomeState extends Equatable {
  const TvHomeState({
    this.trending = const [],
    this.popular = const [],
    this.topRated = const [],
    this.genreSections = const [],
    this.genres = const [],
    this.searchResults = const [],
    this.genreResults = const [],
    this.query = '',
    this.selectedGenreId,
    this.selectedGenreName,
    this.isLoading = false,
    this.isLoadingGenre = false,
    this.errorMessage,
  });

  final List<TvModel> trending;
  final List<TvModel> popular;
  final List<TvModel> topRated;
  final List<TvSection> genreSections;
  final List<GenreModel> genres;
  final List<TvModel> searchResults;
  final List<TvModel> genreResults;
  final String query;
  final int? selectedGenreId;
  final String? selectedGenreName;
  final bool isLoading;
  final bool isLoadingGenre;
  final String? errorMessage;

  bool get isSearching => query.trim().isNotEmpty;
  bool get isFilteringGenre => selectedGenreId != null;

  TvHomeState copyWith({
    List<TvModel>? trending,
    List<TvModel>? popular,
    List<TvModel>? topRated,
    List<TvSection>? genreSections,
    List<GenreModel>? genres,
    List<TvModel>? searchResults,
    List<TvModel>? genreResults,
    String? query,
    bool? isLoading,
    bool? isLoadingGenre,
    String? errorMessage,
  }) {
    return TvHomeState(
      trending: trending ?? this.trending,
      popular: popular ?? this.popular,
      topRated: topRated ?? this.topRated,
      genreSections: genreSections ?? this.genreSections,
      genres: genres ?? this.genres,
      searchResults: searchResults ?? this.searchResults,
      genreResults: genreResults ?? this.genreResults,
      query: query ?? this.query,
      // Genre selection is cleared via clearGenre(); copyWith only ever sets
      // it through the dedicated methods below, so it isn't a named param here.
      selectedGenreId: selectedGenreId,
      selectedGenreName: selectedGenreName,
      isLoading: isLoading ?? this.isLoading,
      isLoadingGenre: isLoadingGenre ?? this.isLoadingGenre,
      errorMessage: errorMessage,
    );
  }

  // Genre state can't ride copyWith (it needs to go back to null), so it gets
  // its own builder used by the filter methods.
  TvHomeState withGenre({
    int? genreId,
    String? genreName,
    List<TvModel>? genreResults,
    bool? isLoadingGenre,
  }) {
    return TvHomeState(
      trending: trending,
      popular: popular,
      topRated: topRated,
      genreSections: genreSections,
      genres: genres,
      searchResults: searchResults,
      genreResults: genreResults ?? this.genreResults,
      query: query,
      selectedGenreId: genreId,
      selectedGenreName: genreName,
      isLoading: isLoading,
      isLoadingGenre: isLoadingGenre ?? this.isLoadingGenre,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        trending,
        popular,
        topRated,
        genreSections,
        genres,
        searchResults,
        genreResults,
        query,
        selectedGenreId,
        selectedGenreName,
        isLoading,
        isLoadingGenre,
        errorMessage,
      ];
}

/// Lightweight Cubit (rather than the full Bloc event/state boilerplate used
/// by the movies feature) for the TV browsing this app needs. Loads several
/// category rows plus the genre catalogue so the home screen mirrors the movie
/// home, and supports genre filtering and search.
class TvHomeCubit extends Cubit<TvHomeState> {
  TvHomeCubit(this._datasource) : super(const TvHomeState());

  final TmdbTvDatasource _datasource;

  // Bumped on every loadHome() call (e.g. pull-to-refresh while a previous
  // call's background availability fill is still running) so a superseded
  // in-flight load's emits are dropped instead of overwriting fresher rows.
  int _generation = 0;

  /// Extra genre rows shown on the home screen (TMDB TV genre id -> title), so
  /// there's plenty to browse beyond the main category rows. Animation (16) is
  /// deliberately excluded - it lives in the dedicated Anime section instead
  /// of duplicating that content here.
  static const List<(int, String)> _homeGenres = [
    (10759, 'Action & Adventure'),
    (35, 'Comedy'),
    (18, 'Drama'),
    (80, 'Crime'),
    (9648, 'Mystery'),
    (10765, 'Sci-Fi & Fantasy'),
    (10768, 'War & Politics'),
  ];

  /// Loads every home row (categories + genre rows + the genre list) in
  /// parallel so the screen fills in one pass. On The Air / Airing Today were
  /// dropped entirely (not just topped up deeper) - currently-airing episodes
  /// are genuinely thin on torrent availability right after broadcast once
  /// CAM/TS/SCR are excluded, so they were frequently just empty rows; the
  /// genre rows below (deep, well-established catalogues) fill that space
  /// with content that's actually there.
  Future<void> loadHome() async {
    // This load's generation: if another loadHome() is dispatched (e.g.
    // pull-to-refresh) before this one finishes, `_generation` moves past
    // `gen` and every emit below becomes a no-op - the newer load wins and
    // this one's (possibly stale) results never overwrite it.
    final gen = ++_generation;
    void safeEmit(TvHomeState s) {
      if (gen == _generation && !isClosed) emit(s);
    }

    safeEmit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      final mainFuture = Future.wait([
        _datasource.getTrendingTv(),
        _datasource.getPopularTv(),
        _datasource.getTopRatedTv(),
      ]);
      // Keep genreId alongside each row (needed to top up that genre from
      // later pages below); dropped once genre sections reach the state.
      final genreRowsFuture = Future.wait(_homeGenres.map((g) async {
        try {
          final r = await _datasource.discoverTvByGenre(genreId: g.$1);
          return (g.$1, g.$2, r.shows);
        } catch (_) {
          return (g.$1, g.$2, const <TvModel>[]);
        }
      }));
      // Genres are non-critical: a failure here shouldn't blank the rows.
      final genresListFuture = _datasource.getTvGenres().catchError((_) => const <GenreModel>[]);

      final results = await mainFuture;
      final genreRowsRaw = (await genreRowsFuture).where((s) => s.$3.isNotEmpty).toList();
      final genres = await genresListFuture;

      final trending = results[0].shows;
      final popular = results[1].shows;
      final topRated = results[2].shows;

      // Pre-filter using cache (known unavailable shows hidden even on first
      // render) so subsequent loads don't show unfiltered TMDB while waiting
      // for background probing to complete.
      final avail = sl<StreamAvailabilityService>();
      final trendingPre = trending.where((s) => !avail.isKnownUnavailable(PlaybackMediaType.tv, s.id)).toList();
      final popularPre = popular.where((s) => !avail.isKnownUnavailable(PlaybackMediaType.tv, s.id)).toList();
      final topRatedPre = topRated.where((s) => !avail.isKnownUnavailable(PlaybackMediaType.tv, s.id)).toList();
      final genresSectionsPre = genreRowsRaw.map((s) => (s.$2, s.$3.where((show) => !avail.isKnownUnavailable(PlaybackMediaType.tv, show.id)).toList())).toList();

      safeEmit(state.copyWith(
        trending: trendingPre,
        popular: popularPre,
        topRated: topRatedPre,
        genreSections: genresSectionsPre,
        genres: genres,
        isLoading: false,
      ));

      // Background availability fill (option B): rows are shown above; probe each
      // show via AIOStreams (a recent episode then S1E1), top up every pageable
      // row - including each genre row - to target across a few pages, and
      // re-emit with unstreamable shows removed.
      final prober = sl<AvailabilityProber>();
      PlaybackRequest req(TvModel s) => PlaybackRequest(
            tmdbId: s.id,
            mediaType: PlaybackMediaType.tv,
            title: s.name,
            seasonNumber: 1,
            episodeNumber: 1,
            posterPath: s.posterPath,
          );
      Future<List<TvModel>> fill(List<TvModel> first, Future<List<TvModel>> Function(int) fetch, {int maxPages = 3}) =>
          prober.fillAvailable<TvModel>(
            mediaType: PlaybackMediaType.tv,
            firstPage: first,
            fetchPage: fetch,
            idOf: (s) => s.id,
            toRequest: req,
            maxPages: maxPages,
          );
      // Each row's fill runs as its own future and re-emits the instant it
      // lands, instead of one row's `await` blocking the next from even
      // starting. Rows share `prober`'s global request gate, so running them
      // concurrently finishes sooner without multiplying total AIOStreams load.
      var trendingF = trending;
      var popularF = popular;
      var topRatedF = topRated;
      var genreSectionsF = genreRowsRaw.map((s) => (s.$2, s.$3)).toList();

      // Superseded by a newer loadHome() (e.g. pull-to-refresh) while probing
      // ran - drop this result rather than overwrite the fresher one.
      void safeEmitRow() {
        if (gen != _generation || isClosed) return;
        emit(state.copyWith(
          trending: trendingF,
          popular: popularF,
          topRated: topRatedF,
          genreSections: genreSectionsF,
        ));
      }

      final fillFutures = <Future<void>>[
        fill(trending, (p) => _datasource.getTrendingTv(page: p).then((r) => r.shows)).then((r) {
          trendingF = r;
          safeEmitRow();
        }).catchError((_) {}),
        fill(popular, (p) => _datasource.getPopularTv(page: p).then((r) => r.shows)).then((r) {
          popularF = r;
          safeEmitRow();
        }).catchError((_) {}),
        fill(topRated, (p) => _datasource.getTopRatedTv(page: p).then((r) => r.shows)).then((r) {
          topRatedF = r;
          safeEmitRow();
        }).catchError((_) {}),
      ];
      // Genre rows top up too (each capped at the prober's default 3 pages) -
      // without this, a genre whose page-1 picks skew unavailable (e.g.
      // Crime/Mystery) ends up nearly empty instead of refilled.
      for (var i = 0; i < genreRowsRaw.length; i++) {
        final s = genreRowsRaw[i];
        fillFutures.add(fill(s.$3, (p) => _datasource.discoverTvByGenre(genreId: s.$1, page: p).then((r) => r.shows)).then((filled) {
          genreSectionsF = [
            for (var j = 0; j < genreSectionsF.length; j++)
              j == i ? (s.$2, filled) : genreSectionsF[j],
          ];
          safeEmitRow();
        }).catchError((_) {})); // fail-open: keep this genre row as first shown
      }
      await Future.wait(fillFutures);
    } catch (_) {
      safeEmit(state.copyWith(isLoading: false, errorMessage: 'Failed to load TV shows.'));
    }
  }

  /// Kept for callers that still expect the old entry point.
  Future<void> loadTrending() => loadHome();

  Future<void> filterByGenre(int genreId, String genreName) async {
    emit(state.withGenre(genreId: genreId, genreName: genreName, isLoadingGenre: true, genreResults: const []));
    try {
      final result = await _datasource.discoverTvByGenre(genreId: genreId);
      emit(state.withGenre(genreId: genreId, genreName: genreName, genreResults: result.shows, isLoadingGenre: false));
    } catch (_) {
      emit(state.withGenre(genreId: genreId, genreName: genreName, genreResults: const [], isLoadingGenre: false));
    }
  }

  void clearGenre() {
    emit(state.withGenre(genreId: null, genreName: null, genreResults: const [], isLoadingGenre: false));
  }

  Future<void> search(String query) async {
    emit(state.copyWith(query: query));
    if (query.trim().isEmpty) {
      emit(state.copyWith(searchResults: const []));
      return;
    }
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      final result = await _datasource.searchTv(query: query);
      emit(state.copyWith(searchResults: result.shows, isLoading: false));
    } catch (_) {
      emit(state.copyWith(isLoading: false, errorMessage: 'Search failed.'));
    }
  }
}
