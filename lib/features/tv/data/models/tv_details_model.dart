import '../../domain/entities/tv_entity.dart';
import 'tv_season_summary_model.dart';

class TvDetailsModel extends TvEntity {
  const TvDetailsModel({
    required super.id,
    required super.name,
    required super.overview,
    required super.posterPath,
    required super.backdropPath,
    required super.voteAverage,
    required super.firstAirDate,
    required this.numberOfSeasons,
    required this.seasons,
    required this.genres,
  });

  final int numberOfSeasons;
  final List<TvSeasonSummaryModel> seasons;
  final List<String> genres;

  factory TvDetailsModel.fromJson(Map<String, dynamic> json) {
    return TvDetailsModel(
      id: json['id'],
      name: json['name'] ?? '',
      overview: json['overview'] ?? '',
      posterPath: json['poster_path'] ?? '',
      backdropPath: json['backdrop_path'] ?? '',
      voteAverage: (json['vote_average'] ?? 0).toDouble(),
      firstAirDate: json['first_air_date'] ?? '',
      numberOfSeasons: json['number_of_seasons'] ?? 0,
      seasons: (json['seasons'] as List? ?? [])
          .map((e) => TvSeasonSummaryModel.fromJson(e))
          .where((s) => s.seasonNumber > 0)
          .toList(),
      genres: (json['genres'] as List? ?? []).map((e) => (e['name'] ?? '').toString()).toList(),
    );
  }
}
