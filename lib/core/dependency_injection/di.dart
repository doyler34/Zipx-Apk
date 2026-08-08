import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:movie_bloc_app/common/blocs/bloc/nav_bar_bloc.dart';
import 'package:movie_bloc_app/core/playback/domain/providers/streaming_provider.dart';
import 'package:movie_bloc_app/core/playback/domain/providers/streaming_provider_registry.dart';
import 'package:movie_bloc_app/core/playback/domain/providers/template_embed_provider.dart';
import 'package:movie_bloc_app/core/playback/domain/providers/vidsrc_provider.dart';
import 'package:movie_bloc_app/core/playback/services/favourite_service.dart';
import 'package:movie_bloc_app/core/playback/services/playback_history_service.dart';
import 'package:movie_bloc_app/core/playback/services/playback_provider_service.dart';
import 'package:movie_bloc_app/core/playback/services/anime_addons_service.dart';
import 'package:movie_bloc_app/core/playback/services/provider_preferences_service.dart';
import 'package:movie_bloc_app/core/playback/services/stream_availability_service.dart';
import 'package:movie_bloc_app/core/playback/services/stream_sources_service.dart';
import 'package:movie_bloc_app/core/playback/services/subtitle_service.dart';
import 'package:movie_bloc_app/core/settings/user_settings.dart';
import 'package:movie_bloc_app/features/movies/data/datasources/remote/tmdb_datasource.dart';
import 'package:movie_bloc_app/features/movies/data/models/movie_model.dart';
import 'package:movie_bloc_app/features/movies/data/repositories/movie_repo_impl.dart';
import 'package:movie_bloc_app/features/movies/domain/repositories/movie_repo.dart';
import 'package:movie_bloc_app/features/movies/domain/usecases/get_genres.dart';
import 'package:movie_bloc_app/features/movies/domain/usecases/get_movie_details.dart';
import 'package:movie_bloc_app/features/movies/domain/usecases/get_movie_reviews.dart';
import 'package:movie_bloc_app/features/movies/domain/usecases/get_movies_by_genre.dart';
import 'package:movie_bloc_app/features/movies/domain/usecases/get_nowplaying.dart';
import 'package:movie_bloc_app/features/movies/domain/usecases/get_search_movies.dart';
import 'package:movie_bloc_app/features/movies/domain/usecases/get_popular.dart';
import 'package:movie_bloc_app/features/movies/domain/usecases/get_similar.dart';
import 'package:movie_bloc_app/features/movies/domain/usecases/get_toprated.dart';
import 'package:movie_bloc_app/features/movies/domain/usecases/get_trending.dart';
import 'package:movie_bloc_app/features/movies/domain/usecases/get_upcoming.dart';
import 'package:movie_bloc_app/features/movies/presentation/blocs/details/reviews/reviews_bloc.dart';
import 'package:movie_bloc_app/features/movies/presentation/blocs/home/all_movies/all_movies_bloc.dart';
import 'package:movie_bloc_app/features/movies/presentation/blocs/home/carousel/carousel_bloc.dart';
import 'package:movie_bloc_app/features/movies/presentation/blocs/home/genre_movies/genre_movies_bloc.dart';
import 'package:movie_bloc_app/features/movies/presentation/blocs/home/home/home_bloc.dart';
import 'package:movie_bloc_app/features/movies/presentation/blocs/search/search/search_bloc.dart';
import 'package:movie_bloc_app/features/personalization/presentation/blocs/bookmarks/bookmarks_bloc.dart';
import 'package:movie_bloc_app/features/personalization/presentation/blocs/settings/settings_bloc.dart';
import 'package:movie_bloc_app/features/tv/data/datasources/remote/tmdb_tv_datasource.dart';
import 'package:movie_bloc_app/features/tv/presentation/blocs/tv_details_cubit.dart';
import 'package:movie_bloc_app/features/tv/presentation/blocs/tv_home_cubit.dart';

import '../../features/movies/presentation/blocs/details/details/details_bloc.dart';

final sl = GetIt.instance;

