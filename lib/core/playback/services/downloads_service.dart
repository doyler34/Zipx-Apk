import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../dependency_injection/di.dart';
import '../domain/entities/download_item.dart';
import 'stream_sources_service.dart';

/// Tracks server-side preparation jobs locally so they appear in Profile →
/// Downloads and survive restarts. Backed by the untyped `downloads` Hive box
/// (one map per job, keyed by jobId). Holds no Real-Debrid credentials and no
/// playback URLs - only the poll handle (jobId) and enough metadata to display
/// and, if needed, retry.
class DownloadsService {
  DownloadsService() : _box = Hive.box(_boxName);

  static const String _boxName = 'downloads';
  final Box _box;

  /// Rebuilds the Downloads UI whenever a job is added/updated/removed.
  ValueListenable<Box> get listenable => _box.listenable();

  /// All jobs, newest first.
  List<DownloadItem> all() {
    final items = _box.values
        .whereType<Map>()
        .map((m) => DownloadItem.fromMap(m))
        .toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  DownloadItem? get(String jobId) {
    final m = _box.get(jobId);
    return m is Map ? DownloadItem.fromMap(m) : null;
  }

  Future<void> upsert(DownloadItem item) => _box.put(item.jobId, item.toMap());

  Future<void> remove(String jobId) => _box.delete(jobId);

  /// An existing active/ready job for the same content, to avoid duplicate cards.
  DownloadItem? findForContent({
    required int tmdbId,
    required String mediaType,
    int? season,
    int? episode,
  }) {
    for (final item in all()) {
      if (item.tmdbId == tmdbId &&
          item.mediaType == mediaType &&
          item.season == season &&
          item.episode == episode &&
          item.status != DownloadStatus.failed) {
        return item;
      }
    }
    return null;
  }

  /// Refreshes one active job from the backend. Ready/failed jobs are never
  /// polled. A backend error keeps the last-known state (no fabrication).
  Future<DownloadItem?> refresh(String jobId) async {
    final item = get(jobId);
    if (item == null || !item.isActive) return item;
    final s = await sl<StreamSourcesService>().prepareStatus(jobId);
    if (s == null) return item;
    final updated = item.withStatus(
      status: downloadStatusFrom(s['status']?.toString()),
      progress: s['progress'] is num ? (s['progress'] as num).toInt() : null,
      speed: s['speed'] is num ? (s['speed'] as num).toInt() : null,
    );
    await upsert(updated);
    return updated;
  }

  /// Refreshes every active job (used on open / restart / each poll tick).
  Future<void> refreshActive() async {
    for (final item in all()) {
      if (item.isActive) {
        await refresh(item.jobId);
      }
    }
  }

  /// Re-submits a failed job using its stored release info. The backend only
  /// dedups active jobs, so a failed one gets a fresh job id; the local card is
  /// moved to it. Returns the refreshed item, or null if it couldn't resubmit.
  Future<DownloadItem?> retry(String jobId) async {
    final item = get(jobId);
    if (item == null || item.hash == null || item.hash!.isEmpty) return null;
    final newJobId = await sl<StreamSourcesService>().submitPreparation(
      tmdbId: item.tmdbId.toString(),
      mediaType: item.mediaType,
      title: item.title,
      season: item.season,
      episode: item.episode,
      hash: item.hash!,
      fileIdx: item.fileIdx,
    );
    if (newJobId == null) return null;
    if (newJobId != jobId) await remove(jobId);
    final fresh = item.copyWith(jobId: newJobId).withStatus(status: DownloadStatus.queued);
    await upsert(fresh);
    return fresh;
  }

  /// Cancels the backend job (best-effort) then removes the local card.
  Future<void> deleteJob(String jobId) async {
    await sl<StreamSourcesService>().cancelPreparation(jobId);
    await remove(jobId);
  }
}
