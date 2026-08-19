import 'package:equatable/equatable.dart';

import 'playback_media_type.dart';

/// A favourited movie or TV show. Kept separate from the pre-existing
/// movie-only bookmarks feature (`BookmarksBloc`) because favourites here
/// need to cover TV shows too, without changing how movie bookmarking
/// already works.
class FavouriteEntry extends Equatable {
  const FavouriteEntry({
    required this.tmdbId,
    required this.mediaType,
    required this.title,
    this.posterPath,
    this.isAnime = false,
  });

  final int tmdbId;
  final PlaybackMediaType mediaType;
  final String title;
  final String? posterPath;

  /// True for anime movies/series, so they're stored and shown separately
  /// from the regular Movies/TV Shows bookmarks instead of mixing in.
  final bool isAnime;

  // Anime gets its own key prefix so it lands in a separate bucket; existing
  // non-anime keys (`movie_123`, `tv_123`) are left exactly as they were so
  // bookmarks saved before this field existed keep working.
  String get storageKey => isAnime ? 'anime_${mediaType.name}_$tmdbId' : '${mediaType.name}_$tmdbId';

  Map<String, dynamic> toMap() {
    return {
      'tmdbId': tmdbId,
      'mediaType': mediaType.name,
      'title': title,
      'posterPath': posterPath,
      'isAnime': isAnime,
    };
  }

  factory FavouriteEntry.fromMap(Map<dynamic, dynamic> map) {
    return FavouriteEntry(
      tmdbId: map['tmdbId'] as int,
      mediaType: PlaybackMediaType.values.byName(map['mediaType'] as String),
      title: map['title'] as String,
      posterPath: map['posterPath'] as String?,
      isAnime: map['isAnime'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [tmdbId, mediaType, title, posterPath, isAnime];
}
