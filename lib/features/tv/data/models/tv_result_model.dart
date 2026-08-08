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
      //  - no poster: an empty placeholder card, and
      //  - unstreamable genres (soaps, talk, news, reality): these never have
      //    Real-Debrid streams, so they'd only dead-end the user.
      shows: (json['results'] as List? ?? [])
          .map((e) => TvModel.fromJson(e))
          .where((s) => s.posterPath.trim().isNotEmpty && !s.isLikelyUnstreamable)
          .toList(),
    );
  }
}
