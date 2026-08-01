import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../domain/entities/extracted_stream.dart';
import '../domain/entities/playback_request.dart';

/// Resolves a VidSrc embed into a directly-playable `.m3u8` stream, so the app
/// can play it in a native ExoPlayer (fully remote-controllable) instead of
/// loading VidSrc's embed in a WebView (un-controllable + captcha-gated).
///
/// It walks the same chain a browser would:
///   1. GET  /embed/movie/{id}         -> find the cloudnestra `/rcp/` iframe
///   2. GET  cloudnestra `/rcp/...`    -> find the `/prorcp/...` source
///   3. GET  cloudnestra `/prorcp/...` -> find the `.m3u8`
/// then returns the stream URL plus the Referer/Origin headers its CDN needs.
///
/// This is a straight port of the standalone `vidsrc_extract.py` harness; keep
/// the two in sync when VidSrc changes their player. Every step logs under the
/// `[VIDSRC]` tag so a breakage is visible in `adb logcat` and we can fix the
/// one step that moved.
///
/// Extracted URLs are signed/short-lived, so results are cached with a TTL and
/// transparently re-extracted when a cached link is stale or fails at play
/// time (see [extract]'s `forceRefresh`).
class VidSrcExtractor {
  VidSrcExtractor()
      : _dio = Dio(
          BaseOptions(
            // Its own client, not the shared TMDB Dio, so TMDB's base URL and
            // auth headers never leak into requests to VidSrc's mirrors.
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 20),
          ),
        );

  final Dio _dio;

  static const String _userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  /// Interchangeable VidSrc embed mirrors (kept in sync with VidSrcProvider).
  /// The first one that yields a stream wins.
  static const List<String> _embedHosts = [
    'vidsrc-embed.ru',
    'vidsrc.xyz',
    'vidsrc.me',
    'vidsrc.net',
    'vsrc.su',
  ];

  static const String _cacheBox = 'stream_cache';

  /// How long a cached stream URL is trusted before we re-extract. These links
  /// are tokenised; 2h is a conservative window well inside typical expiry.
  static const Duration _cacheTtl = Duration(hours: 2);

  /// In-memory mirror of the cache so repeat opens in one session never touch
  /// Hive or the network.
  final Map<String, ExtractedStream> _memoryCache = {};

  /// Resolves a playable stream for [request].
  ///
  /// Returns a cached result when one is present and fresh (and
  /// [forceRefresh] is false); otherwise extracts live, caches, and returns.
  /// Throws [VidSrcExtractionException] if every mirror fails.
  Future<ExtractedStream> extract(PlaybackRequest request, {bool forceRefresh = false}) async {
    final key = _cacheKey(request);

    if (!forceRefresh) {
      final cached = _readCache(key);
      if (cached != null) {
        _log('cache hit for $key (host=${cached.sourceHost})');
        return cached;
      }
    }

    Object? lastError;
    for (final host in _embedHosts) {
      try {
        final stream = await _extractFromHost(host, request);
        _writeCache(key, stream);
        _log('extracted OK via $host: ${stream.url}');
        return stream;
      } catch (e) {
        _log('miss on $host: $e');
        lastError = e;
      }
    }
    throw VidSrcExtractionException('All VidSrc mirrors failed. Last error: $lastError');
  }

  Future<ExtractedStream> _extractFromHost(String host, PlaybackRequest request) async {
    final embedUrl = 'https://$host${_embedPath(request)}';

    // Step 1: embed page -> cloudnestra /rcp/ iframe.
    final embedHtml = await _fetch(embedUrl, referer: 'https://$host/');
    final rcpUrl = _absolutize(_firstMatch(embedHtml, _rcpPatterns), embedUrl);
    if (rcpUrl == null) throw const VidSrcExtractionException('step1: no /rcp/ iframe in embed page');
    _log('step1 rcp: $rcpUrl');

    // Step 2: /rcp/ -> /prorcp/ source (or an inline m3u8 on some variants).
    final rcpHtml = await _fetch(rcpUrl, referer: embedUrl);
    final prorcpRaw = _firstMatch(rcpHtml, _prorcpPatterns);
    if (prorcpRaw == null) throw const VidSrcExtractionException('step2: no /prorcp/ or m3u8 in rcp page');

    final origin = Uri.parse(rcpUrl);
    final originBase = '${origin.scheme}://${origin.host}';

    String m3u8;
    if (prorcpRaw.contains('.m3u8')) {
      _log('step2 inline m3u8: $prorcpRaw');
      m3u8 = _absolutize(prorcpRaw, rcpUrl)!;
    } else {
      final prorcpUrl = _absolutize(prorcpRaw, rcpUrl)!;
      _log('step2 prorcp: $prorcpUrl');
      // Step 3: /prorcp/ -> m3u8.
      final prorcpHtml = await _fetch(prorcpUrl, referer: rcpUrl);
      final raw = _firstMatch(prorcpHtml, _m3u8Patterns);
      if (raw == null) throw const VidSrcExtractionException('step3: no .m3u8 in prorcp page');
      _log('step3 m3u8: $raw');
      m3u8 = _absolutize(raw, prorcpUrl)!;
    }

    return ExtractedStream(
      url: m3u8,
      headers: {
        'Referer': '$originBase/',
        'Origin': originBase,
        'User-Agent': _userAgent,
      },
      extractedAt: DateTime.now(),
      sourceHost: host,
    );
  }

  String _embedPath(PlaybackRequest request) {
    if (request.isTvEpisode) {
      return '/embed/tv/${request.tmdbId}/${request.seasonNumber}-${request.episodeNumber}';
    }
    return '/embed/movie/${request.tmdbId}';
  }

  Future<String> _fetch(String url, {String? referer}) async {
    final response = await _dio.get<String>(
      url,
      options: Options(
        responseType: ResponseType.plain,
        followRedirects: true,
        maxRedirects: 5,
        // Treat any <500 as a body we can inspect rather than a thrown error,
        // so a challenge/HTML error page reaches our pattern matching.
        validateStatus: (status) => status != null && status < 500,
        headers: {
          'User-Agent': _userAgent,
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
          if (referer != null) 'Referer': referer,
        },
      ),
    );
    final body = response.data ?? '';
    _log('GET $url -> ${response.statusCode} (${body.length} bytes)');
    final low = body.toLowerCase();
    for (final marker in ['just a moment', 'attention required', 'not a robot', 'captcha']) {
      if (low.contains(marker)) {
        _log('WARN response looks like an anti-bot page (matched "$marker")');
        break;
      }
    }
    return body;
  }

  // --- pattern tables (mirror of the Python harness) -----------------------

  static final List<RegExp> _rcpPatterns = [
    RegExp(r'''id=["']player_iframe["'][^>]*\ssrc=["']([^"']+)["']'''),
    RegExp(r'''<iframe[^>]*\ssrc=["'](//[^"']*cloudnestra[^"']+)["']'''),
    RegExp(r'''src=["']((?:https?:)?//[^"']*cloudnestra\.com/rcp/[^"']+)["']'''),
    RegExp(r'''["'](/rcp/[A-Za-z0-9+/=_-]+)["']'''),
  ];

  static final List<RegExp> _prorcpPatterns = [
    RegExp(r'''src\s*:\s*['"](/prorcp/[^'"]+)['"]'''),
    RegExp(r'''['"](/prorcp/[A-Za-z0-9+/=_-]+)['"]'''),
    RegExp(r'''file\s*:\s*['"]([^'"]+\.m3u8[^'"]*)['"]'''),
  ];

  static final List<RegExp> _m3u8Patterns = [
    RegExp(r'''file\s*:\s*['"]([^'"]+\.m3u8[^'"]*)['"]'''),
    RegExp(r'''['"](https?://[^'"]+\.m3u8[^'"]*)['"]'''),
    RegExp(r'''(https?://[^\s'"]+\.m3u8[^\s'"]*)'''),
  ];

  String? _firstMatch(String html, List<RegExp> patterns) {
    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      if (match != null) return match.group(1);
    }
    return null;
  }

  String? _absolutize(String? raw, String base) {
    if (raw == null) return null;
    if (raw.startsWith('//')) return 'https:$raw';
    if (raw.startsWith('http')) return raw;
    return Uri.parse(base).resolve(raw).toString();
  }

  // --- cache ----------------------------------------------------------------

  String _cacheKey(PlaybackRequest request) {
    final type = request.isTvEpisode ? 'tv' : 'movie';
    return '$type:${request.tmdbId}:${request.seasonNumber ?? ''}:${request.episodeNumber ?? ''}';
  }

  ExtractedStream? _readCache(String key) {
    final mem = _memoryCache[key];
    if (mem != null && _isFresh(mem)) return mem;

    final box = _boxOrNull();
    if (box != null) {
      final raw = box.get(key);
      if (raw is Map) {
        try {
          final stream = ExtractedStream.fromMap(raw);
          if (_isFresh(stream)) {
            _memoryCache[key] = stream;
            return stream;
          }
        } catch (_) {
          // Corrupt/legacy entry - ignore and re-extract.
        }
      }
    }
    return null;
  }

  void _writeCache(String key, ExtractedStream stream) {
    _memoryCache[key] = stream;
    _boxOrNull()?.put(key, stream.toMap());
  }

  bool _isFresh(ExtractedStream stream) => DateTime.now().difference(stream.extractedAt) < _cacheTtl;

  Box? _boxOrNull() {
    if (!Hive.isBoxOpen(_cacheBox)) return null;
    return Hive.box(_cacheBox);
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('[VIDSRC] $message');
  }
}

class VidSrcExtractionException implements Exception {
  const VidSrcExtractionException(this.message);
  final String message;
  @override
  String toString() => 'VidSrcExtractionException: $message';
}
