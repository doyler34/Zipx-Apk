import 'dart:convert';

import 'package:dio/dio.dart';

import '../domain/entities/playback_request.dart';

/// One downloadable external subtitle track for a title.
class ExternalSubtitle {
  const ExternalSubtitle({required this.url, required this.label, required this.language});

  /// Direct URL to the subtitle file (SRT/VTT) - loaded straight into mpv.
  final String url;

  /// Human-readable label for the picker, e.g. "English" or "English (HI)".
  final String label;

  /// ISO language code, passed through to the player track.
  final String language;
}

/// Fetches external subtitles for a title so text subs are available even when
/// the streamed file (a Real-Debrid torrent) has none embedded.
///
/// Uses Wyzie Subs (sub.wyzie.ru) - a free, keyless subtitle search that maps a
/// TMDB id (+ season/episode for TV) to direct subtitle-file URLs sourced from
/// OpenSubtitles. No account or API key needed, matching how the rest of the
/// playback stack stays configuration-free on the device.
class SubtitleService {
  SubtitleService(this._dio);

  final Dio _dio;

  static const String _base = 'https://sub.wyzie.ru/search';

  /// A broad-but-bounded set of common languages so the picker isn't flooded
  /// with dozens of obscure ones. English first.
  static const String _languages = 'en,es,fr,de,it,pt,pt-BR,nl,ar,hi,ru,ja,ko,zh,pl,tr,sv,da,no,fi';

  Future<List<ExternalSubtitle>> fetch(PlaybackRequest request) async {
    try {
      final params = <String, dynamic>{
        'id': request.tmdbId,
        'language': _languages,
        'format': 'srt',
      };
      if (request.isTvEpisode) {
        params['season'] = request.seasonNumber;
        params['episode'] = request.episodeNumber;
      }

      final response = await _dio.get(
        _base,
        queryParameters: params,
        options: Options(
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      dynamic decoded = response.data;
      if (decoded is String) {
        if (decoded.trim().isEmpty) return const [];
        decoded = jsonDecode(decoded);
      }
      if (decoded is! List) return const [];

      final out = <ExternalSubtitle>[];
      final seenUrls = <String>{};
      // How many of each display label we've added, so duplicate "English"
      // entries become "English", "English (2)", "English (3)" - distinguishable
      // in the picker.
      final labelCounts = <String, int>{};

      for (final raw in decoded) {
        if (raw is! Map) continue;
        final url = (raw['url'] ?? '').toString();
        if (url.isEmpty || !seenUrls.add(url)) continue;

        final display = (raw['display'] ?? raw['language'] ?? 'Subtitle').toString().trim();
        final language = (raw['language'] ?? '').toString().trim();
        final hearingImpaired = raw['isHearingImpaired'] == true;

        var label = display.isEmpty ? (language.isEmpty ? 'Subtitle' : language) : display;
        if (hearingImpaired) label = '$label (HI)';

        final count = (labelCounts[label] ?? 0) + 1;
        labelCounts[label] = count;
        final uniqueLabel = count == 1 ? label : '$label ($count)';

        out.add(ExternalSubtitle(url: url, label: uniqueLabel, language: language));
        if (out.length >= 40) break;
      }

      return out;
    } catch (_) {
      // Non-critical: playback still works, just without online subs.
      return const [];
    }
  }
}
