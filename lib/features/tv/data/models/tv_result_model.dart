import '../../../../core/dependency_injection/di.dart';
import '../../../../core/playback/domain/entities/playback_media_type.dart';
import '../../../../core/playback/services/stream_availability_service.dart';
import 'tv_model.dart';

class TvResultModel {
  const TvResultModel({
    required this.page,
    required this.totalPages,
    required this.shows,
  });

  final int page;
  final int totalPages;
  final List<TvModel> shows;

  factory TvResultModel.fromJson(Map<String, dynamic> json) {
    return TvResultModel(
      page: json['page'] ?? 1,
      totalPages: json['total_pages'] ?? 1,
      // Drop entries we can't show or play:
      //  - no poster: an empty placeholder card,
      //  - unstreamable genres (soaps, talk, news, reality): never have RD
      //    streams, so they'd only dead-end the user, and
      //  - titles already learned to have no streams (see StreamAvailability).
      shows: (json['results'] as List? ?? [])
          .map((e) => TvModel.fromJson(e))
          .where((s) =>
              s.posterPath.trim().isNotEmpty &&
              !s.isLikelyUnstreamable &&
              !sl<StreamAvailabilityService>().isKnownUnavailable(PlaybackMediaType.tv, s.id))
          .toList(),
    );
  }
}
