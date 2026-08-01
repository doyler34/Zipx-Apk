import '../../movies/data/models/movie_model.dart';
import '../../tv/data/models/tv_model.dart';

enum TvMediaKind { movie, tv }

/// A unified, display-oriented item for the TV home rows and hero banner, so
/// movie and TV data can share the same widgets. Wraps the existing
/// [MovieModel] / [TvModel] rather than replacing them.
class TvMediaItem {
  const TvMediaItem({
    required this.id,
    required this.title,
    required this.posterPath,
    required this.backdropPath,
    required this.overview,
    required this.voteAverage,
    required this.date,
    required this.kind,
    this.movie,
    this.tv,
  });

  final int id;
  final String title;
  final String posterPath;
  final String backdropPath;
  final String overview;
  final double voteAverage;
  final String date;
  final TvMediaKind kind;

  /// The original model, kept so navigation can pass it through unchanged.
  final MovieModel? movie;
  final TvModel? tv;

  String get year => date.trim().isNotEmpty ? date.split('-').first : '';

  factory TvMediaItem.fromMovie(MovieModel m) => TvMediaItem(
        id: m.id,
        title: m.title,
        posterPath: m.posterPath,
        backdropPath: m.backdropPath,
        overview: m.overview,
        voteAverage: m.voteAverage,
        date: m.releaseDate,
        kind: TvMediaKind.movie,
        movie: m,
      );

  factory TvMediaItem.fromTv(TvModel t) => TvMediaItem(
        id: t.id,
        title: t.name,
        posterPath: t.posterPath,
        backdropPath: t.backdropPath,
        overview: t.overview,
        voteAverage: t.voteAverage,
        date: t.firstAirDate,
        kind: TvMediaKind.tv,
        tv: t,
      );
}
