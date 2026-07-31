import 'package:equatable/equatable.dart';

import 'playback_media_type.dart';
import 'playback_request.dart';

/// A single "continue watching" row: the last thing the user opened the
/// player for, which provider served it, and (only when technically
/// available) how far into it they were.
class PlaybackHistoryEntry extends Equatable {
  const PlaybackHistoryEntry({
    required this.tmdbId,
    required this.mediaType,
    required this.title,
    required this.providerId,
    required this.lastWatchedAt,
    this.seasonNumber,
    this.episodeNumber,
    this.posterPath,
    this.progressSeconds,
  });

  final int tmdbId;
  final PlaybackMediaType mediaType;
  final String title;
  final String providerId;
  final DateTime lastWatchedAt;
  final int? seasonNumber;
  final int? episodeNumber;
  final String? posterPath;

  /// Only populated when the provider's page actually reports progress back
  /// to us; embedded third-party players generally don't, so this is `null`
  /// in practice. Never inferred from the player being closed.
  final double? progressSeconds;

  /// One entry per title: a show's entry is overwritten (not duplicated)
  /// whenever a new episode is watched, so "continue watching" always shows
  /// the latest season/episode.
  String get storageKey => '${mediaType.name}_$tmdbId';

  PlaybackRequest toPlaybackRequest() {
    return PlaybackRequest(
      tmdbId: tmdbId,
      mediaType: mediaType,
      title: title,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
      posterPath: posterPath,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tmdbId': tmdbId,
      'mediaType': mediaType.name,
      'title': title,
      'providerId': providerId,
      'lastWatchedAt': lastWatchedAt.toIso8601String(),
      'seasonNumber': seasonNumber,
      'episodeNumber': episodeNumber,
      'posterPath': posterPath,
      'progressSeconds': progressSeconds,
    };
  }

  factory PlaybackHistoryEntry.fromMap(Map<dynamic, dynamic> map) {
    return PlaybackHistoryEntry(
      tmdbId: map['tmdbId'] as int,
      mediaType: PlaybackMediaType.values.byName(map['mediaType'] as String),
      title: map['title'] as String,
      providerId: map['providerId'] as String,
      lastWatchedAt: DateTime.parse(map['lastWatchedAt'] as String),
      seasonNumber: map['seasonNumber'] as int?,
      episodeNumber: map['episodeNumber'] as int?,
      posterPath: map['posterPath'] as String?,
      progressSeconds: (map['progressSeconds'] as num?)?.toDouble(),
    );
  }

  @override
  List<Object?> get props => [tmdbId, mediaType, title, providerId, lastWatchedAt, seasonNumber, episodeNumber, posterPath, progressSeconds];
}
