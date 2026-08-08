import '../../../../core/dependency_injection/di.dart';
import '../../../../core/playback/domain/entities/playback_media_type.dart';
import '../../../../core/playback/services/stream_availability_service.dart';
import 'movie_model.dart';

class MoviesResultModel {
  List<MovieModel>? movies;
  int? totalPages;

  MoviesResultModel({this.movies, this.totalPages});

  MoviesResultModel.fromJson(Map<String, dynamic> json) {
    if (json['results'] != null) {
      movies = <MovieModel>[];
      json['results'].forEach((v) {
        final movie = MovieModel.fromJson(v);
        // Skip entries with no poster (empty placeholder card) or ones already
        // learned to have no streams, so lists don't dead-end the user.
        final unavailable = sl<StreamAvailabilityService>().isKnownUnavailable(PlaybackMediaType.movie, movie.id);
        if (movie.posterPath.trim().isNotEmpty && !unavailable) movies!.add(movie);
      });
    } else {
      movies = [];
    }
    if (json['total_pages'] != null) {
      totalPages = json['total_pages'];
    } else {
      totalPages = 0;
    }
  }

  MoviesResultModel.empty() {
    movies = [];
    totalPages = 0;
  }
}
