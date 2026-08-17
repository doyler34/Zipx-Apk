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
    this.onTheAir = const [],
    this.airingToday = const [],
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
  final List<TvModel> onTheAir;
  final List<TvModel> airingToday;
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
    List<TvModel>? onTheAir,
    List<TvModel>? airingToday,
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
      onTheAir: onTheAir ?? this.onTheAir,
      airingToday: airingToday ?? this.airingToday,
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
      onTheAir: onTheAir,
      airingToday: airingToday,
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
        onTheAir,
        airingToday,
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

  /// Extra genre rows shown on the home screen (TMDB TV genre id -> title), so
  /// there's plenty to browse beyond the main category rows.
  static const List<(int, String)> _homeGenres = [
    (10759, 'Action & Adventure'),
    (35, 'Comedy'),
    (18, 'Drama'),
    (80, 'Crime'),
    (9648, 'Mystery'),
    (10765, 'Sci-Fi & Fantasy'),
    (16, 'Animation'),
    (10768, 'War & Politics'),
  ];

  /// Loads every home row (categories + genre rows + the genre list) in
  /// parallel so the screen fills in one pass.
  Future<void> loadHome() async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      final mainFuture = Future.wait([
        _datasource.getTrendingTv(),
        _datasource.getPopularTv(),
        _datasource.getTopRatedTv(),
        _datasource.getOnTheAirTv(),
        _datasource.getAiringTodayTv(),
      ]);
      final genreRowsFuture = Future.wait(_homeGenres.map((g) async {
        try {
          final r = await _datasource.discoverTvByGenre(genreId: g.$1);
          return (g.$2, r.shows);
        } catch (_) {
          return (g.$2, const <TvModel>[]);
        }
      }));
      // Genres are non-critical: a failure here shouldn't blank the rows.
      final genresListFuture = _datasource.getTvGenres().catchError((_) => const <GenreModel>[]);

      final results = await mainFuture;
      final genreRows = (await genreRowsFuture).where((s) => s.$2.isNotEmpty).toList();
      final genres = await genresListFuture;

      final trending = results[0].shows;
      final popular = results[1].shows;
      final topRated = results[2].shows;
      final onTheAir = results[3].shows;
      final airingToday = results[4].shows;
      emit(state.copyWith(
        trending: trending,
        popular: popular,
        topRated: topRated,
        onTheAir: onTheAir,
        airingToday: airingToday,
        genreSections: genreRows,
        genres: genres,
        isLoading: false,
      ));

      // Background availability fill (option B): rows are shown above; probe each
      // show (as S1E1) via AIOStreams, then re-emit with the unstreamable ones
      // removed. Fail-open.
      final all = <TvModel>[...trending, ...popular, ...topRated, ...onTheAir, ...airingToday];
      for (final s in genreRows) {
        all.addAll(s.$2);
      }
      final requests = all
          .map((s) => PlaybackRequest(
                tmdbId: s.id,
                mediaType: PlaybackMediaType.tv,
                title: s.name,
                seasonNumber: 1,
                episodeNumber: 1,
                posterPath: s.posterPath,
              ))
          .toList();
      try {
        await sl<AvailabilityProber>().probe(PlaybackMediaType.tv, requests);
      } catch (_) {
        return; // fail-open
      }
      if (isClosed) return;
      final avail = sl<StreamAvailabilityService>();
      List<TvModel> keep(List<TvModel> xs) =>
          xs.where((s) => !avail.isKnownUnavailable(PlaybackMediaType.tv, s.id)).toList();
      emit(state.copyWith(
        trending: keep(trending),
        popular: keep(popular),
        topRated: keep(topRated),
        onTheAir: keep(onTheAir),
        airingToday: keep(airingToday),
        genreSections: [for (final s in genreRows) (s.$1, keep(s.$2))],
      ));
    } catch (_) {
      emit(state.copyWith(isLoading: false, errorMessage: 'Failed to load TV shows.'));
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
