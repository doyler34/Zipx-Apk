import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../dependency_injection/di.dart';
import '../domain/entities/playback_request.dart';
import '../domain/entities/stream_source.dart';
import 'stream_availability_service.dart';

/// Resolves a [PlaybackRequest] into a ranked list of directly-playable
/// [StreamSource]s for native, ad-free playback.
///
/// Backend: AIOStreams - one aggregated endpoint that wraps every source +
/// debrid and does the anime id mapping, dedup, cached-filtering and ranking
/// server-side, so the app only sends it an IMDb id. If it comes up empty (or
/// unreachable) the caller falls back to the WebView providers.
class StreamSourcesService {
  StreamSourcesService(this._dio);

  final Dio _dio;

  /// TMDB v3 key (already public in the app) - used to map a TMDB id to an
  /// IMDB id (which AIOStreams needs) and to read runtime / original language.
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
    // Resolve the IMDb id (AIOStreams needs it) and the original language
    // (drives anime detection + audio ranking) up front, in parallel.
    final meta = await Future.wait([
      _imdbId(request).catchError((_) => null),
      originalLanguage(request).catchError((_) => null),
    ]);
    final imdb = meta[0];
    final origLang = meta[1];
    final l = (origLang ?? '').toLowerCase();
    final isAnime = l == 'ja' || l == 'ko';

    // AIOStreams: one aggregated endpoint that wraps every source + debrid and
    // does the anime id mapping, dedup, cached-filtering and ranking
    // server-side. Just send it the IMDb id.
    if (_aioUrl.isNotEmpty && imdb != null && imdb.isNotEmpty) {
      try {
        final aio = await _fetchAio(request, imdb, origLang);
        if (aio.isNotEmpty) return (aio, isAnime);
      } catch (_) {
        // ignore - the caller shows a "no source" screen
      }
    }

