part of 'all_movies_bloc.dart';

sealed class AllMoviesEvent extends Equatable {
  const AllMoviesEvent();

  @override
  List<Object> get props => [];
}

class FetchAllMovies extends AllMoviesEvent {
  final String section;

  const FetchAllMovies(this.section);

  @override
  List<Object> get props => [section];
}

class LoadMoreAllMovies extends AllMoviesEvent {
  final String section;

  /// True when this was fired automatically because the current page didn't
  /// fill/scroll (see AllMoviesSection), rather than by the user scrolling.
  /// Auto top-ups are budgeted (see [AllMoviesBloc._autoTopUpBudget]) so a
  /// category that's mostly unavailable can't turn into an unbounded fetch
  /// loop; a real scroll always proceeds regardless of the budget.
  final bool auto;

  const LoadMoreAllMovies(this.section, {this.auto = false});

  @override
  List<Object> get props => [section, auto];
}
