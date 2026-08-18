import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/datasources/remote/tmdb_tv_datasource.dart';
import '../../data/models/tv_details_model.dart';
import '../../data/models/tv_episode_model.dart';

class TvDetailsState extends Equatable {
  const TvDetailsState({
    this.details,
    this.selectedSeason,
    this.episodes = const [],
    this.isLoadingDetails = false,
    this.isLoadingEpisodes = false,
    this.errorMessage,
  });

  final TvDetailsModel? details;
  final int? selectedSeason;
  final List<TvEpisodeModel> episodes;
  final bool isLoadingDetails;
  final bool isLoadingEpisodes;
  final String? errorMessage;

  TvDetailsState copyWith({
    TvDetailsModel? details,
    int? selectedSeason,
    List<TvEpisodeModel>? episodes,
    bool? isLoadingDetails,
    bool? isLoadingEpisodes,
    String? errorMessage,
  }) {
    return TvDetailsState(
      details: details ?? this.details,
      selectedSeason: selectedSeason ?? this.selectedSeason,
      episodes: episodes ?? this.episodes,
      isLoadingDetails: isLoadingDetails ?? this.isLoadingDetails,
      isLoadingEpisodes: isLoadingEpisodes ?? this.isLoadingEpisodes,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [details, selectedSeason, episodes, isLoadingDetails, isLoadingEpisodes, errorMessage];
}

class TvDetailsCubit extends Cubit<TvDetailsState> {
  TvDetailsCubit(this._datasource) : super(const TvDetailsState());

  final TmdbTvDatasource _datasource;

  // A transient network hiccup shouldn't need the user to notice something's
  // wrong and tap a button - retry silently a couple more times first, with a
  // short gap between attempts. Only a fetch that keeps failing (no internet,
  // TMDB genuinely down) ever reaches the user, and even then the UI's Retry
  // button is a real fallback, not the primary way transient failures recover.
  static const int _maxAttempts = 3;

  Future<void> loadDetails(int tvId) async {
    emit(state.copyWith(isLoadingDetails: true, errorMessage: null));
    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        final details = await _datasource.getTvDetails(id: tvId);
        emit(state.copyWith(details: details, isLoadingDetails: false));
        if (details.seasons.isNotEmpty) {
          await loadSeason(tvId, details.seasons.first.seasonNumber);
        }
        return;
      } catch (_) {
        if (attempt == _maxAttempts) {
          emit(state.copyWith(isLoadingDetails: false, errorMessage: 'Failed to load show details.'));
          return;
        }
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }
    }
  }

  Future<void> loadSeason(int tvId, int seasonNumber) async {
    // Clear episodes up front (not just on success): otherwise switching
    // season - or retrying after a failure - keeps showing the PREVIOUS
    // season's episodes while loading/if it fails, with no indication
    // anything went wrong (the error banner only shows when episodes is
    // empty; stale data would silently hide it).
    emit(state.copyWith(selectedSeason: seasonNumber, episodes: const [], isLoadingEpisodes: true, errorMessage: null));
    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        final season = await _datasource.getSeasonDetails(tvId: tvId, seasonNumber: seasonNumber);
        emit(state.copyWith(episodes: season.episodes, isLoadingEpisodes: false));
        return;
      } catch (_) {
        if (attempt == _maxAttempts) {
          emit(state.copyWith(isLoadingEpisodes: false, errorMessage: 'Failed to load episodes.'));
          return;
        }
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }
    }
  }
}
