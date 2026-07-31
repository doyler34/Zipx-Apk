import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/datasources/remote/tmdb_tv_datasource.dart';
import '../../data/models/tv_model.dart';

class TvHomeState extends Equatable {
  const TvHomeState({
    this.trending = const [],
    this.searchResults = const [],
    this.query = '',
    this.isLoading = false,
    this.errorMessage,
  });

  final List<TvModel> trending;
  final List<TvModel> searchResults;
  final String query;
  final bool isLoading;
  final String? errorMessage;

  bool get isSearching => query.trim().isNotEmpty;

  TvHomeState copyWith({
    List<TvModel>? trending,
    List<TvModel>? searchResults,
    String? query,
    bool? isLoading,
    String? errorMessage,
  }) {
    return TvHomeState(
      trending: trending ?? this.trending,
      searchResults: searchResults ?? this.searchResults,
      query: query ?? this.query,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [trending, searchResults, query, isLoading, errorMessage];
}

/// Lightweight Cubit (rather than the full Bloc event/state boilerplate used
/// by the movies feature) for the small amount of TV browsing this app
/// needs. Same `flutter_bloc` state-management approach as the rest of the
/// app, just less ceremony for a two-endpoint screen.
class TvHomeCubit extends Cubit<TvHomeState> {
  TvHomeCubit(this._datasource) : super(const TvHomeState());

  final TmdbTvDatasource _datasource;

  Future<void> loadTrending() async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      final result = await _datasource.getTrendingTv();
      emit(state.copyWith(trending: result.shows, isLoading: false));
    } catch (_) {
      emit(state.copyWith(isLoading: false, errorMessage: 'Failed to load trending TV shows.'));
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
      final result = await _datasource.searchTv(query: query);
      emit(state.copyWith(searchResults: result.shows, isLoading: false));
    } catch (_) {
      emit(state.copyWith(isLoading: false, errorMessage: 'Search failed.'));
    }
  }
}
