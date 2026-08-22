import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:movie_bloc_app/core/dependency_injection/di.dart';
import 'package:movie_bloc_app/core/playback/domain/entities/playback_media_type.dart';
import 'package:movie_bloc_app/core/playback/services/stream_availability_service.dart';
import 'package:movie_bloc_app/core/utils/helpers/helper_functions.dart';
import 'package:movie_bloc_app/features/movies/data/models/movie_model.dart';
import 'package:movie_bloc_app/features/movies/domain/entities/params/params.dart';
import 'package:movie_bloc_app/features/movies/domain/usecases/get_movies_by_genre.dart';

part 'genre_movies_event.dart';
part 'genre_movies_state.dart';

class GenreMoviesBloc extends Bloc<GenreMoviesEvent, GenreMoviesState> {
  final GetMoviesByGenre getMoviesByGenre;

  List<MovieModel> movies = [];
  int selectedYear = DateTime.now().year;
  bool isMaxPage = false;
  int currentPage = 1;
  int maxPages = 1;
  String genreId = '28';

  // Guards against overlapping FetchMoreGenreMovies dispatches (e.g. the
  // no-scroll-yet auto top-up below firing again before the previous page
  // finished) corrupting currentPage/maxPages with a concurrent fetch.
  bool _isFetchingMore = false;

  // Bounds FetchMoreGenreMovies(auto: true) dispatches (fired by GenreMovies
  // when a page came back too short to fill/scroll, so the normal
  // scroll-triggered load-more would never fire on its own) - without this, a
  // genre/year combo that's mostly unavailable could auto-fetch page after
  // page indefinitely. A real user scroll is unbounded (uses auto: false).
  static const int _autoTopUpBudget = 8;
  int _autoTopUpsUsed = 0;

  // Same cache-based availability filter the Home rows already apply - see
  // AllMoviesBloc._filterAvailable for why. `movies` itself stays the raw
  // accumulated list so pagination bookkeeping tracks the real TMDB pages.
  List<MovieModel> _filterAvailable(List<MovieModel> movies) {
    final avail = sl<StreamAvailabilityService>();
    return movies.where((m) => !avail.isKnownUnavailable(PlaybackMediaType.movie, m.id)).toList();
  }

  GenreMoviesBloc({required this.getMoviesByGenre}) : super(GenreMoviesInitial()) {
    on<FetchGenreMovies>((event, emit) async {
      movies.clear();
      currentPage = 1;
      maxPages = 1;
      isMaxPage = false;
      genreId = '28';
      _isFetchingMore = false;
      _autoTopUpsUsed = 0;

      final hasConnection = await HelperFunctions.hasConnection();
      if (!hasConnection) {
        emit(const GenreMoviesError('No internet connection'));
        return;
      }

      emit(GenreMoviesLoading());

      genreId = event.genreId;
      selectedYear = event.year;

      try {
        final genreMovies = await getMoviesByGenre(Params(
          genreId: genreId,
          page: currentPage,
          year: selectedYear,
        ));
        movies.addAll(genreMovies.movies!);
        maxPages = genreMovies.totalPages!;

        if (currentPage == maxPages) {
          isMaxPage = true;
        }

        emit(GenreMoviesLoaded(_filterAvailable(movies), isMaxPage, selectedYear));
      } catch (e) {
        emit(const GenreMoviesError('Error fetching movies'));
      }
    });

    on<FetchMoreGenreMovies>((event, emit) async {
      if (_isFetchingMore || isMaxPage) return;
      if (event.auto) {
        if (_autoTopUpsUsed >= _autoTopUpBudget) {
          // Given up auto-topping-up (still not scrollable, so the user can't
          // trigger a manual load-more either) - stop the spinner and show
          // what was actually gathered instead of spinning forever.
          isMaxPage = true;
          emit(GenreMoviesLoaded(_filterAvailable(movies), isMaxPage, selectedYear));
          return;
        }
        _autoTopUpsUsed++;
      }
      _isFetchingMore = true;
      try {
        final hasConnection = await HelperFunctions.hasConnection();
        if (!hasConnection) {
          return;
        }

        currentPage++;

        if (currentPage == maxPages) {
          isMaxPage = true;
        }

        try {
          final genreMovies = await getMoviesByGenre(Params(
            genreId: genreId,
            page: currentPage,
            year: selectedYear,
          ));
          movies.addAll(genreMovies.movies!);
          maxPages = genreMovies.totalPages!;

          if (currentPage == maxPages) {
            isMaxPage = true;
          }

          emit(GenreMoviesLoading());
          emit(GenreMoviesLoaded(_filterAvailable(movies), isMaxPage, selectedYear));
        } catch (e) {
          currentPage--;
          emit(const GenreMoviesError('Error fetching movies'));
        }
      } finally {
        _isFetchingMore = false;
      }
    });
  }
}
