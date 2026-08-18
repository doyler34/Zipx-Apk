import '../domain/entities/playback_media_type.dart';
import '../domain/entities/playback_request.dart';
import 'stream_availability_service.dart';
import 'stream_sources_service.dart';

/// Proactively checks whether catalog titles have playable streams (via
/// AIOStreams) and records the verdicts in [StreamAvailabilityService], so
/// browse rows can drop the dead-ends.
///
/// It reuses the exact same lookup the player uses ([StreamSourcesService.
/// probeHasStreams]) - a non-empty result means AIOStreams returned at least
/// one playable stream. For TV it uses [StreamSourcesService.tvShowHasStreams],
/// which probes a recent aired episode then falls back to S1E1 (avoids false
/// negatives from using S1E1 alone as a proxy for the whole show).
/// Checks run concurrently with a small pool (not sequentially, not
/// all-at-once), only for titles that actually need a (re)check, and are
/// **fail-open**: a lookup error never records a negative. An empty result for
/// anime/JA-KO-ZH content also never records a negative (see [probe]) -
/// AIOStreams coming back empty for that content is often an uncached/ID-mapping
/// gap, not genuinely dead, mirroring the same guard [StreamSourcesService.fetch]
/// uses on the player path.
class AvailabilityProber {
  AvailabilityProber(this._sources, this._availability);

  final StreamSourcesService _sources;
  final StreamAvailabilityService _availability;

  Future<(bool hasStreams, bool isAnime)> _hasStreams(PlaybackMediaType mediaType, PlaybackRequest r) {
    if (mediaType == PlaybackMediaType.tv) {
      return _sources.tvShowHasStreams(tmdbId: r.tmdbId, title: r.title, posterPath: r.posterPath);
    }
    // strict: true - a genuine backend/network failure throws instead of
    // reading as "no streams", so the catch below fails open on it.
    return _sources.probeHasStreams(r, strict: true);
  }

  /// Probes [requests] (each a full [PlaybackRequest]) for [mediaType]. Skips
  /// titles whose cached verdict is still fresh. Returns once every needed check
  /// has completed and been recorded.
  Future<void> probe(
    PlaybackMediaType mediaType,
    List<PlaybackRequest> requests, {
    int concurrency = 6,
  }) async {
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
          final (ok, isAnime) = await _hasStreams(mediaType, r);
          // Never record a negative for anime/JA-KO-ZH content purely from an
          // empty result: that's often just an uncached-only title or an
          // ID-mapping gap, not genuinely dead (see fetch()'s matching
          // guard for the player path). Leaving it unrecorded keeps it
          // visible (isKnownUnavailable stays false) and re-probed later,
          // rather than getting permanently hidden from browsing.
          if (ok || !isAnime) {
            await _availability.record(mediaType: mediaType, tmdbId: r.tmdbId, hasStreams: ok);
          }
        } catch (_) {
          // Fail-open: never record a negative because a lookup errored.
        }
      }
    }

    final workers = concurrency.clamp(1, pending.length);
    await Future.wait(List.generate(workers, (_) => worker()));
  }

  /// Bounded page top-up: walks successive TMDB pages, probes each, and returns
  /// up to [target] titles that have a playable stream - stopping at [maxPages],
  /// when a page returns empty, or once the target is met. So a row of 20 that
  /// filters down to 8 fetches the next page(s) to refill it instead of looking
  /// broken. [firstPage] lets the caller pass an already-loaded page 1 to avoid
  /// re-fetching it.
  Future<List<T>> fillAvailable<T>({
    required PlaybackMediaType mediaType,
    required Future<List<T>> Function(int page) fetchPage,
    required int Function(T) idOf,
    required PlaybackRequest Function(T) toRequest,
    int target = 20,
    int maxPages = 3,
    int concurrency = 6,
    List<T>? firstPage,
  }) async {
    final kept = <T>[];
    final seen = <int>{};
    for (var page = 1; page <= maxPages && kept.length < target; page++) {
      List<T> items;
      try {
        items = (page == 1 && firstPage != null) ? firstPage : await fetchPage(page);
      } catch (_) {
        break; // page fetch failed - stop topping up, keep what we have
      }
      if (items.isEmpty) break;
      await probe(mediaType, items.map(toRequest).toList(), concurrency: concurrency);
      for (final it in items) {
        final id = idOf(it);
        if (!seen.add(id)) continue;
        if (!_availability.isKnownUnavailable(mediaType, id)) kept.add(it);
        if (kept.length >= target) break;
      }
    }
    return kept;
  }
}
