class TvSeasonSummaryModel {
  const TvSeasonSummaryModel({
    required this.seasonNumber,
    required this.name,
    required this.episodeCount,
    required this.posterPath,
  });

  final int seasonNumber;
  final String name;
  final int episodeCount;
  final String posterPath;

  factory TvSeasonSummaryModel.fromJson(Map<String, dynamic> json) {
    return TvSeasonSummaryModel(
      seasonNumber: json['season_number'] ?? 0,
      name: json['name'] ?? '',
      episodeCount: json['episode_count'] ?? 0,
      posterPath: json['poster_path'] ?? '',
    );
  }
}
