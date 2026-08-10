import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../dependency_injection/di.dart';
import '../domain/entities/playback_request.dart';
import '../domain/entities/stream_source.dart';
import 'anime_addons_service.dart';
import 'anime_id_mapper.dart';
import 'stream_availability_service.dart';

/// Resolves a [PlaybackRequest] into a ranked list of directly-playable
/// [StreamSource]s for native, ad-free playback.
///
/// Two backends, best first:
///   1. Comet + Real-Debrid - direct RD streams (new releases, high quality).
///   2. TMDB-Embed-API - free scrapers (VixSrc/Vidlink/NoTorrent/...).
/// If both come up empty (or unreachable) the caller falls back to the WebView
/// providers.
class StreamSourcesService {
  StreamSourcesService(this._dio);

  final Dio _dio;

  // --- backends (plain HTTP for now; move to https domain once TLS is set up)
  static const String _embedBase = 'http://2.24.98.35:8787';
  static const String _cometBase = 'http://2.24.98.35:8000';

  /// Comet install config (from its /configure page). Contains the debrid
  /// stream proxy password, NOT the Real-Debrid token (that stays on the VPS).
  /// Regenerate + replace this if the Comet config/proxy-password changes.
  static const String _cometConfig =
      'eyJtYXhSZXN1bHRzUGVyUmVzb2x1dGlvbiI6MCwibWF4U2l6ZSI6MCwiY2FjaGVkT25seSI6ZmFsc2UsInNvcnRDYWNoZWRVbmNhY2hlZFRvZ2V0aGVyIjpmYWxzZSwicmVtb3ZlVHJhc2giOnRydWUsInJlc3VsdEZvcm1hdCI6WyJhbGwiXSwiZGVicmlkU2VydmljZXMiOltdLCJlbmFibGVUb3JyZW50IjpmYWxzZSwiZGVkdXBsaWNhdGVTdHJlYW1zIjpmYWxzZSwic2NyYXBlRGVicmlkQWNjb3VudFRvcnJlbnRzIjpmYWxzZSwiZGVicmlkU3RyZWFtUHJveHlQYXNzd29yZCI6IkdhcmVANDc2MCIsImxhbmd1YWdlcyI6eyJyZXF1aXJlZCI6W10sImFsbG93ZWQiOltdLCJleGNsdWRlIjpbXSwicHJlZmVycmVkIjpbXX0sInJlc29sdXRpb25zIjp7fSwib3B0aW9ucyI6eyJyZW1vdmVfcmFua3NfdW5kZXIiOi0xMDAwMDAwMDAwMCwiYWxsb3dfZW5nbGlzaF9pbl9sYW5ndWFnZXMiOmZhbHNlLCJyZW1vdmVfdW5rbm93bl9sYW5ndWFnZXMiOmZhbHNlfX0=';

  /// TMDB v3 key (already public in the app) - used only to map a TMDB id to an
  /// IMDB id, which Comet needs.
  static const String _tmdbKey = 'd168cb7e62f9692894c20fdb039ae126';

  /// AIOStreams aggregated addon base URL (everything before `/stream/...`),
  /// injected via `--dart-define=AIOSTREAMS_ADDON_URL`. A single endpoint that
  /// wraps every source + debrid and does the anime id mapping, dedup, cached
  /// filtering and ranking server-side - so the app just asks it for an IMDb id.
  static const String _aioUrl = String.fromEnvironment('AIOSTREAMS_ADDON_URL');

  Future<List<StreamSource>> fetch(PlaybackRequest request) async {
    final (sources, isAnime) = await _fetchSources(request);
    // Learn availability so dead titles get hidden from browsing - but NEVER
    // hide anime this way: "no cached source" doesn't mean dead, it just means
    // it may need preparing (uncached), so anime must stay visible. Only record
    // a negative for non-anime; a positive (found sources) is always fine.
    if (!isAnime || sources.isNotEmpty) {
      unawaited(sl<StreamAvailabilityService>().record(
        mediaType: request.mediaType,
        tmdbId: request.tmdbId,
        hasStreams: sources.isNotEmpty,
      ));
    }
    return sources;
  }

