import 'package:hive_flutter/hive_flutter.dart';

import '../domain/entities/playback_history_entry.dart';
import '../domain/entities/playback_request.dart';

/// Persists "continue watching" entries: the last provider used and, for TV,
/// the last season/episode watched. Backed by its own Hive box so it never
/// depends on the movies/TV feature code.
class PlaybackHistoryService {
  static const String _boxName = 'playback_history';

  Box get _box => Hive.box(_boxName);

  List<PlaybackHistoryEntry> getHistory() {
    final entries = _box.values.whereType<Map>().map(PlaybackHistoryEntry.fromMap).toList();
    entries.sort((a, b) => b.lastWatchedAt.compareTo(a.lastWatchedAt));
    return entries;
  }

  /// Called when the player screen successfully starts playing [request]
  /// with [providerId]. Overwrites any prior entry for the same title so a
  /// show only ever has one "continue watching" row, pointing at the latest
  /// episode. Progress is intentionally not marked as completed here or
  /// anywhere else purely from the player being closed.
  Future<void> recordPlaybackStarted({
    required PlaybackRequest request,
    required String providerId,
  }) async {
    final entry = PlaybackHistoryEntry(
      tmdbId: request.tmdbId,
      mediaType: request.mediaType,
      title: request.title,
      providerId: providerId,
      lastWatchedAt: DateTime.now(),
      seasonNumber: request.seasonNumber,
      episodeNumber: request.episodeNumber,
      posterPath: request.posterPath,
    );
    await _box.put(entry.storageKey, entry.toMap());
  }

  Future<void> removeEntry(PlaybackHistoryEntry entry) async {
    await _box.delete(entry.storageKey);
  }

  Future<void> clear() async {
    await _box.clear();
  }
}
