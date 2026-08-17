import '../domain/entities/playback_media_type.dart';
import '../domain/entities/playback_request.dart';
import 'stream_availability_service.dart';
import 'stream_sources_service.dart';

/// Proactively checks whether catalog titles have playable streams (via
/// AIOStreams) and records the verdicts in [StreamAvailabilityService], so
/// browse rows can drop the dead-ends.
///
/// It reuses the exact same lookup the player uses ([StreamSourcesService.
/// fetchQuiet]) - a non-empty result means AIOStreams returned at least one
/// playable stream. Checks run concurrently with a small pool (not sequentially,
/// not all-at-once), only for titles that actually need a (re)check, and are
/// **fail-open**: a lookup error never records a negative, so a hiccup can never
/// hide a title that might be fine.
class AvailabilityProber {
  AvailabilityProber(this._sources, this._availability);

  final StreamSourcesService _sources;
  final StreamAvailabilityService _availability;

  /// Probes [requests] (each already a full [PlaybackRequest]) for [mediaType].
  /// Skips titles whose cached verdict is still fresh. Returns once every needed
  /// check has completed and been recorded.
  Future<void> probe(
    PlaybackMediaType mediaType,
    List<PlaybackRequest> requests, {
    int concurrency = 6,
  }) async {
    // De-dupe by tmdbId and keep only the ones due for a (re)check.
    final seen = <int>{};
    final pending = <PlaybackRequest>[];
    for (final r in requests) {
      if (!seen.add(r.tmdbId)) continue;
      if (_availability.needsProbe(mediaType, r.tmdbId)) pending.add(r);
    }
    if (pending.isEmpty) return;

    var next = 0;
    Future<void> worker() async {
      while (next < pending.length) {
        final r = pending[next++]; // sync read+increment: no race on the event loop
        try {
          final sources = await _sources.fetchQuiet(r);
          await _availability.record(
            mediaType: mediaType,
            tmdbId: r.tmdbId,
            hasStreams: sources.isNotEmpty,
          );
        } catch (_) {
          // Fail-open: never record a negative because a lookup errored.
        }
      }
    }

    final workers = concurrency.clamp(1, pending.length);
    await Future.wait(List.generate(workers, (_) => worker()));
  }
}
