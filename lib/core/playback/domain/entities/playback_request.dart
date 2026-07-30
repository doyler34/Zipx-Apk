import 'package:equatable/equatable.dart';

import 'playback_media_type.dart';

/// Describes *what* the user wants to watch, independent of which
/// [StreamingProvider] will end up serving it.
///
/// The player screen and every provider implementation only ever see a
/// [PlaybackRequest] - never raw movie/TV widgets - which keeps provider
/// URL logic decoupled from the movie/TV presentation layer.
class PlaybackRequest extends Equatable {
  const PlaybackRequest({
    required this.tmdbId,
    required this.mediaType,
    required this.title,
    this.seasonNumber,
    this.episodeNumber,
    this.posterPath,
  });

  final int tmdbId;
  final PlaybackMediaType mediaType;
  final String title;

  /// Required when [mediaType] is [PlaybackMediaType.tv].
  final int? seasonNumber;

  /// Required when [mediaType] is [PlaybackMediaType.tv].
  final int? episodeNumber;

  /// Optional, used only for display (continue watching / history rows).
  final String? posterPath;

  bool get isTvEpisode => mediaType == PlaybackMediaType.tv;

  PlaybackRequest copyWith({
    int? seasonNumber,
    int? episodeNumber,
  }) {
    return PlaybackRequest(
      tmdbId: tmdbId,
      mediaType: mediaType,
      title: title,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      posterPath: posterPath,
    );
  }

  @override
  List<Object?> get props => [tmdbId, mediaType, title, seasonNumber, episodeNumber, posterPath];
}
