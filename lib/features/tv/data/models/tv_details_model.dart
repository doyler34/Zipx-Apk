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
    required this.trailerKey,
  });

  final int numberOfSeasons;
  final List<TvSeasonSummaryModel> seasons;
  final List<String> genres;

  /// YouTube video id for the show's trailer (empty if none). Populated from
  /// TMDB `videos` (requires `append_to_response=videos`).
  final String trailerKey;

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
      trailerKey: _pickTrailer(json['videos']?['results']),
    );
  }

  /// Prefer a YouTube "Trailer"; fall back to a "Teaser".
  static String _pickTrailer(dynamic results) {
    if (results is! List) return '';
    Map? teaser;
    for (final v in results) {
      if (v is! Map || v['site'] != 'YouTube') continue;
      if (v['type'] == 'Trailer') return (v['key'] ?? '').toString();
      teaser ??= (v['type'] == 'Teaser') ? v : null;
    }
    return (teaser?['key'] ?? '').toString();
  }
}