  Future<(List<StreamSource>, bool)> _fetchSources(PlaybackRequest request) async {
    // Resolve the IMDb id (Comet + IMDb-scheme addons need it) and the original
    // language (drives anime detection + audio ranking) up front, in parallel.
    final meta = await Future.wait([
      _imdbId(request).catchError((_) => null),
      originalLanguage(request).catchError((_) => null),
    ]);
    final imdb = meta[0];
    final origLang = meta[1];
    final l = (origLang ?? '').toLowerCase();
    final isAnime = l == 'ja' || l == 'ko';

    // 0) AIOStreams first: one aggregated endpoint that wraps every source +
    //    debrid and does the anime id mapping, dedup, cached-filtering and
    //    ranking server-side. Just send it the IMDb id. When it returns cached
    //    sources we're done - no per-provider juggling needed.
    if (_aioUrl.isNotEmpty && imdb != null && imdb.isNotEmpty) {
      try {
        final aio = await _fetchAio(request, imdb, origLang);
        if (aio.isNotEmpty) return (aio, isAnime);
      } catch (_) {
        // ignore - fall back to the legacy providers below
      }
    }

    // 1) Comet (legacy fallback if AIOStreams is unset / down / empty). A cached
    //    hit is the fast path, so play it immediately.
    if (imdb != null && imdb.isNotEmpty) {
      try {
        final comet = await _fetchComet(request, imdb, origLang);
        if (comet.isNotEmpty) return (comet, isAnime);
      } catch (_) {
        // ignore - fall through to the fan-out
      }
    }

    // 2) Comet missed (niche / older / anime it can't number). Only NOW fan out
    //    to the extra addons and the free scrapers - all in parallel, each fully
    //    isolated - and merge whatever comes back. Adding more providers costs
    //    nothing on the fast path; it only ever runs when Comet came up empty.
    final results = await Future.wait([
      _fetchExtraAddons(request, imdb, origLang, isAnime),
      _fetchEmbed(request).catchError((_) => const <StreamSource>[]),
    ]);
    return (_dedup([...results[0], ...results[1]]), isAnime);
  }

  /// Queries every configured extra addon (Torii, MediaFusion, ...) in parallel,
  /// each fully isolated so one being slow/down/absent can't affect the others.
  /// Anime-only addons are skipped for non-anime titles. Anime uses the mapped
  /// Kitsu/MAL/AniList ids (absolute episode); everything else uses the IMDb id.
  Future<List<StreamSource>> _fetchExtraAddons(
      PlaybackRequest request, String? imdb, String? originalLang, bool isAnime) async {
    var addons = sl<AnimeAddonsService>().addons();
    if (!isAnime) addons = addons.where((a) => !a.animeOnly).toList();
    if (addons.isEmpty) return const [];

    final ids = isAnime ? await _animeStreamIds(request, imdb) : _imdbIds(request, imdb);
    if (ids.isEmpty) return const [];

    final results = await Future.wait(addons.map((addon) async {
      // Try each id in turn until one returns sources for this addon.
      for (final id in ids) {
        try {
          final r = await _fetchAddonById(addon, request.isTvEpisode, id, originalLang);
          if (r.isNotEmpty) return r;
        } catch (_) {
          // isolated - move on to the next id / addon
        }
      }
      return const <StreamSource>[];
    }));
    return results.expand((e) => e).toList();
  }

  /// The plain IMDb content id for non-anime addons (`tt…:s:e` for series).
  List<String> _imdbIds(PlaybackRequest request, String? imdb) {
    if (imdb == null || imdb.isEmpty) return const [];
    return [request.isTvEpisode ? '$imdb:${request.seasonNumber}:${request.episodeNumber}' : imdb];
  }

  /// Builds the ordered list of content ids to try against anime addons:
  /// `kitsu:/anilist:/mal:` (from the TMDB->anime mapping, with absolute-episode
  /// numbering) first, then the plain IMDb id as a fallback.
  Future<List<String>> _animeStreamIds(PlaybackRequest request, String? imdb) async {
    final ids = <String>[];
    final season = request.seasonNumber ?? 1;
    final episode = request.episodeNumber ?? 1;

    AnimeMapping? m;
    try {
      m = await sl<AnimeIdMapper>().resolve(request.tmdbId, season, episode);
    } catch (_) {
      m = null;
    }
    if (m != null && m.hasAnyId) {
      final ep = request.isTvEpisode ? ':${m.episode}' : '';
      if (m.kitsuId != null) ids.add('kitsu:${m.kitsuId}$ep');
      if (m.anilistId != null) ids.add('anilist:${m.anilistId}$ep');
      if (m.malId != null) ids.add('mal:${m.malId}$ep');
    }
    if (imdb != null && imdb.isNotEmpty) {
      ids.add(request.isTvEpisode ? '$imdb:$season:$episode' : imdb);
    }
    return ids;
  }

