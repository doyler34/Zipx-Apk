import 'dart:convert';

import 'package:dio/dio.dart';

import '../domain/entities/playback_request.dart';
import '../domain/entities/stream_source.dart';

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
    final sources = <StreamSource>[];

    // 1) Comet / Real-Debrid first (best: direct, ad-free, new releases).
    try {
      final imdb = await _imdbId(request);
      if (imdb != null && imdb.isNotEmpty) {
        sources.addAll(await _fetchComet(request, imdb));
      }
    } catch (_) {
      // ignore - fall through to the free scrapers
    }

    // 2) TMDB-Embed-API (free scrapers).
    try {
      sources.addAll(await _fetchEmbed(request));
    } catch (_) {
      // ignore - caller falls back to WebView if the whole list is empty
    }

    return sources;
  }

  // ---------------------------------------------------------------------------
  // Comet + Real-Debrid
  // ---------------------------------------------------------------------------

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

  Future<List<StreamSource>> _fetchComet(PlaybackRequest request, String imdb) async {
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
    if (decoded is! Map || decoded['streams'] is! List) return const [];

    final parsed = <StreamSource>[];
    for (final raw in decoded['streams'] as List) {
      if (raw is! Map) continue;
      final url = (raw['url'] ?? '').toString();
      if (url.isEmpty) continue;
      final name = (raw['name'] ?? '').toString();
      final description = (raw['description'] ?? '').toString();
      if (_isBad('$url $name $description')) continue;
      // A real WEB-DL/BluRay release always carries a resolution tag. Cams and
      // junk that the ranker couldn't classify come through as "unknown" (the
      // "0p" we saw on the Spider-Man cam), so require a proper resolution.
      final res = _resolution('$name $description');
      if (res < 720) continue;
      parsed.add(StreamSource(
        title: _cometLabel(name, description),
        url: url,
        quality: '${res}p',
        provider: 'Real-Debrid',
        headers: const {},
      ));
    }

    // Prefer 1080p for auto-play (streams smoothly, decodes on any phone);
    // 4K remuxes are huge and often won't decode on mobile - keep them, just
    // lower. Smaller files first within a resolution.
    parsed.sort((a, b) {
      final ra = _autoPref(_resolution(a.quality));
      final rb = _autoPref(_resolution(b.quality));
      if (ra != rb) return ra.compareTo(rb);
      return _sizeGb(a.title).compareTo(_sizeGb(b.title));
    });
    // Cap to keep the picker manageable.
    return parsed.take(20).toList();
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
