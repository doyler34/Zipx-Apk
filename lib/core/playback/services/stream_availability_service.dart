import 'package:hive_flutter/hive_flutter.dart';

import '../domain/entities/playback_media_type.dart';

/// Tracks which TMDB titles actually have playable streams (via AIOStreams), so
/// the browse rows only show titles you can watch.
///
/// Two things write here:
///  - the player (reactive): when a title is opened, its lookup verdict is
///    recorded;
///  - the background prober (proactive): it probes catalog titles and records
///    verdicts up-front so dead-ends never even show.
///
/// Cache model (deliberately "realistic"):
///  - **Available is sticky** - a title with a working link keeps showing; we do
///    not drop it after a day. It's only re-verified occasionally
///    ([_availableReverify]) to catch content that later disappears.
///  - **Unavailable is re-probed**, not permanent: a *recently* unavailable
///    title (younger than [_newThreshold], i.e. likely a new release) is
///    rechecked quickly ([_newBadRetry]) so it appears the moment a stream shows
///    up; a long-unavailable title is rechecked rarely ([_oldBadRetry]).
class StreamAvailabilityService {
  static const String boxName = 'stream_availability';

  /// Available titles keep showing; only re-verified this often (catch removals).
  static const Duration _availableReverify = Duration(days: 7);

  /// A title unavailable for less than this is treated as "new" (recheck fast).
  static const Duration _newThreshold = Duration(days: 3);

  /// Recheck cadence for new vs. long-standing unavailable titles.
  static const Duration _newBadRetry = Duration(hours: 4); // within the 3-6h target
  static const Duration _oldBadRetry = Duration(hours: 48); // within the 24-72h target

  /// Anime/JA-KO-ZH-language content gets this many empty probes (each paced
  /// by the normal cooldown below, so this plays out over ~16h+) before a
  /// negative is actually recorded - an empty AIOStreams result for that
  /// content is often just an uncached/ID-mapping gap rather than genuinely
  /// dead. Once it does cross the threshold it's treated exactly like any
  /// other title from then on (same cooldown/re-probe cycle) - it never gets
  /// buried forever, but it also isn't shown forever if it's just dead.
  static const int _animeMissThreshold = 4;

  Box get _box => Hive.box(boxName);

  String _key(PlaybackMediaType mediaType, int tmdbId) => '${mediaType.name}_$tmdbId';

  int get _now => DateTime.now().millisecondsSinceEpoch;

  /// Recheck cooldown for an unavailable entry, based on how long it's been bad.
  Duration _badCooldown(int firstBad) =>
      _now - firstBad < _newThreshold.inMilliseconds ? _newBadRetry : _oldBadRetry;

  /// True only when this title is known to have no streams AND that verdict is
  /// still inside its recheck cooldown. Unknown / available / cooled-down all
  /// return false (shown). Used by the catalog parsers + row re-filtering.
  bool isKnownUnavailable(PlaybackMediaType mediaType, int tmdbId) {
    final v = _box.get(_key(mediaType, tmdbId));
    if (v is! Map || v['available'] != false) return false;
    final ts = v['ts'];
    if (ts is! int) return false;
    final firstBad = v['firstBad'] is int ? v['firstBad'] as int : ts;
    // Hide while inside the cooldown; once it lapses, show again (a fresh probe
    // will re-decide) so a title is never permanently buried.
    return _now - ts < _badCooldown(firstBad).inMilliseconds;
  }

  /// Whether the background prober should (re)check this title now: unknown,
  /// available-but-due-for-reverify, or unavailable-and-past-its-cooldown.
  bool needsProbe(PlaybackMediaType mediaType, int tmdbId) {
    final v = _box.get(_key(mediaType, tmdbId));
    if (v is! Map) return true; // never checked
    final ts = v['ts'] is int ? v['ts'] as int : 0;
    if (v['available'] == true) {
      return _now - ts > _availableReverify.inMilliseconds;
    }
    final firstBad = v['firstBad'] is int ? v['firstBad'] as int : ts;
    return _now - ts >= _badCooldown(firstBad).inMilliseconds;
  }

  /// Records the outcome of a stream lookup. A positive verdict is sticky and
  /// overrides any earlier negative; a negative never overwrites a positive, and
  /// preserves the original "first went bad" time so new-vs-old stays accurate.
  ///
  /// [isAnime] (anime/JA-KO-ZH-language content) gets [_animeMissThreshold]
  /// empty misses before the negative actually sticks - see that constant.
  /// Below the threshold nothing is hidden (`isKnownUnavailable` stays
  /// false); the miss is still timestamped so the next probe is paced by the
  /// normal cooldown instead of hammering it every load.
  Future<void> record({
    required PlaybackMediaType mediaType,
    required int tmdbId,
    required bool hasStreams,
    bool isAnime = false,
  }) async {
    final key = _key(mediaType, tmdbId);
    if (hasStreams) {
      await _box.put(key, {'available': true, 'ts': _now});
      return;
    }
    final existing = _box.get(key);
    if (existing is Map && existing['available'] == true) return; // keep positive
    final firstBad = existing is Map && existing['firstBad'] is int ? existing['firstBad'] as int : _now;

    if (isAnime) {
      final missCount = (existing is Map && existing['missCount'] is int ? existing['missCount'] as int : 0) + 1;
      if (missCount < _animeMissThreshold) {
        await _box.put(key, {'missCount': missCount, 'ts': _now, 'firstBad': firstBad});
        return;
      }
    }

    await _box.put(key, {'available': false, 'ts': _now, 'firstBad': firstBad});
  }
}