  /// Fetches one addon for a specific content id via the standard Stremio
  /// `/stream/{type}/{id}.json` protocol (same shape Comet returns).
  Future<List<StreamSource>> _fetchAddonById(
      StremioAddon addon, bool isSeries, String id, String? originalLang) async {
    final type = isSeries ? 'series' : 'movie';
    final response = await _dio.get(
      '${addon.baseUrl}/stream/$type/$id.json',
      options: Options(responseType: ResponseType.plain, receiveTimeout: const Duration(seconds: 20)),
    );
    final decoded = response.data is String ? jsonDecode(response.data as String) : response.data;
    return _parseStremioStreams(decoded, provider: addon.name, originalLang: originalLang).take(15).toList();
  }

  /// Merges provider results, dropping duplicate stream URLs while preserving
  /// order (Comet first), and caps the list so the picker stays manageable.
  List<StreamSource> _dedup(List<StreamSource> sources) {
    final seen = <String>{};
    final out = <StreamSource>[];
    for (final s in sources) {
      if (s.url.isNotEmpty && seen.add(s.url)) out.add(s);
    }
    return out.take(30).toList();
  }

  /// On-device diagnostic for the anime "no source" screen: reveals whether RD
  /// is configured, which anime ids the mapper resolved, and what an uncached
  /// lookup returned - so a failure can be pinpointed without guessing.
  Future<String> animeDiag(PlaybackRequest request) async {
    final b = StringBuffer();
    b.writeln('RD token: ${sl<RealDebridService>().isConfigured ? "set" : "MISSING"}');
    b.writeln('addons: ${sl<AnimeAddonsService>().addons().map((a) => a.name).join(", ")}');
    final imdb = await _imdbId(request).catchError((_) => null);
    b.writeln('tmdb=${request.tmdbId} imdb=${imdb ?? "-"} S${request.seasonNumber}E${request.episodeNumber}');
    final m = await sl<AnimeIdMapper>()
        .resolve(request.tmdbId, request.seasonNumber ?? 1, request.episodeNumber ?? 1)
        .catchError((_) => null);
    b.writeln(m == null
        ? 'mapping: NONE (tmdb id not in dataset)'
        : 'mapping: kitsu=${m.kitsuId} anilist=${m.anilistId} mal=${m.malId} ep=${m.episode}');
    final ids = await _animeStreamIds(request, imdb);
    b.writeln('ids tried: ${ids.isEmpty ? "-" : ids.join("  ")}');
    final unc = await bestUncachedAnime(request);
    b.write('uncached found: ${unc == null ? "NONE" : "${unc.provider}  ih=${unc.infohash ?? "-"}"}');
    return b.toString();
  }

  // ---------------------------------------------------------------------------
  // Comet + Real-Debrid
  // ---------------------------------------------------------------------------

  /// The title's real runtime in minutes from TMDB, used to reject sample /
  /// trailer / wrong-content files (anything far shorter than the real movie).
  /// Null if unknown.
  Future<int?> expectedRuntimeMinutes(PlaybackRequest request) async {
    try {
      final String url;
      if (request.isTvEpisode) {
        url = 'https://api.themoviedb.org/3/tv/${request.tmdbId}/season/${request.seasonNumber}/episode/${request.episodeNumber}';
      } else {
        url = 'https://api.themoviedb.org/3/movie/${request.tmdbId}';
      }
      final r = await _dio.get(
        url,
        queryParameters: {'api_key': _tmdbKey},
        options: Options(receiveTimeout: const Duration(seconds: 10)),
      );
      final data = r.data is String ? jsonDecode(r.data as String) : r.data;
      if (data is Map) {
        final rt = data['runtime'];
        if (rt is num && rt > 0) return rt.toInt();
      }
    } catch (_) {
      // unknown - the player falls back to a fixed minimum
    }
    return null;
  }

