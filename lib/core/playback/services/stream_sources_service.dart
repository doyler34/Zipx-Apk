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

  Future<List<StreamSource>> fetch(PlaybackRequest request) async {
    final sources = await _fetchSources(request);
    // Learn availability: a title that returns nothing gets hidden from future
    // browsing; one that returns sources is remembered as playable.
    unawaited(sl<StreamAvailabilityService>().record(
      mediaType: request.mediaType,
      tmdbId: request.tmdbId,
      hasStreams: sources.isNotEmpty,
    ));
    return sources;
  }

  Future<List<StreamSource>> _fetchSources(PlaybackRequest request) async {
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

    Future<List<StreamSource>> comet() async {
      if (imdb == null || imdb.isEmpty) return const [];
      try {
        return await _fetchComet(request, imdb, origLang);
      } catch (_) {
        return const [];
      }
    }

    // Anime: query Comet AND the configured anime addons together, then merge -
    // more sources for anime, older shows and niche content. Each provider is
    // isolated, so a failing/absent anime addon never affects Comet.
    if (isAnime) {
      final results = await Future.wait([comet(), _fetchAnimeAddons(request, imdb, origLang)]);
      final merged = _dedup([...results[0], ...results[1]]);
      if (merged.isNotEmpty) return merged;
      // Nothing from either - fall back to the free scrapers (often subbed).
      try {
        return await _fetchEmbed(request);
      } catch (_) {
        return const [];
      }
    }

    // Non-anime: keep the existing fast path - if Real-Debrid already has it,
    // return immediately without waiting on the slower free-scraper backend.
    final cometOnly = await comet();
    if (cometOnly.isNotEmpty) return cometOnly;
    try {
      return await _fetchEmbed(request);
    } catch (_) {
      return const [];
    }
  }

  /// Queries every configured anime addon in parallel, each fully isolated so
  /// one being slow/down/absent can't affect Comet or the others. Returns the
  /// combined list (deduped + capped by the caller).
  ///
  /// Anime addons key on Kitsu/MAL/AniList ids + absolute episodes, so the TMDB
  /// id is mapped first; the IMDb id is kept as a last-resort fallback.
  Future<List<StreamSource>> _fetchAnimeAddons(
      PlaybackRequest request, String? imdb, String? originalLang) async {
    final addons = sl<AnimeAddonsService>().addons();
    if (addons.isEmpty) return const [];

    final ids = await _animeStreamIds(request, imdb);
    if (ids.isEmpty) return const [];

    final results = await Future.wait(addons.map((addon) async {
      // Try each id (kitsu -> anilist -> mal -> imdb) until one returns sources.
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
  List<StreamSource> _parseStremioStreams(dynamic decoded, {required String provider, String? originalLang}) {
    if (decoded is! Map || decoded['streams'] is! List) return const [];

    // (cached, resolution, sizeGB, source) so we can rank before dropping the
    // extra fields.
    final entries = <(bool, int, double, StreamSource)>[];
    for (final raw in decoded['streams'] as List) {
      if (raw is! Map) continue;
      final url = (raw['url'] ?? '').toString();
      if (url.isEmpty) continue;
      final name = (raw['name'] ?? '').toString();
      final description = (raw['description'] ?? raw['title'] ?? '').toString();
      if (_isBad('$url $name $description')) continue;
      // A real WEB-DL/BluRay release always carries a resolution tag. Cams and
      // junk that the ranker couldn't classify come through as "unknown", so
      // require a proper resolution.
      final res = _resolution('$name $description');
      if (res < 720) continue;
      // Cached results are instant-play; an uncached one makes RD download the
      // torrent first, which just hangs the player. Detect the common "cached"
      // markers across Comet/Torii/other addons.
      final blob = '$name $description'.toLowerCase();
      final cached = name.contains('⚡') ||
          blob.contains('cached') ||
          blob.contains('instant') ||
          blob.contains('[rd+]') ||
          blob.contains('rd+');
      entries.add((cached, res, _sizeGb(description), StreamSource(
        title: _cometLabel(name, description),
        url: url,
        quality: '${res}p',
        provider: provider,
        headers: const {},
        releaseName: _releaseName(name, description),
      )));
    }

    // For a non-English original (anime/foreign): hide foreign-dub sources
    // entirely - keep only the original/dual audio and any English dub.
    final foreignOriginal = (originalLang ?? '').isNotEmpty && originalLang!.toLowerCase() != 'en';
    if (foreignOriginal) {
      entries.retainWhere((e) => _audioRank(e.$4.releaseName ?? '', originalLang) != 2);
    }

    // Only offer instant-play (cached) sources when any exist: an uncached RD
    // stream isn't ready, so it just hangs the player for the full timeout and
    // then falls through. If nothing is cached, keep what we have as a last try.
    if (entries.any((e) => e.$1)) {
      entries.retainWhere((e) => e.$1);
    }

    // Rank: cached first (instant play); then prefer original/dual audio; then
    // 1080p (streams smoothly on any phone), then smaller files first.
    entries.sort((a, b) {
      if (a.$1 != b.$1) return a.$1 ? -1 : 1;
      final aa = _audioRank(a.$4.releaseName ?? '', originalLang);
      final ab = _audioRank(b.$4.releaseName ?? '', originalLang);
      if (aa != ab) return aa.compareTo(ab);
      final ra = _autoPref(a.$2);
      final rb = _autoPref(b.$2);
      if (ra != rb) return ra.compareTo(rb);
      return a.$3.compareTo(b.$3);
    });
    return entries.map((e) => e.$4).toList();
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
