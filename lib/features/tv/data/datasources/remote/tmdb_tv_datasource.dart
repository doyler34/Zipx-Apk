import 'package:dio/dio.dart';
import 'package:movie_bloc_app/core/dependency_injection/di.dart';
import 'package:movie_bloc_app/core/settings/user_settings.dart';
import 'package:movie_bloc_app/core/utils/strings/url_strings.dart';

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