  /// The title's original language (TMDB ISO code, e.g. "zh"), used to auto
  /// -select the original audio track over a dub. Null if unknown.
  Future<String?> originalLanguage(PlaybackRequest request) async {
    try {
      final type = request.isTvEpisode ? 'tv' : 'movie';
      final r = await _dio.get(
        'https://api.themoviedb.org/3/$type/${request.tmdbId}',
        queryParameters: {'api_key': _tmdbKey},
        options: Options(receiveTimeout: const Duration(seconds: 10)),
      );
      final data = r.data is String ? jsonDecode(r.data as String) : r.data;
      if (data is Map) {
        final lang = data['original_language'];
        if (lang is String && lang.isNotEmpty) return lang;
      }
    } catch (_) {
      // unknown - leave audio track on the player's default
    }
    return null;
  }

  Future<String?> _imdbId(PlaybackRequest request) async {
    final type = request.isTvEpisode ? 'tv' : 'movie';
    final response = await _dio.get(
      'https://api.themoviedb.org/3/$type/${request.tmdbId}/external_ids',
      queryParameters: {'api_key': _tmdbKey},
      options: Options(receiveTimeout: const Duration(seconds: 10)),
    );
    final data = response.data is String ? jsonDecode(response.data as String) : response.data;
    if (data is Map) return data['imdb_id'] as String?;
    return null;
  }

  /// Queries the AIOStreams aggregated endpoint with the IMDb id. AIOStreams
  /// resolves anime ids, dedupes, filters to cached and ranks server-side, so
  /// the response is parsed the same way as any Stremio stream reply.
  Future<List<StreamSource>> _fetchAio(PlaybackRequest request, String imdb, String? originalLang) async {
    final base = _aioUrl.replaceAll(RegExp(r'/+$'), '');
    final type = request.isTvEpisode ? 'series' : 'movie';
    final id = request.isTvEpisode ? '$imdb:${request.seasonNumber}:${request.episodeNumber}' : imdb;
    final response = await _dio.get(
      '$base/stream/$type/$id.json',
      options: Options(responseType: ResponseType.plain, receiveTimeout: const Duration(seconds: 45)),
    );
    final decoded = response.data is String ? jsonDecode(response.data as String) : response.data;
    return _parseStremioStreams(decoded, provider: 'AIOStreams', originalLang: originalLang).take(30).toList();
  }

  Future<List<StreamSource>> _fetchComet(PlaybackRequest request, String imdb, String? originalLang) async {
    final path = request.isTvEpisode
        ? '$_cometBase/$_cometConfig/stream/series/$imdb:${request.seasonNumber}:${request.episodeNumber}.json'
        : '$_cometBase/$_cometConfig/stream/movie/$imdb.json';

    final response = await _dio.get(
      path,
      options: Options(
        responseType: ResponseType.plain,
        // Scraping + RD cache-check can take a little while.
        receiveTimeout: const Duration(seconds: 45),
      ),
    );

    final decoded = response.data is String ? jsonDecode(response.data as String) : response.data;
    return _parseStremioStreams(decoded, provider: 'Real-Debrid', originalLang: originalLang).take(20).toList();
  }

