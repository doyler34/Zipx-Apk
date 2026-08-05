import 'package:dio/dio.dart';
import 'package:movie_bloc_app/core/dependency_injection/di.dart';
import 'package:movie_bloc_app/core/settings/user_settings.dart';
import 'package:movie_bloc_app/core/utils/strings/url_strings.dart';
import 'package:movie_bloc_app/features/movies/data/models/genre_model.dart';

import '../../models/tv_details_model.dart';
import '../../models/tv_result_model.dart';
import '../../models/tv_season_model.dart';

/// TMDB is kept as the single metadata provider for both movies and TV -
/// this datasource mirrors `TmdbDatasource` exactly, just for the `/tv`
/// family of endpoints. It has nothing to do with playback: it never
/// returns a streaming URL, only metadata.
class TmdbTvDatasource {
  final Dio dio;

  TmdbTvDatasource(this.dio);

  Future<TvResultModel> getTrendingTv({int page = 1}) async {
    Map<String, dynamic> settings = sl<UserSettings>().getSettings();
    settings['page'] = page;

    final response = await dio.get(
      '${UrlStrings.baseUrl}trending/tv/day',
      queryParameters: settings,
    );

    return TvResultModel.fromJson(response.data);
  }

  /// A category-list endpoint under the `/tv` family (popular, top_rated,
  /// on_the_air, airing_today). Same settings/paging handling as trending so
  /// the home screen can show several rows instead of just one.
  Future<TvResultModel> _getTvList(String path, {int page = 1}) async {
    Map<String, dynamic> settings = sl<UserSettings>().getSettings();
    settings['page'] = page;

    final response = await dio.get(
      '${UrlStrings.baseUrl}tv/$path',
      queryParameters: settings,
    );

    return TvResultModel.fromJson(response.data);
  }

  Future<TvResultModel> getPopularTv({int page = 1}) => _getTvList('popular', page: page);

  Future<TvResultModel> getTopRatedTv({int page = 1}) => _getTvList('top_rated', page: page);

  Future<TvResultModel> getOnTheAirTv({int page = 1}) => _getTvList('on_the_air', page: page);

  Future<TvResultModel> getAiringTodayTv({int page = 1}) => _getTvList('airing_today', page: page);

  /// The TMDB TV genre catalogue, reused for the home-screen genre filter.
  Future<List<GenreModel>> getTvGenres() async {
    Map<String, dynamic> settings = sl<UserSettings>().getSettings();

    final response = await dio.get(
      '${UrlStrings.baseUrl}genre/tv/list',
      queryParameters: {
        'api_key': settings['api_key'],
        'language': settings['language'],
      },
    );

    return (response.data['genres'] as List? ?? [])
        .map((e) => GenreModel.fromJson(e))
        .toList();
  }

  /// Shows for a single genre, most-popular first, via TMDB discover.
  Future<TvResultModel> discoverTvByGenre({required int genreId, int page = 1}) async {
    Map<String, dynamic> settings = sl<UserSettings>().getSettings();
    settings['page'] = page;
    settings['with_genres'] = genreId;
    settings['sort_by'] = 'popularity.desc';

    final response = await dio.get(
      '${UrlStrings.baseUrl}discover/tv',
      queryParameters: settings,
    );

    return TvResultModel.fromJson(response.data);
  }

  Future<TvResultModel> searchTv({required String query, int page = 1}) async {
    Map<String, dynamic> settings = sl<UserSettings>().getSettings();
    settings['query'] = query;
    settings['page'] = page;

    final response = await dio.get(
      '${UrlStrings.baseUrl}search/tv',
      queryParameters: settings,
    );

    return TvResultModel.fromJson(response.data);
  }

  Future<TvDetailsModel> getTvDetails({required int id}) async {
    Map<String, dynamic> settings = sl<UserSettings>().getSettings();

    final response = await dio.get(
      '${UrlStrings.baseUrl}tv/$id',
      queryParameters: {
        'api_key': settings['api_key'],
        'language': settings['language'],
      },
    );

    return TvDetailsModel.fromJson(response.data);
  }

  Future<TvSeasonModel> getSeasonDetails({required int tvId, required int seasonNumber}) async {
    Map<String, dynamic> settings = sl<UserSettings>().getSettings();

    final response = await dio.get(
      '${UrlStrings.baseUrl}tv/$tvId/season/$seasonNumber',
      queryParameters: {
        'api_key': settings['api_key'],
        'language': settings['language'],
      },
    );

    return TvSeasonModel.fromJson(response.data);
  }
}
