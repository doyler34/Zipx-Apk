import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';

import '../domain/entities/playback_request.dart';

/// How a subtitle is delivered - determines how the player loads it.
enum SubtitleKind {
  /// A direct subtitle-file URL (SRT/VTT) - loaded straight into mpv.
  direct,

  /// A SubDL zip archive URL - must be downloaded + unzipped on-device first.
  subdlZip,
}

/// One external (English) subtitle option for a title.
class ExternalSubtitle {
  const ExternalSubtitle({
    required this.url,
    required this.label,
    required this.kind,
    this.episode,
  });

  /// Direct subtitle URL ([SubtitleKind.direct]) or zip URL ([SubtitleKind.subdlZip]).
  final String url;

  /// Human-readable label for the picker, e.g. "English · SubDL".
  final String label;

  final SubtitleKind kind;

  /// For TV zips that may bundle a whole season: the episode to pick out.
  final int? episode;
}

/// Fetches **English** external subtitles for a title so text subs are
/// available even when the streamed file (a Real-Debrid torrent) has none
/// embedded.
///
/// Two free sources, both matched by TMDB id (+ season/episode for TV):
///   1. SubDL (api.subdl.com) - broad coverage incl. Chinese dramas that
///      OpenSubtitles misses. Ships subs as zips, unpacked on selection.
///      Needs a free API key (subdl.com account -> API); disabled until set.
///   2. Wyzie Subs (sub.wyzie.ru) - keyless OpenSubtitles proxy, direct URLs.
class SubtitleService {
  SubtitleService(this._dio);

  final Dio _dio;

  static const String _wyzieBase = 'https://sub.wyzie.ru/search';

  static const String _subdlSearch = 'https://api.subdl.com/api/v1/subtitles';
  static const String _subdlDownloadBase = 'https://dl.subdl.com';

  /// Free SubDL API key (subdl.com -> account -> API). Left blank ships with
  /// only the keyless OpenSubtitles source; set it to enable SubDL's much
  /// better Chinese-drama coverage.
  static const String _subdlApiKey = 'subdl_NzYdZIVX1icsPtWzn5qtoaNo4D4ZJ4bfIeRC-bdpjTU';

  /// Fetches English subtitles from both sources, SubDL first (better
  /// C-drama coverage), then OpenSubtitles.
  Future<List<ExternalSubtitle>> fetch(PlaybackRequest request) async {
    final results = await Future.wait([
      _fetchSubdl(request),
      _fetchWyzie(request),
    ]);
    return [...results[0], ...results[1]];
  }

  // ---------------------------------------------------------------------------
  // SubDL (zip archives, best C-drama coverage)
  // ---------------------------------------------------------------------------