  /// Parses a Stremio `/stream` response (`{streams:[...]}`) into ranked,
  /// playable [StreamSource]s. Shared by Comet and the extra anime addons since
  /// they all speak the same protocol. Drops junk/cams (< 720p), and for a
  /// non-English original hides foreign-dub releases; ranks cached-first, then
  /// original/dual audio, then 1080p, then smaller files.
  List<StreamSource> _parseStremioStreams(dynamic decoded,
      {required String provider, String? originalLang, bool uncachedOnly = false}) {
    if (decoded is! Map || decoded['streams'] is! List) return const [];

    // (cached, resolution, sizeGB, isBatch, seeders, source) for ranking.
    final entries = <(bool, int, double, bool, int, StreamSource)>[];
    for (final raw in decoded['streams'] as List) {
      if (raw is! Map) continue;
      final url = (raw['url'] ?? '').toString();
      if (url.isEmpty) continue;
      final name = (raw['name'] ?? '').toString();
      final description = (raw['description'] ?? raw['title'] ?? '').toString();
      if (_isBad('$url $name $description')) continue;
      final res = _resolution('$name $description');
      if (res < 720) continue;
      // Torii marks cache state with an explicit `_isCached` flag (in
      // behaviorHints); Comet/Torrentio use a ⚡/"cached" name marker.
      final bh = raw['behaviorHints'];
      final bool cached;
      if (bh is Map && bh.containsKey('_isCached')) {
        cached = bh['_isCached'] == true;
      } else if (raw.containsKey('_isCached')) {
        cached = raw['_isCached'] == true;
      } else {
        final blob = '$name $description'.toLowerCase();
        cached = name.contains('⚡') || blob.contains('cached') || blob.contains('instant');
      }
      final isBatch = bh is Map && bh['_isBatch'] == true;
      final seeders = (bh is Map && bh['_seeders'] is num) ? (bh['_seeders'] as num).toInt() : 0;
      entries.add((cached, res, _sizeGb(description), isBatch, seeders, StreamSource(
        title: _cometLabel(name, description),
        url: url,
        quality: '${res}p',
        provider: provider,
        headers: const {},
        releaseName: _releaseName(name, description),
        infohash: _infohash(raw, bh),
        cached: cached,
      )));
    }

    // For a non-English original (anime/foreign): hide foreign-dub sources
    // entirely - keep only the original/dual audio and any English dub.
    final foreignOriginal = (originalLang ?? '').isNotEmpty && originalLang!.toLowerCase() != 'en';
    if (foreignOriginal) {
      entries.retainWhere((e) => _audioRank(e.$6.releaseName ?? '', originalLang) != 2);
    }

    if (uncachedOnly) {
      // Uncached candidates we could actually prepare (need an infohash). Rank
      // by fastest-to-cache: single episodes before batches, then most seeders,
      // then smallest file.
      entries.retainWhere((e) => !e.$1 && (e.$6.infohash?.isNotEmpty ?? false));
      entries.sort((a, b) {
        if (a.$4 != b.$4) return a.$4 ? 1 : -1;
        if (a.$5 != b.$5) return b.$5.compareTo(a.$5);
        return a.$3.compareTo(b.$3);
      });
      return entries.map((e) => e.$6).toList();
    }

    // Play path: never offer uncached sources - an uncached RD stream isn't
    // ready and just hangs the player, so drop them (caller falls back fast).
    entries.retainWhere((e) => e.$1);
    // Rank: cached first; then original/dual audio; then 1080p; then smaller.
    entries.sort((a, b) {
      if (a.$1 != b.$1) return a.$1 ? -1 : 1;
      final aa = _audioRank(a.$6.releaseName ?? '', originalLang);
      final ab = _audioRank(b.$6.releaseName ?? '', originalLang);
      if (aa != ab) return aa.compareTo(ab);
      final ra = _autoPref(a.$2);
      final rb = _autoPref(b.$2);
      if (ra != rb) return ra.compareTo(rb);
      return a.$3.compareTo(b.$3);
    });
    return entries.map((e) => e.$6).toList();
  }

  /// Extracts the 40-hex torrent infohash from a Stremio stream: the standard
  /// `infoHash` field, or Torii's `behaviorHints.bingeGroup` ("..._<40hex>").
  String? _infohash(Map raw, dynamic bh) {
    final direct = raw['infoHash'];
    if (direct is String && RegExp(r'^[a-fA-F0-9]{40}$').hasMatch(direct)) {
      return direct.toLowerCase();
    }
    if (bh is Map) {
      final m = RegExp(r'[a-fA-F0-9]{40}').firstMatch((bh['bingeGroup'] ?? '').toString());
      if (m != null) return m.group(0)!.toLowerCase();
    }
    return null;
  }