    return (const <StreamSource>[], isAnime);
  }

  // ---------------------------------------------------------------------------
  // TMDB metadata
  // ---------------------------------------------------------------------------

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

  /// Queries the AIOStreams aggregated endpoint with the IMDb id and plays the
  /// URLs it returns as-is. AIOStreams has already aggregated, deduplicated,
  /// quality/resolution/language-filtered and ranked the results server-side.
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

  /// Parses an AIOStreams `/stream` response (`{streams:[...]}`) into playable
  /// [StreamSource]s. AIOStreams is the source of truth: it has already
  /// aggregated, deduplicated, quality/resolution/language-filtered and ranked
  /// the results, so the client does the minimum - preserve the metadata, order
  /// cached-first (uncached kept as a fallback), and drop only malformed or
  /// duplicate playback URLs. It never REJECTS a stream over language: it only
  /// DEMOTES releases whose filename looks foreign/hardsubbed (burned-in subs)
  /// so an English release plays first, keeping the foreign one as a last
  /// resort. Matched on `behaviorHints.filename`, not the subtitle-flag-heavy
  /// formatter description.
  List<StreamSource> _parseStremioStreams(dynamic decoded,
      {required String provider, String? originalLang}) {
    if (decoded is! Map || decoded['streams'] is! List) return const [];

    // (score, original index, source). The original index keeps the sort stable
    // so equal-scored streams keep AIOStreams' own order.
    final entries = <(int, int, StreamSource)>[];
    final seenUrls = <String>{};
    final l = (originalLang ?? '').toLowerCase();
    // "Home audio" title: original language is Japanese/Korean, so that audio is
    // allowed (anime + JA/KO live-action). Everything else is treated as a
    // normal English-required title.
    final homeAudioTitle = l == 'ja' || l == 'ko';
    var index = 0;

    for (final raw in decoded['streams'] as List) {
      if (raw is! Map) continue;
      final url = (raw['url'] ?? '').toString();
      if (!_isValidPlaybackUrl(url)) continue;
      if (!seenUrls.add(url)) continue; // drop identical duplicate playback URLs

      final name = (raw['name'] ?? '').toString();
      final description = (raw['description'] ?? raw['title'] ?? '').toString();
      final bh = raw['behaviorHints'];
      final filename = (bh is Map ? bh['filename'] : null)?.toString();
      final videoSize = (bh is Map && bh['videoSize'] is num) ? (bh['videoSize'] as num).toInt() : null;
      final bingeGroup = (bh is Map ? bh['bingeGroup'] : null)?.toString();

      final isCached = _isCached(raw, bh, name, description);
      final res = _resolution('$name $description ${filename ?? ''}');
      final releaseName = (filename != null && filename.isNotEmpty) ? filename : _releaseName(name, description);

      final source = StreamSource(
        title: _streamLabel(res, videoSize),
        url: url,
        quality: res > 0 ? '${res}p' : '',
        provider: provider,
        headers: const {},
        releaseName: releaseName,
        filename: filename,
        videoSize: videoSize,
        bingeGroup: bingeGroup,
        cached: isCached,
      );
      // Score on the structured release name (filename preferred) - never the
      // subtitle-flag-heavy formatter description.
      final score = _scoreStream(releaseName ?? '', res: res, cached: isCached, homeAudio: homeAudioTitle);
      entries.add((score, index++, source));
    }

    // Best score first; ties keep AIOStreams' original order (stable sort). No
    // stream is ever dropped - a low score just sinks it to the bottom, so the
    // user can still pick it from the source list, and it's there as a last
    // resort when nothing cleaner exists.
    entries.sort((a, b) {
      if (a.$1 != b.$1) return b.$1.compareTo(a.$1);
      return a.$2.compareTo(b.$2);
    });
    return entries.map((e) => e.$3).toList();
  }

  /// Ranks a stream so the app plays a clean, cached English release first
  /// instead of blindly playing `streams[0]`. Higher is better; nothing dropped.
  ///
  /// Weights are tiered so a higher priority always dominates every lower one,
  /// matching the requested order:
  ///   1. English audio        - foreign/dubbed audio is near-disqualifying
  ///                             (for a JA/KO-original title that audio is "home"
  ///                             and allowed - anime + JA/KO live-action)
  ///   2. No hardcoded subs     - HC / HCSUB / KORSUB / CHS / CHT / HARDCODED…
  ///   3. Cached on Real-Debrid - instant, reliable playback beats a marginal
  ///                             release-quality gain, so it outranks release type
  ///   4. Release type          - REMUX > BluRay > WEB-DL > WEBRip > HDRip >
  ///                             HDTV > DVD
  ///   5. Resolution            - 1080p > 720p
  ///   6. English subtitle hint - minor tiebreak
  /// (A soft SUBBED tag is a tiny extra nudge - soft subs are fine/disableable.)
  ///
  /// The cached bonus (5000) exceeds the whole release-type + resolution + hint
  /// range (max 3620), so cached always outranks uncached (e.g. a cached 1080p
  /// WEB-DL beats an uncached 1080p BluRay/REMUX); it stays below the hardcoded
  /// (10000) and foreign-audio (100000) penalties, so those tiers never cross.
  int _scoreStream(String releaseName, {required int res, required bool cached, required bool homeAudio}) {
    final n = releaseName.toLowerCase();
    var score = 0;

    // (1) Foreign / dubbed AUDIO - the main thing to avoid for normal titles.
    if (_hasForeignAudio(n, homeAudio)) score -= 100000;

    // (2) Hardcoded / baked-in subtitles (can't be turned off). Still English
    //     audio, so it ranks ABOVE foreign-audio releases in the fallback order.
    if (_hasHardcodedSubs(n)) score -= 10000;

    // Soft "subbed" tag - soft subs are fine (disableable), so only a gentle
    // tiebreak, and never for a home-audio (anime/JA/KO) title.
    if (!homeAudio && _hasTag(n, 'subbed')) score -= 200;

    // (3) Cached on Real-Debrid - instant, reliable playback outranks release
    //     type (a cached 1080p WEB-DL beats an uncached 1080p BluRay/REMUX).
    if (cached) score += 5000;

    // (4) Preferred release type.
    score += _releaseTypeBonus(n);

    // (5) Resolution.
    score += res == 1080 ? 100 : (res == 720 ? 50 : 0);

    // (6) English subtitle hint (minor).
    if (_hasTag(n, 'english') || _hasTag(n, 'eng')) score += 20;

    return score;
  }

  /// Foreign-language AUDIO indicators (whole-word). For a home-audio title
  /// (JA/KO original) Japanese/Korean are allowed and "dubbed" is not penalised
  /// (an English dub is welcome). Uses language *words*, not the "*SUB" tags, so
  /// a KORSUB / "KOR SUB" release (English audio, baked Korean subs) is caught by
  /// [_hasHardcodedSubs] instead and stays above truly foreign-audio releases.
  bool _hasForeignAudio(String n, bool homeAudio) {
    const words = [
      'italian', 'italiano', 'german', 'deutsch', 'french', 'francais',
      'français', 'truefrench', 'spanish', 'espanol', 'español', 'castellano',
      'latino', 'russian', 'russo', 'hindi', 'polish', 'portuguese',
      'portugues', 'português', 'dublado', 'turkish', 'arabic', 'chinese',
      'mandarin', 'cantonese', 'korean', 'japanese',
    ];
    for (final w in words) {
      if (homeAudio && (w == 'korean' || w == 'japanese')) continue;
      if (_hasTag(n, w)) return true;
    }
    // A foreign dub when English is expected (not for a home-audio title).
    if (!homeAudio && (_hasTag(n, 'dubbed') || _hasTag(n, 'dub'))) return true;
    return false;
  }

  /// Hardcoded / baked-in subtitle tags (the release burns subs into the video,
  /// so they can't be turned off).
  bool _hasHardcodedSubs(String n) {
    const tags = [
      'hardcoded', 'hardsub', 'hardsubbed', 'hardcore sub', 'korsub', 'kor sub',
      'kor-sub', 'hcsub', 'hc-sub', 'hc sub', 'hc eng sub', 'chs', 'cht',
    ];
    for (final t in tags) {
      if (_hasTag(n, t)) return true;
    }
    return _hasTag(n, 'hc'); // bare "HC" token
  }

  /// Release-type preference bonus (higher = better source).
  int _releaseTypeBonus(String n) {
    if (_hasTag(n, 'remux')) return 3500;
    if (n.contains('bluray') || n.contains('blu-ray') || _hasTag(n, 'bdrip') || _hasTag(n, 'brrip')) return 3000;
    if (n.contains('web-dl') || n.contains('webdl') || _hasTag(n, 'web')) return 2500;
    if (n.contains('webrip') || n.contains('web-rip')) return 2000;
    if (_hasTag(n, 'hdrip')) return 1500;
    if (_hasTag(n, 'hdtv')) return 1000;
    if (_hasTag(n, 'dvdrip') || n.contains('dvd')) return 500;
    return 0;
  }

  /// True if [tag] appears in [name] as a whole token (bounded by
  /// non-alphanumerics), so short tags like "hc" don't match inside words.
  bool _hasTag(String name, String tag) {
    final t = RegExp.escape(tag);
    return RegExp('(?<![a-z0-9])$t(?![a-z0-9])', caseSensitive: false).hasMatch(name);
  }

  /// A syntactically valid http(s) playback URL (basic malformed-URL guard).
  bool _isValidPlaybackUrl(String url) {
    if (url.isEmpty) return false;
    final u = Uri.tryParse(url);
    return u != null && (u.scheme == 'http' || u.scheme == 'https') && u.host.isNotEmpty;
  }

  /// Whether AIOStreams reports this stream as cached: an explicit
  /// `behaviorHints._isCached`, else the "⚡Ready (RD)" text marker AIOStreams
  /// puts in the description. Used only to order cached-first - uncached streams
  /// are still kept.
  bool _isCached(Map raw, dynamic bh, String name, String description) {
    if (bh is Map && bh.containsKey('_isCached')) return bh['_isCached'] == true;
    if (raw.containsKey('_isCached')) return raw['_isCached'] == true;
    final blob = '$name $description'.toLowerCase();
    return blob.contains('⚡') || blob.contains('cached') || blob.contains('instant');
  }

  /// The release/torrent title, used to match a synced subtitle. Prefer
  /// `behaviorHints.filename`; otherwise take the first real line of the
  /// description (skipping the emoji metadata lines), falling back to the name.
  String? _releaseName(String name, String description) {
    for (final line in description.split('\n')) {
      final t = line.trim();
      if (t.isEmpty) continue;
      if (t.startsWith('👤') || t.startsWith('💾') || t.startsWith('⚙️') || t.startsWith('🌐') || t.startsWith('🔗')) continue;
      return t;
    }
    final n = name.replaceAll('⚡', '').trim();
    return n.isEmpty ? null : n;
  }

  String _streamLabel(int res, int? videoSize) {
    final resStr = res > 0 ? '${res}p' : 'Auto';
    if (videoSize == null || videoSize <= 0) return 'Real-Debrid · $resStr';
    final gb = videoSize / (1024 * 1024 * 1024);
    return 'Real-Debrid · $resStr · ${gb.toStringAsFixed(1)} GB';
  }

  /// Reads a resolution height from AIOStreams' labels (numeric or UHD/QHD/FHD/HD).
  /// Display/ordering only - AIOStreams already restricts the actual set.
  int _resolution(String text) {
    final hay = text.toLowerCase();
    // Numeric labels first, then AIOStreams' letter labels (UHD/QHD/FHD/HD).
    if (hay.contains('2160') || hay.contains('4k') || hay.contains('uhd')) return 2160;
    if (hay.contains('1440') || hay.contains('qhd')) return 1440;
    if (hay.contains('1080') || hay.contains('fhd')) return 1080;
    if (hay.contains('720')) return 720;
    if (hay.contains('480')) return 480;
    // Bare "HD" (not U/F/Q-HD, handled above) ~ 720p.
    if (RegExp(r'(?<![a-z0-9])hd(?![a-z0-9])').hasMatch(hay)) return 720;
    return 0;
  }
}