  Future<List<ExternalSubtitle>> _fetchSubdl(PlaybackRequest request) async {
    if (_subdlApiKey.isEmpty) return const [];
    try {
      final params = <String, dynamic>{
        'api_key': _subdlApiKey,
        'tmdb_id': request.tmdbId,
        'type': request.isTvEpisode ? 'tv' : 'movie',
        'languages': 'EN',
        'subs_per_page': 10,
      };
      if (request.isTvEpisode) {
        params['season_number'] = request.seasonNumber;
        params['episode_number'] = request.episodeNumber;
      }

      final response = await _dio.get(
        _subdlSearch,
        queryParameters: params,
        options: Options(responseType: ResponseType.plain, receiveTimeout: const Duration(seconds: 15)),
      );

      dynamic decoded = response.data;
      if (decoded is String) {
        if (decoded.trim().isEmpty) return const [];
        decoded = jsonDecode(decoded);
      }
      if (decoded is! Map || decoded['subtitles'] is! List) return const [];

      final out = <ExternalSubtitle>[];
      var n = 0;
      for (final raw in decoded['subtitles'] as List) {
        if (raw is! Map) continue;
        final rel = (raw['url'] ?? '').toString();
        if (rel.isEmpty) continue;
        final url = rel.startsWith('http') ? rel : '$_subdlDownloadBase$rel';
        n++;
        final release = (raw['release_name'] ?? raw['name'] ?? '').toString();
        final hint = release.isNotEmpty ? ' · ${_short(release)}' : '';
        out.add(ExternalSubtitle(
          url: url,
          label: 'English · SubDL${n > 1 ? ' ($n)' : ''}$hint',
          kind: SubtitleKind.subdlZip,
          episode: request.episodeNumber,
        ));
        if (out.length >= 10) break;
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  /// Downloads a SubDL zip and returns the best-matching SRT's text content,
  /// ready for `SubtitleTrack.data`. Null if it can't be resolved.
  Future<String?> resolveSubdlZip(String zipUrl, {int? episode}) async {
    try {
      final response = await _dio.get<List<int>>(
        zipUrl,
        options: Options(responseType: ResponseType.bytes, receiveTimeout: const Duration(seconds: 20)),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) return null;

      final archive = ZipDecoder().decodeBytes(bytes);
      final subFiles = archive.files
          .where((f) => f.isFile && _isSubtitleFile(f.name))
          .toList();
      if (subFiles.isEmpty) return null;

      // A season pack bundles every episode; pick the file whose name carries
      // this episode number (e.g. E07 / "07"). Otherwise take the first.
      ArchiveFile chosen = subFiles.first;
      if (episode != null && subFiles.length > 1) {
        final match = subFiles.firstWhere(
          (f) => _nameMatchesEpisode(f.name, episode),
          orElse: () => subFiles.first,
        );
        chosen = match;
      }

      // English subs are UTF-8 / Windows-1252; allowMalformed keeps stray bytes
      // from throwing rather than failing the whole track.
      return utf8.decode(chosen.content as List<int>, allowMalformed: true);
    } catch (_) {
      return null;
    }
  }

  bool _isSubtitleFile(String name) {
    final n = name.toLowerCase();
    return n.endsWith('.srt') || n.endsWith('.vtt') || n.endsWith('.ass') || n.endsWith('.ssa');
  }

  bool _nameMatchesEpisode(String name, int episode) {
    final ep = episode.toString().padLeft(2, '0');
    final n = name.toLowerCase();
    return n.contains('e$ep') || n.contains('ep$ep') || RegExp(r'\b0*' + episode.toString() + r'\b').hasMatch(n);
  }

  String _short(String s) => s.length <= 28 ? s : '${s.substring(0, 28)}…';

  // ---------------------------------------------------------------------------
  // Wyzie Subs (keyless OpenSubtitles proxy, direct URLs)
  // ---------------------------------------------------------------------------

  Future<List<ExternalSubtitle>> _fetchWyzie(PlaybackRequest request) async {
    try {
      final params = <String, dynamic>{
        'id': request.tmdbId,
        'language': 'en',
        'format': 'srt',
      };
      if (request.isTvEpisode) {
        params['season'] = request.seasonNumber;
        params['episode'] = request.episodeNumber;
      }

      final response = await _dio.get(
        _wyzieBase,
        queryParameters: params,
        options: Options(responseType: ResponseType.plain, receiveTimeout: const Duration(seconds: 15)),
      );

      dynamic decoded = response.data;
      if (decoded is String) {
        if (decoded.trim().isEmpty) return const [];
        decoded = jsonDecode(decoded);
      }
      if (decoded is! List) return const [];

      final out = <ExternalSubtitle>[];
      final seenUrls = <String>{};
      var n = 0;
      for (final raw in decoded) {
        if (raw is! Map) continue;
        final url = (raw['url'] ?? '').toString();
        if (url.isEmpty || !seenUrls.add(url)) continue;
        final hearingImpaired = raw['isHearingImpaired'] == true;
        n++;
        final suffix = n > 1 ? ' ($n)' : '';
        out.add(ExternalSubtitle(
          url: url,
          label: 'English${hearingImpaired ? ' (HI)' : ''} · OpenSubtitles$suffix',
          kind: SubtitleKind.direct,
        ));
        if (out.length >= 15) break;
      }
      return out;
    } catch (_) {
      return const [];
    }
  }
}
