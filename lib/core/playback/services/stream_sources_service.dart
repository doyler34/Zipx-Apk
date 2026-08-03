import 'dart:convert';

import 'package:dio/dio.dart';

import '../domain/entities/playback_request.dart';
import '../domain/entities/stream_source.dart';

/// Talks to the self-hosted sources backend (TMDB-Embed-API on the VPS) and
/// returns a ranked list of directly-playable [StreamSource]s for a request.
///
/// The player uses these for native, ad-free playback; if this returns nothing
/// (or the backend is unreachable) the caller falls back to the WebView
/// providers.
class StreamSourcesService {
  StreamSourcesService(this._dio);

  final Dio _dio;

  /// Base URL of the sources backend. Plain HTTP for now - swap to the https
  /// domain once TLS is set up on the VPS. (The app allows cleartext to reach
  /// it; see AndroidManifest `usesCleartextTraffic`.)
  static const String backendBase = 'http://2.24.98.35:8787';

  Future<List<StreamSource>> fetch(PlaybackRequest request) async {
    final String url;
    Map<String, dynamic>? query;
    if (request.isTvEpisode) {
      url = '$backendBase/api/streams/series/${request.tmdbId}';
      query = {'season': request.seasonNumber, 'episode': request.episodeNumber};
    } else {
      url = '$backendBase/api/streams/movie/${request.tmdbId}';
    }

    final response = await _dio.get(
      url,
      queryParameters: query,
      options: Options(
        responseType: ResponseType.plain,
        // Scraping several providers live can take a few seconds.
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 15),
      ),
    );
    return _parse(response.data);
  }

  List<StreamSource> _parse(dynamic data) {
    dynamic decoded = data;
    if (data is String) {
      if (data.trim().isEmpty) return const [];
      decoded = jsonDecode(data);
    }
    if (decoded is! Map || decoded['streams'] is! List) return const [];

    final all = (decoded['streams'] as List)
        .whereType<Map>()
        .map((m) => StreamSource.fromJson(m.cast<String, dynamic>()))
        .where((s) => s.url.isNotEmpty && _isPlayable(s))
        .toList();

    // Rank: adaptive HLS first, then higher resolution first.
    all.sort((a, b) => _rank(a).compareTo(_rank(b)));
    return all;
  }

  /// Streaming-only: keep just directly-playable video URLs. Drops
  /// DahmerMovies (giant MKV files, Cloudflare rate-limited) and the NoTorrent
  /// entries that are intermediate API endpoints rather than a real stream.
  bool _isPlayable(StreamSource s) {
    if (s.provider.toLowerCase() == 'dahmermovies') return false;
    final u = s.url.toLowerCase();
    return u.contains('.m3u8') || u.contains('.mp4');
  }

  int _rank(StreamSource s) {
    var r = 0;
    if (s.isHls) r -= 1000; // adaptive HLS is the nicest to stream
    r -= _resolution(s); // higher resolution sorts earlier
    return r;
  }

  int _resolution(StreamSource s) {
    final hay = '${s.quality} ${s.title} ${s.url}'.toLowerCase();
    if (hay.contains('2160') || hay.contains('4k')) return 2160;
    if (hay.contains('1080')) return 1080;
    if (hay.contains('720')) return 720;
    if (hay.contains('480')) return 480;
    return 0;
  }
}