Future initDependencyInjection() async {
  //Datasources
  sl.registerLazySingleton<Dio>(() => Dio());
  sl.registerLazySingleton<TmdbDatasource>(() => TmdbDatasource(sl()));
  sl.registerLazySingleton<MovieRepo>(() => MovieRepoImpl(tmdbDatasource: sl()));
  sl.registerLazySingleton<TmdbTvDatasource>(() => TmdbTvDatasource(sl()));

  // --- Streaming provider architecture -------------------------------
  // Every embedded playback provider is registered exactly once, here.
  // To add a new provider later: implement `StreamingProvider` in its own
  // file under core/playback/domain/providers/, then add one line to this
  // list. Nothing else in the app (registry, services, player UI,
  // settings screen) needs to change.
  sl.registerLazySingleton<StreamingProviderRegistry>(
    () => StreamingProviderRegistry(<StreamingProvider>[
      // VidSrc stays first (priority 0) so it remains the default that
      // auto-plays. The rest are a TEST BATCH - switch to them from the
      // player's provider button to find which also come out ad-free under
      // our navigation blocking; we'll trim to the winners afterwards.
      VidSrcProvider(),
      ...buildEmbedProviders(),
    ]),
  );
  sl.registerLazySingleton<ProviderPreferencesService>(() => ProviderPreferencesService(sl()));
  sl.registerLazySingleton<PlaybackProviderService>(() => PlaybackProviderService(sl(), sl(), sl()));
  sl.registerLazySingleton<PlaybackHistoryService>(() => PlaybackHistoryService());
  sl.registerLazySingleton<StreamAvailabilityService>(() => StreamAvailabilityService());
  sl.registerLazySingleton<AnimeAddonsService>(() => AnimeAddonsService());
  sl.registerLazySingleton<StreamSourcesService>(() => StreamSourcesService(sl<Dio>()));
  sl.registerLazySingleton<SubtitleService>(() => SubtitleService(sl<Dio>()));
  sl.registerLazySingleton<FavouriteService>(() => FavouriteService());

  //Others
  sl.registerSingleton<TextEditingController>(TextEditingController(), instanceName: 'search_controller');
  sl.registerSingleton<List<MovieModel>>([], instanceName: 'search_movies');

  sl.registerSingleton<List<MovieModel>>([], instanceName: 'bookmarks');
  sl.registerSingleton<List<int>>([], instanceName: 'bookmarkIds');

  sl.registerLazySingleton<UserSettings>(() => UserSettings());

  //Use cases
  sl.registerLazySingleton<GetPopular>(() => GetPopular(sl()));
  sl.registerLazySingleton<GetUpcoming>(() => GetUpcoming(sl()));
  sl.registerLazySingleton<GetGenres>(() => GetGenres(sl()));
  sl.registerLazySingleton<GetMovieDetails>(() => GetMovieDetails(sl()));
  sl.registerLazySingleton<GetSearchMovies>(() => GetSearchMovies(sl()));
  sl.registerLazySingleton<GetNowplaying>(() => GetNowplaying(sl()));
  sl.registerLazySingleton<GetToprated>(() => GetToprated(sl()));
  sl.registerLazySingleton<GetTrending>(() => GetTrending(sl()));
  sl.registerLazySingleton<GetSimilar>(() => GetSimilar(sl()));
  sl.registerLazySingleton<GetMoviesByGenre>(() => GetMoviesByGenre(sl()));
  sl.registerLazySingleton<GetMovieReviews>(() => GetMovieReviews(sl()));

  //Blocs
  sl.registerFactory(() => NavBarBloc());
  sl.registerFactory(() => CarouselBloc());

  sl.registerFactory(() => BookmarksBloc(
        bookmarks: sl(instanceName: 'bookmarks'),
        bookmarkIds: sl(instanceName: 'bookmarkIds'),
      ));

  sl.registerFactory(
    () => AllMoviesBloc(
      getUpcoming: sl(),
      getNowplaying: sl(),
      getToprated: sl(),
      getPopular: sl(),
    ),
  );

  sl.registerFactory(() => GenreMoviesBloc(getMoviesByGenre: sl()));

  sl.registerFactory(() => ReviewsBloc(getMovieReviews: sl()));

  //Pages Blocs
  sl.registerFactory(
    () => HomeBloc(
      getGenres: sl(),
      getUpcoming: sl(),
      getPopular: sl(),
      getNowPlaying: sl(),
      getTopRated: sl(),
      getTrending: sl(),
    ),
  );

  sl.registerFactory(() => DetailsBloc(getMovieDetails: sl(), getSimilar: sl()));

  sl.registerFactory(
    () => SearchBloc(
      getSearchMovies: sl(),
      controller: sl(instanceName: 'search_controller'),
      movies: sl(instanceName: 'search_movies'),
    ),
  );

  sl.registerFactory(() => SettingsBloc());

  sl.registerFactory(() => TvHomeCubit(sl()));
  sl.registerFactory(() => TvDetailsCubit(sl()));
}
