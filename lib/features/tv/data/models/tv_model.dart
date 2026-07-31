import '../../domain/entities/tv_entity.dart';

class TvModel extends TvEntity {
  const TvModel({
    required super.id,
    required super.name,
    required super.overview,
    required super.posterPath,
    required super.backdropPath,
    required super.voteAverage,
    required super.firstAirDate,
  });

  factory TvModel.fromJson(Map<String, dynamic> json) {
    return TvModel(
      id: json['id'],
      name: json['name'] ?? '',
      overview: json['overview'] ?? '',
      posterPath: json['poster_path'] ?? '',
      backdropPath: json['backdrop_path'] ?? '',
      voteAverage: (json['vote_average'] ?? 0).toDouble(),
      firstAirDate: json['first_air_date'] ?? '',
    );
  }
}
