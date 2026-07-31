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
      shows: (json['results'] as List? ?? []).map((e) => TvModel.fromJson(e)).toList(),
    );
  }
}
