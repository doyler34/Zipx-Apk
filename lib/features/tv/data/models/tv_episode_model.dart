class TvEpisodeModel {
  const TvEpisodeModel({
    required this.episodeNumber,
    required this.seasonNumber,
    required this.name,
    required this.overview,
    required this.stillPath,
    required this.airDate,
    required this.voteAverage,
  });

  final int episodeNumber;
  final int seasonNumber;
  final String name;
  final String overview;
  final String stillPath;
  final String airDate;
  final double voteAverage;

  factory TvEpisodeModel.fromJson(Map<String, dynamic> json) {
    return TvEpisodeModel(
      episodeNumber: json['episode_number'] ?? 0,
      seasonNumber: json['season_number'] ?? 0,
      name: json['name'] ?? '',
      overview: json['overview'] ?? '',
      stillPath: json['still_path'] ?? '',
      airDate: json['air_date'] ?? '',
      voteAverage: (json['vote_average'] ?? 0).toDouble(),
    );
  }
}
