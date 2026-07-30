import 'tv_episode_model.dart';

class TvSeasonModel {
  const TvSeasonModel({
    required this.seasonNumber,
    required this.name,
    required this.episodes,
  });

  final int seasonNumber;
  final String name;
  final List<TvEpisodeModel> episodes;

  factory TvSeasonModel.fromJson(Map<String, dynamic> json) {
    return TvSeasonModel(
      seasonNumber: json['season_number'] ?? 0,
      name: json['name'] ?? '',
      episodes: (json['episodes'] as List? ?? []).map((e) => TvEpisodeModel.fromJson(e)).toList(),
    );
  }
}
