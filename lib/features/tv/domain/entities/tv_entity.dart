import 'package:equatable/equatable.dart';

class TvEntity extends Equatable {
  const TvEntity({
    required this.id,
    required this.name,
    required this.overview,
    required this.posterPath,
    required this.backdropPath,
    required this.voteAverage,
    required this.firstAirDate,
  });

  final int id;
  final String name;
  final String overview;
  final String posterPath;
  final String backdropPath;
  final double voteAverage;
  final String firstAirDate;

  @override
  List<Object?> get props => [id, name, overview, posterPath, backdropPath, voteAverage, firstAirDate];
}
