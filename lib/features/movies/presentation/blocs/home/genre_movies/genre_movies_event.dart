part of 'genre_movies_bloc.dart';

sealed class GenreMoviesEvent extends Equatable {
  const GenreMoviesEvent();

  @override
  List<Object> get props => [];
}

final class FetchGenreMovies extends GenreMoviesEvent {
  final String genreId;
  final int year;

  const FetchGenreMovies(this.genreId, this.year);

  @override
  List<Object> get props => [genreId, year];
}

final class FetchMoreGenreMovies extends GenreMoviesEvent {
  /// True when this was fired automatically because the current page didn't
  /// fill/scroll (see GenreMovies), rather than by the user scrolling. Auto
  /// top-ups are budgeted (see [GenreMoviesBloc._autoTopUpBudget]) so a
  /// genre/year combo that's mostly unavailable can't turn into an unbounded
  /// fetch loop; a real scroll always proceeds regardless of the budget.
  final bool auto;

  const FetchMoreGenreMovies({this.auto = false});

  @override
  List<Object> get props => [auto];
}
