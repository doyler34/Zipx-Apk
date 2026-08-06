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
      // Drop entries with no poster - a card with no image is just an empty
      // placeholder, so it shouldn't appear in any list/search/grid.
      shows: (json['results'] as List? ?? [])
          .map((e) => TvModel.fromJson(e))
          .where((s) => s.posterPath.trim().isNotEmpty)
          .toList(),
    );
  }
}
