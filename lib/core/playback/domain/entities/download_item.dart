import 'playback_media_type.dart';
import 'playback_request.dart';

/// The four states the preparation backend reports.
enum DownloadStatus { queued, downloading, ready, failed }

DownloadStatus downloadStatusFrom(String? s) {
  switch (s) {
    case 'downloading':
      return DownloadStatus.downloading;
    case 'ready':
      return DownloadStatus.ready;
    case 'failed':
      return DownloadStatus.failed;
    default:
      return DownloadStatus.queued;
  }
}

/// A title being prepared server-side (by ZipX / Real-Debrid), as the app
/// tracks it locally. This is NOT a device download - no media is stored on the
/// phone. Persisted as a plain map in the `downloads` Hive box (no adapter),
/// matching the app's other untyped boxes (playback_history, stream_availability).
class DownloadItem {
  const DownloadItem({
    required this.jobId,
    required this.tmdbId,
    required this.mediaType,
    required this.title,
    this.poster,
    this.season,
    this.episode,
    this.hash,
    this.fileIdx,
    this.status = DownloadStatus.queued,
    this.progress,
    this.speed,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Backend job id (the poll/cancel handle and the local key).
  final String jobId;
  final int tmdbId;
  final String mediaType; // 'movie' | 'tv'
  final String title;
  final String? poster; // TMDB poster path (display only)
  final int? season;
  final int? episode;

  /// Kept only so a failed item can be retried without re-querying; never a
  /// playback URL, which would go stale.
  final String? hash;
  final int? fileIdx;

  final DownloadStatus status;

  /// 0-100, only when the backend genuinely reported it (else null).
  final int? progress;

  /// Bytes/sec, only when the backend genuinely reported it (else null).
  final int? speed;

  final int createdAt;
  final int updatedAt;

  bool get isTv => mediaType == 'tv';
  bool get isActive => status == DownloadStatus.queued || status == DownloadStatus.downloading;

  /// "S02E07" for TV, null for movies.
  String? get episodeLabel => (isTv && season != null && episode != null)
      ? 'S${season.toString().padLeft(2, '0')}E${episode.toString().padLeft(2, '0')}'
      : null;

  DownloadItem copyWith({String? jobId}) => DownloadItem(
        jobId: jobId ?? this.jobId,
        tmdbId: tmdbId,
        mediaType: mediaType,
        title: title,
        poster: poster,
        season: season,
        episode: episode,
        hash: hash,
        fileIdx: fileIdx,
        status: status,
        progress: progress,
        speed: speed,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  /// A new item with a fresh backend status (progress/speed default to null so
  /// a value is never carried over / fabricated when the backend stops sending
  /// it). Bumps updatedAt.
  DownloadItem withStatus({required DownloadStatus status, int? progress, int? speed}) => DownloadItem(
        jobId: jobId,
        tmdbId: tmdbId,
        mediaType: mediaType,
        title: title,
        poster: poster,
        season: season,
        episode: episode,
        hash: hash,
        fileIdx: fileIdx,
        status: status,
        progress: progress,
        speed: speed,
        createdAt: createdAt,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

  PlaybackRequest toPlaybackRequest() => PlaybackRequest(
        tmdbId: tmdbId,
        mediaType: isTv ? PlaybackMediaType.tv : PlaybackMediaType.movie,
        title: title,
        seasonNumber: season,
        episodeNumber: episode,
        posterPath: poster,
      );

  Map<String, dynamic> toMap() => {
        'jobId': jobId,
        'tmdbId': tmdbId,
        'mediaType': mediaType,
        'title': title,
        'poster': poster,
        'season': season,
        'episode': episode,
        'hash': hash,
        'fileIdx': fileIdx,
        'status': status.name,
        'progress': progress,
        'speed': speed,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory DownloadItem.fromMap(Map map) => DownloadItem(
        jobId: map['jobId'].toString(),
        tmdbId: (map['tmdbId'] as num).toInt(),
        mediaType: map['mediaType']?.toString() ?? 'movie',
        title: map['title']?.toString() ?? '',
        poster: map['poster']?.toString(),
        season: (map['season'] as num?)?.toInt(),
        episode: (map['episode'] as num?)?.toInt(),
        hash: map['hash']?.toString(),
        fileIdx: (map['fileIdx'] as num?)?.toInt(),
        status: downloadStatusFrom(map['status']?.toString()),
        progress: (map['progress'] as num?)?.toInt(),
        speed: (map['speed'] as num?)?.toInt(),
        createdAt: (map['createdAt'] as num?)?.toInt() ?? 0,
        updatedAt: (map['updatedAt'] as num?)?.toInt() ?? 0,
      );
}
