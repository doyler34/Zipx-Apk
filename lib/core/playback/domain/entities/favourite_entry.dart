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
  });

  final int tmdbId;
  final PlaybackMediaType mediaType;
  final String title;
  final String? posterPath;

  String get storageKey => '${mediaType.name}_$tmdbId';

  Map<String, dynamic> toMap() {
    return {
      'tmdbId': tmdbId,
      'mediaType': mediaType.name,
      'title': title,
      'posterPath': posterPath,
    };
  }

  factory FavouriteEntry.fromMap(Map<dynamic, dynamic> map) {
    return FavouriteEntry(
      tmdbId: map['tmdbId'] as int,
      mediaType: PlaybackMediaType.values.byName(map['mediaType'] as String),
      title: map['title'] as String,
      posterPath: map['posterPath'] as String?,
    );
  }

  @override
  List<Object?> get props => [tmdbId, mediaType, title, posterPath];
}
