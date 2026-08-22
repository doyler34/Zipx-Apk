import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:movie_bloc_app/core/dependency_injection/di.dart';
import 'package:movie_bloc_app/core/playback/domain/entities/playback_media_type.dart';
import 'package:movie_bloc_app/core/playback/services/stream_availability_service.dart';
import 'package:movie_bloc_app/core/utils/helpers/helper_functions.dart';

import 'package:movie_bloc_app/features/movies/domain/usecases/get_nowplaying.dart';
import 'package:movie_bloc_app/features/movies/domain/usecases/get_popular.dart';
import 'package:movie_bloc_app/features/movies/domain/usecases/get_toprated.dart';
import 'package:movie_bloc_app/features/movies/domain/usecases/get_upcoming.dart';

import '../../../../data/models/movie_model.dart';
import '../../../../domain/entities/params/params.dart';

part 'all_movies_event.dart';
part 'all_movies_state.dart';

class AllMoviesBloc extends Bloc<AllMoviesEvent, AllMoviesState> {
  GetUpcoming getUpcoming;
  GetNowplaying getNowplaying;
  GetToprated getToprated;
  GetPopular getPopular;

  List<MovieModel> allMovies = [];
  int currentPage = 1;
  int maxPages = 0;

  bool isMaxPage = false;

  // Guards against overlapping LoadMoreAllMovies dispatches (e.g. the
  // no-scroll-yet auto top-up below firing again before the previous page
  // finished) corrupting currentPage/maxPages with a concurrent fetch.
  bool _isFetchingMore = false;

  // Bounds LoadMoreAllMovies(auto: true) dispatches (fired by AllMoviesSection
  // when a page came back too short to fill/scroll, so the normal
  // scroll-triggered load-more would never fire on its own) - without this, a
  // section that's mostly unavailable could auto-fetch page after page
  // indefinitely. A real user scroll is unbounded (uses auto: false).
  static const int _autoTopUpBudget = 8;
  int _autoTopUpsUsed = 0;

  // Same cache-based availability filter the Home rows already apply, so
  // "See More" is the same catalogue at a different depth instead of a
  // separate, unfiltered one - dead-end titles the row hides don't
  // reappear here. `allMovies` itself stays the raw accumulated list (so
  // pagination bookkeeping tracks the real TMDB pages); this is only
  // applied at emit time.
  List<MovieModel> _filterAvailable(List<MovieModel> movies) {
    final avail = sl<StreamAvailabilityService>();
    return movies.where((m) => !avail.isKnownUnavailable(PlaybackMediaType.movie, m.id)).toList();
  }

  AllMoviesBloc({
    required this.getUpcoming,
    required this.getNowplaying,
    required this.getToprated,
    required this.getPopular,
  }) : super(AllMoviesInitial()) {
    on<FetchAllMovies>((event, emit) async {
      allMovies.clear();
      currentPage = 1;
      maxPages = 1;
      isMaxPage = false;
      _isFetchingMore = false;
      _autoTopUpsUsed = 0;

      final hasConnection = await HelperFunctions.hasConnection();
      if (!hasConnection) {
        emit(const AllMoviesError(message: 'No internet connection'));
        return;
      }

      emit(AllMoviesLoading());

      try {
        if (event.section == 'upcoming') {
          final upcomingMovies = await getUpcoming(Params(page: currentPage));
          allMovies.addAll(upcomingMovies.movies!);
          maxPages = upcomingMovies.totalPages!;
        } else if (event.section == 'now_playing') {
          final nowplayingMovies = await getNowplaying(Params(page: currentPage));
          allMovies.addAll(nowplayingMovies.movies!);
          maxPages = nowplayingMovies.totalPages!;
        } else if (event.section == 'top_rated') {
          final topratedMovies = await getToprated(Params(page: currentPage));
          allMovies.addAll(topratedMovies.movies!);
          maxPages = topratedMovies.totalPages!;
        } else if (event.section == 'popular') {
          final popularMovies = await getPopular(Params(page: currentPage));
          allMovies.addAll(popularMovies.movies!);
          maxPages = popularMovies.totalPages!;
        }

        if (allMovies.isEmpty) {
          emit(const AllMoviesError(message: 'No movies found'));
          return;
        }

        if (currentPage == maxPages) {
          isMaxPage = true;
        }

        emit(AllMoviesLoaded(movies: _filterAvailable(allMovies), isMaxPage: isMaxPage));
      } catch (e) {
        emit(const AllMoviesError(message: 'Error fetching movies'));
      }
    });
    on<LoadMoreAllMovies>((event, emit) async {
      if (_isFetchingMore || isMaxPage) return;
      if (event.auto) {
        if (_autoTopUpsUsed >= _autoTopUpBudget) {
          // Given up auto-topping-up (still not scrollable, so the user can't
          // trigger a manual load-more either) - stop the spinner and show
          // what was actually gathered instead of spinning forever.
          isMaxPage = true;
          emit(AllMoviesLoaded(movies: _filterAvailable(allMovies), isMaxPage: isMaxPage));
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
          if (event.section == 'upcoming') {
            final upcomingMovies = await getUpcoming(Params(page: currentPage));
            allMovies.addAll(upcomingMovies.movies!);
            maxPages = upcomingMovies.totalPages!;
          } else if (event.section == 'now_playing') {
            final nowplayingMovies = await getNowplaying(Params(page: currentPage));
            allMovies.addAll(nowplayingMovies.movies!);
            maxPages = nowplayingMovies.totalPages!;
          } else if (event.section == 'top_rated') {
            final topratedMovies = await getToprated(Params(page: currentPage));
            allMovies.addAll(topratedMovies.movies!);
            maxPages = topratedMovies.totalPages!;
          } else if (event.section == 'popular') {
            final popularMovies = await getPopular(Params(page: currentPage));
            allMovies.addAll(popularMovies.movies!);
            maxPages = popularMovies.totalPages!;
          }

          emit(AllMoviesLoading());
          emit(AllMoviesLoaded(movies: _filterAvailable(allMovies), isMaxPage: isMaxPage));
        } catch (e) {
          currentPage--;
          emit(const AllMoviesError(message: 'Error fetching movies'));
        }
      } finally {
        _isFetchingMore = false;
      }
    });
  }
}
