import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../movies/data/models/genre_model.dart';
import '../../data/datasources/remote/tmdb_tv_datasource.dart';
import '../../data/models/tv_model.dart';

class TvHomeState extends Equatable {
  const TvHomeState({
    this.trending = const [],
    this.popular = const [],
    this.topRated = const [],
    this.onTheAir = const [],
    this.airingToday = const [],
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

  /// Loads every home row (and the genre list) in parallel so the screen fills
  /// in one pass instead of one endpoint at a time.
  Future<void> loadHome() async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      final results = await Future.wait([
        _datasource.getTrendingTv(),
        _datasource.getPopularTv(),
        _datasource.getTopRatedTv(),
        _datasource.getOnTheAirTv(),
        _datasource.getAiringTodayTv(),
      ]);
      // Genres are non-critical: a failure here shouldn't blank the rows.
      List<GenreModel> genres = const [];
      try {
        genres = await _datasource.getTvGenres();
      } catch (_) {}

      emit(state.copyWith(
        trending: results[0].shows,
        popular: results[1].shows,
        topRated: results[2].shows,
        onTheAir: results[3].shows,
        airingToday: results[4].shows,
        genres: genres,
        isLoading: false,
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
