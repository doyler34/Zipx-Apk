import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// The anime ids an addon can be queried with, plus the episode number mapped
/// into that anime's own numbering.
class AnimeMapping {
  const AnimeMapping({this.kitsuId, this.malId, this.anilistId, required this.episode});

  final int? kitsuId;
  final int? malId;
  final int? anilistId;

  /// Episode number in the mapped anime's numbering (offset-adjusted).
  final int episode;

  bool get hasAnyId => kitsuId != null || malId != null || anilistId != null;
}

/// Maps a TMDB id (+ season/episode) to the anime databases' ids and episode
/// numbering, so anime addons (Torii, Kitsu, ...) - which key on Kitsu/MAL/
/// AniList ids and absolute episodes - can be queried for a title the app only
/// knows by TMDB id.
///
/// Uses the community "Fribb/anime-lists" dataset (merged over anidb id), which
/// carries `themoviedb_id`, `kitsu_id`, `mal_id`, `anilist_id`, `season` and
/// `episode_offset` per entry - so we can map straight from TMDB with no fragile
/// title matching. The dataset is fetched once and cached on-device (refreshed
/// every [_ttl]); a failure just yields no mapping, never an error.
class AnimeIdMapper {
  AnimeIdMapper(this._dio);

  final Dio _dio;

  static const String _url =
      'https://raw.githubusercontent.com/Fribb/anime-lists/master/anime-list-mini.json';
  static const String _boxName = 'anime_map';
  static const Duration _ttl = Duration(days: 14);

  List<dynamic>? _entriesCache;

  /// Resolves a TMDB TV title + season/episode to anime ids + episode. Returns
  /// null when the title isn't in the dataset (i.e. it isn't anime, or isn't
  /// mapped) - callers then just skip the anime addons.
  Future<AnimeMapping?> resolve(int tmdbId, int season, int episode) async {
    final List<dynamic>? entries;
    try {
      entries = await _entries();
    } catch (_) {
      return null;
    }
    if (entries == null) return null;

    final matches = <Map>[];
    for (final e in entries) {
      if (e is Map && _tmdbTv(e['themoviedb_id']) == tmdbId) matches.add(e);
    }
    if (matches.isEmpty) return null;

    // Prefer entries mapped to this TMDB season; among those, the one whose
    // episode-offset window contains the requested episode (handles a multi-cour
    // anime split into several anidb/kitsu entries under one TMDB season).
    final seasonMatches = matches.where((e) => (_tmdbSeason(e['season']) ?? season) == season).toList();
    final pool = seasonMatches.isNotEmpty ? seasonMatches : matches;
    pool.sort((a, b) => _offset(a['episode_offset']).compareTo(_offset(b['episode_offset'])));
    Map chosen = pool.first;
    for (final e in pool) {
      if (episode > _offset(e['episode_offset'])) chosen = e;
    }

    final mapped = episode - _offset(chosen['episode_offset']);
    return AnimeMapping(
      kitsuId: _asInt(chosen['kitsu_id']),
      malId: _asInt(chosen['mal_id']),
      anilistId: _asInt(chosen['anilist_id']),
      episode: mapped < 1 ? episode : mapped,
    );
  }

  // ---------------------------------------------------------------------------

  Future<List<dynamic>?> _entries() async {
    if (_entriesCache != null) return _entriesCache;
    final box = await _openBox();

    final ts = box.get('ts');
    final fresh = ts is int && DateTime.now().millisecondsSinceEpoch - ts < _ttl.inMilliseconds;
    String? raw = fresh ? box.get('json') as String? : null;

    if (raw == null) {
      try {
        final resp = await _dio.get(
          _url,
          options: Options(responseType: ResponseType.plain, receiveTimeout: const Duration(seconds: 30)),
        );
        raw = resp.data is String ? resp.data as String : jsonEncode(resp.data);
        await box.put('json', raw);
        await box.put('ts', DateTime.now().millisecondsSinceEpoch);
      } catch (_) {
        raw = box.get('json') as String?; // fall back to a stale copy if any
      }
    }
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      _entriesCache = decoded is List ? decoded : null;
    } catch (_) {
      _entriesCache = null;
    }
    return _entriesCache;
  }

  Future<Box> _openBox() async {
    // Opened lazily (not at startup) so the multi-MB dataset isn't loaded into
    // memory unless the user actually plays anime.
    return Hive.isBoxOpen(_boxName) ? Hive.box(_boxName) : await Hive.openBox(_boxName);
  }

  static int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  /// `themoviedb_id` is sometimes a flat id, sometimes `{tv, movie}`.
  static int? _tmdbTv(dynamic v) {
    if (v is Map) return _asInt(v['tv']) ?? _asInt(v['tv_id']);
    return _asInt(v);
  }

  /// `season` is sometimes an int, sometimes `{tvdb, tmdb}`.
  static int? _tmdbSeason(dynamic v) {
    if (v is Map) return _asInt(v['tmdb']);
    return _asInt(v);
  }

  /// `episode_offset` is sometimes an int, sometimes `{tvdb, tmdb}`; default 0.
  static int _offset(dynamic v) {
    if (v is Map) return _asInt(v['tmdb']) ?? 0;
    return _asInt(v) ?? 0;
  }
}
