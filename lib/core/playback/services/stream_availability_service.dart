import 'package:hive_flutter/hive_flutter.dart';

import '../domain/entities/playback_media_type.dart';

/// Remembers which titles turned out to have **no** playable streams, so the
/// browse lists can hide those dead-ends next time.
///
/// Real-Debrid removed its bulk "instant availability" API, so there's no cheap
/// way to know up-front whether a title is streamable. Instead we learn it: the
/// player already scrapes a title when it's opened, and [record] stores the
/// verdict. A "no streams" result hides the title from future browsing; a "has
/// streams" result is sticky so a title that plays is never wrongly hidden
/// (e.g. one TV episode with no source doesn't bury a show that streams fine).
///
/// "No stream" verdicts expire after [_negativeTtl] so a title gets another
/// chance once torrents appear for it later.
class StreamAvailabilityService {
  static const String boxName = 'stream_availability';

  static const Duration _negativeTtl = Duration(days: 21);

  Box get _box => Hive.box(boxName);

  String _key(PlaybackMediaType mediaType, int tmdbId) => '${mediaType.name}_$tmdbId';

  /// True only when this title is known to have no streams and that verdict is
  /// still fresh. Unknown / known-available / stale all return false (shown).
  bool isKnownUnavailable(PlaybackMediaType mediaType, int tmdbId) {
    final v = _box.get(_key(mediaType, tmdbId));
    if (v is! Map || v['available'] != false) return false;
    final ts = v['ts'];
    if (ts is int && DateTime.now().millisecondsSinceEpoch - ts > _negativeTtl.inMilliseconds) {
      return false; // stale - allow a recheck
    }
    return true;
  }

  /// Records the outcome of a stream lookup. A positive verdict is sticky and
  /// overrides any earlier negative; a negative never overwrites a positive.
  Future<void> record({
    required PlaybackMediaType mediaType,
    required int tmdbId,
    required bool hasStreams,
  }) async {
    final key = _key(mediaType, tmdbId);
    if (hasStreams) {
      await _box.put(key, {'available': true, 'ts': DateTime.now().millisecondsSinceEpoch});
      return;
    }
    final existing = _box.get(key);
    if (existing is Map && existing['available'] == true) return; // keep positive
    await _box.put(key, {'available': false, 'ts': DateTime.now().millisecondsSinceEpoch});
  }
}
