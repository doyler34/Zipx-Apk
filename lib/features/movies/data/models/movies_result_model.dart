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
        // Skip entries with no poster - a card with no image is just an empty
        // placeholder, so it shouldn't appear in any list/search/grid.
        if (movie.posterPath.trim().isNotEmpty) movies!.add(movie);
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
