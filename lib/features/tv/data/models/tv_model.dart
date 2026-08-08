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
    this.genreIds = const [],
  });

  /// TMDB genre ids from list endpoints (kept out of [TvEntity] since it's a
  /// data-layer detail used only for stream-availability filtering).
  final List<int> genreIds;

  /// TMDB TV genres that essentially never have torrents / Real-Debrid streams:
  /// News (10763), Reality (10764), Soap (10766), Talk (10767). Titles in these
  /// are hidden from browsing so the catalogue only shows playable shows.
  static const Set<int> unstreamableGenreIds = {10763, 10764, 10766, 10767};

  bool get isLikelyUnstreamable => genreIds.any(unstreamableGenreIds.contains);

  factory TvModel.fromJson(Map<String, dynamic> json) {
    return TvModel(
      id: json['id'],
      name: json['name'] ?? '',
      overview: json['overview'] ?? '',
      posterPath: json['poster_path'] ?? '',
      backdropPath: json['backdrop_path'] ?? '',
      voteAverage: (json['vote_average'] ?? 0).toDouble(),
      firstAirDate: json['first_air_date'] ?? '',
      genreIds: (json['genre_ids'] as List?)?.whereType<int>().toList() ?? const [],
    );
  }
}
