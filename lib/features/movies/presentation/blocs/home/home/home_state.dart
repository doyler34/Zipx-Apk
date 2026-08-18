part of 'home_bloc.dart';

/// A titled home row built from a genre (e.g. "Action" -> its movies) -
/// mirrors TvHomeCubit's TvSection for the same purpose.
typedef MovieSection = (String title, List<MovieModel> movies);

sealed class HomeState extends Equatable {
  const HomeState();

  @override
  List<Object> get props => [];
}

final class HomeInitial extends HomeState {}

final class HomeLoading extends HomeState {}

final class HomeLoaded extends HomeState {
  final MoviesResultModel popularMovies;
  final List<GenreModel> genres;
  final MoviesResultModel topRatedMovies;
  final MoviesResultModel trendingMovies;
  final List<MovieSection> genreSections;

  const HomeLoaded({
    required this.genres,
    required this.popularMovies,
    required this.topRatedMovies,
    required this.trendingMovies,
    this.genreSections = const [],
  });

  @override
  List<Object> get props => [
        genres,
        popularMovies,
        topRatedMovies,
        trendingMovies,
        genreSections,
      ];
}

final class HomeError extends HomeState {
  final String message;

  const HomeError(this.message);

  @override
  List<Object> get props => [message];
}