  /// The best uncached anime source to "prepare" (cache on Real-Debrid), or
  /// null. Prefers single-episode torrents so caching is fast. Only used by the
  /// opt-in "prepare episode" flow when there's no cached source.
  Future<StreamSource?> bestUncachedAnime(PlaybackRequest request) async {
    try {
      final meta = await Future.wait([
        _imdbId(request).catchError((_) => null),
        originalLanguage(request).catchError((_) => null),
      ]);
      final ids = await _animeStreamIds(request, meta[0]);
      if (ids.isEmpty) return null;
      for (final addon in sl<AnimeAddonsService>().addons()) {
        for (final id in ids) {
          try {
            final type = request.isTvEpisode ? 'series' : 'movie';
            final resp = await _dio.get(
              '${addon.baseUrl}/stream/$type/$id.json',
              options: Options(responseType: ResponseType.plain, receiveTimeout: const Duration(seconds: 20)),
            );
            final decoded = resp.data is String ? jsonDecode(resp.data as String) : resp.data;
            final unc = _parseStremioStreams(decoded, provider: addon.name, originalLang: meta[1], uncachedOnly: true);
            if (unc.isNotEmpty) return unc.first;
          } catch (_) {
            // isolated - try the next id/addon
          }
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Audio-language preference for a release name. Lower is better. For an
  /// English (or unknown) original there's no preference, so everything is 1
  /// and the audio step has no effect. For a non-English original (anime is
  /// "ja"): original/dual audio = 0 (best), an obvious foreign dub = 2 (worst),
  /// everything else = 1.
  int _audioRank(String releaseName, String? originalLang) {
    final lang = (originalLang ?? '').toLowerCase();
    if (lang.isEmpty || lang == 'en') return 1;
    final n = releaseName.toLowerCase();
    final origTags = _origLangTags(lang);
    if (_hasTag(n, 'dual') || _hasTag(n, 'multi') || origTags.any((t) => _hasTag(n, t))) return 0;
    // A dub in a language that's neither the original nor English. Matched on
    // whole tokens only (see _hasTag) so short tags like "ita"/"vf" can be
    // listed without false-matching words like "capital". NOT generic
    // "dubbed"/"dub" so an English dub isn't mistaken for a foreign one.
    // The original language is matched first (origTags -> 0), so listing both
    // 'japanese' and 'korean' here only excludes them when they're NOT the
    // original (e.g. a Japanese dub of a Korean title).
    const foreignDub = [
      'spanish', 'latino', 'latin', 'castellano', 'espanol', 'español', 'esp',
      'spa', 'italian', 'italiano', 'ita', 'german', 'deutsch', 'ger', 'deu',
      'french', 'truefrench', 'francais', 'français', 'vf', 'vff', 'vfq', 'fre',
      'fra', 'hindi', 'hin', 'dublado', 'russian', 'russo', 'rus', 'polish',
      'pl', 'portuguese', 'portugues', 'português', 'por', 'pt', 'korean',
      'kor', 'japanese', 'jpn', 'jap', 'thai', 'tamil', 'tam', 'telugu', 'tel',
      'arabic', 'ara', 'turkish', 'turk',
    ];
    if (foreignDub.any((t) => _hasTag(n, t))) return 2;
    return 1;
  }

  /// True if [tag] appears in [name] as a whole token (bounded by non-alphanumerics
  /// or string ends), so short tags like "ita" don't match inside "capital".
  bool _hasTag(String name, String tag) {
    final t = RegExp.escape(tag);
    return RegExp('(?<![a-z0-9])$t(?![a-z0-9])', caseSensitive: false).hasMatch(name);
  }

  /// Release-name tags that indicate a title's original-language audio.
  List<String> _origLangTags(String lang) {
    switch (lang) {
      case 'ja':
        return const ['jpn', 'japanese', 'jap'];
      case 'ko':
        return const ['kor', 'korean'];
      case 'zh':
        return const ['chi', 'zho', 'chinese', 'mandarin', 'cantonese'];
      default:
        return [lang];
    }
  }

  /// The raw release/torrent title, used to match a synced subtitle. Comet
  /// (Torrentio-style) puts the actual filename on the first line of the
  /// description; fall back to the name.
  String? _releaseName(String name, String description) {
    for (final line in description.split('\n')) {
      final t = line.trim();
      // Skip the metadata lines (seeders / size / indexer), which start with an
      // emoji/symbol rather than the release title.
      if (t.isEmpty) continue;
      if (t.startsWith('👤') || t.startsWith('💾') || t.startsWith('⚙️') || t.startsWith('🌐') || t.startsWith('🔗')) continue;
      return t;
    }
    final n = name.replaceAll('⚡', '').trim();
    return n.isEmpty ? null : n;
  }

  String _cometLabel(String name, String description) {
    final res = _resolution('$name $description');
    final size = _sizeGb(description);
    final sizeStr = size > 0 ? ' · ${size.toStringAsFixed(1)} GB' : '';
    return 'Real-Debrid · ${res}p$sizeStr';
  }

  /// Lower = tried first for auto-play.
  int _autoPref(int res) {
    switch (res) {
      case 1080:
        return 0;
      case 720:
        return 1;
      case 2160:
        return 2;
      case 1440:
        return 3;
      default:
        return 4;
    }
  }

  double _sizeGb(String text) {
    final m = RegExp(r'([\d.]+)\s*GB', caseSensitive: false).firstMatch(text);
    if (m != null) return double.tryParse(m.group(1)!) ?? 0;
    return 0;
  }

  // ---------------------------------------------------------------------------
  // TMDB-Embed-API (free scrapers)
  // ---------------------------------------------------------------------------

  Future<List<StreamSource>> _fetchEmbed(PlaybackRequest request) async {
    final String url;
    Map<String, dynamic>? query;
    if (request.isTvEpisode) {
      url = '$_embedBase/api/streams/series/${request.tmdbId}';
      query = {'season': request.seasonNumber, 'episode': request.episodeNumber};
    } else {
      url = '$_embedBase/api/streams/movie/${request.tmdbId}';
    }

    final response = await _dio.get(
      url,
      queryParameters: query,
      options: Options(
        responseType: ResponseType.plain,
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 15),
      ),
    );

    dynamic decoded = response.data;
    if (decoded is String) {
      if (decoded.trim().isEmpty) return const [];
      decoded = jsonDecode(decoded);
    }
    if (decoded is! Map || decoded['streams'] is! List) return const [];

    final all = (decoded['streams'] as List)
        .whereType<Map>()
        .map((m) => StreamSource.fromJson(m.cast<String, dynamic>()))
        .where((s) => s.url.isNotEmpty && _isPlayableEmbed(s))
        .toList();

    all.sort((a, b) => _embedRank(a).compareTo(_embedRank(b)));
    return all;
  }

  /// Streaming-only: keep just directly-playable video URLs. Drops
  /// DahmerMovies (giant MKV, rate-limited) and NoTorrent API (non-video) URLs,
  /// and anything that looks like a trailer.
  bool _isPlayableEmbed(StreamSource s) {
    if (s.provider.toLowerCase() == 'dahmermovies') return false;
    if (_isBad('${s.url} ${s.title}')) return false;
    final u = s.url.toLowerCase();
    return u.contains('.m3u8') || u.contains('.mp4');
  }

  /// Trailers usually come from YouTube (or are literally labelled "trailer").
  /// The real safety net is the short-duration skip in the player; this just
  /// drops the obvious ones up front.
  static bool _looksLikeTrailer(String text) {
    final t = text.toLowerCase();
    return t.contains('youtube.com') ||
        t.contains('youtu.be') ||
        t.contains('googlevideo.com') ||
        t.contains('/trailer') ||
        t.contains('trailer.');
  }

  /// Cam / telesync / telecine theatrical rips - low quality, never wanted.
  /// Word-boundary matched so real tags like "DTS" (audio) aren't caught.
  static final RegExp _camPattern = RegExp(
    r'\b(cam|camrip|hdcam|hqcam|ts|hdts|tsrip|telesync|tc|hdtc|telecine|scr|dvdscr|screener|predvd|workprint)\b',
    caseSensitive: false,
  );

  static bool _looksLikeCam(String text) => _camPattern.hasMatch(text);

  static bool _isBad(String text) => _looksLikeTrailer(text) || _looksLikeCam(text);

  int _embedRank(StreamSource s) {
    var r = 0;
    if (s.isHls) r -= 1000;
    r -= _resolution('${s.quality} ${s.title} ${s.url}');
    return r;
  }

  int _resolution(String text) {
    final hay = text.toLowerCase();
    if (hay.contains('2160') || hay.contains('4k')) return 2160;
    if (hay.contains('1440')) return 1440;
    if (hay.contains('1080')) return 1080;
    if (hay.contains('720')) return 720;
    if (hay.contains('480')) return 480;
    return 0;
  }
}
