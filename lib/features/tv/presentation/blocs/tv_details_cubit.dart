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

  Future<void> loadDetails(int tvId) async {
    emit(state.copyWith(isLoadingDetails: true, errorMessage: null));
    try {
      final details = await _datasource.getTvDetails(id: tvId);
      emit(state.copyWith(details: details, isLoadingDetails: false));
      if (details.seasons.isNotEmpty) {
        await loadSeason(tvId, details.seasons.first.seasonNumber);
      }
    } catch (_) {
      emit(state.copyWith(isLoadingDetails: false, errorMessage: 'Failed to load show details.'));
    }
  }

  Future<void> loadSeason(int tvId, int seasonNumber) async {
    emit(state.copyWith(selectedSeason: seasonNumber, isLoadingEpisodes: true, errorMessage: null));
    try {
      final season = await _datasource.getSeasonDetails(tvId: tvId, seasonNumber: seasonNumber);
      emit(state.copyWith(episodes: season.episodes, isLoadingEpisodes: false));
    } catch (_) {
      emit(state.copyWith(isLoadingEpisodes: false, errorMessage: 'Failed to load episodes.'));
    }
  }
}
