import 'streaming_provider.dart';

/// VidSrc embedded playback provider.
///
/// Every VidSrc-specific detail (domain, path structure, query params, which
/// hosts its player is allowed to navigate to) is contained in this file.
/// No other file in the app should ever construct or parse a vidsrc-embed.*
/// URL.
///
/// Per VidSrc's own API docs (https://vidsrc-embed.ru/api/):
///   Movie:   /embed/movie/{tmdb_id}
///   Episode: /embed/tv/{tmdb_id}/{season}-{episode}   (hyphenated, not
///            separate path segments)
/// `imdb`/`tmdb` ids are accepted interchangeably in that path slot; this app
/// only ever has TMDB ids (TMDB is the metadata provider), so that's all we
/// send. `autoplay=1` is passed explicitly for a predictable start rather
/// than relying on VidSrc's current default.
class VidSrcProvider extends BaseStreamingProvider {
  VidSrcProvider({super.enabledByDefault = true});

  /// Primary embed domain. VidSrc publishes a handful of interchangeable
  /// domains (see [_knownDomains]) - any of them work as the embed host.
  static const String _host = 'vidsrc-embed.ru';

  /// Every domain VidSrc's own docs list as valid for embed URLs, plus
  /// `vidsrc.me` (referenced by their docs as the subtitle sample host).
  /// Used to recognize in-family navigations/redirects so the player doesn't
  /// block VidSrc's own mirrors while still blocking unrelated pages.
  static const List<String> _knownDomains = [
    'vidsrc-embed.ru',
    'vidsrc-embed.su',
    'vidsrcme.su',
    'vsrc.su',
    'vidsrc.me',
  ];

  @override
  String get id => 'vidsrc';

  @override
  String get displayName => 'VidSrc';

  /// VidSrc is resolved to a direct `.m3u8` by [VidSrcExtractor] and played
  /// natively (ExoPlayer), which is what makes the Fire TV remote work.
  @override
  bool get supportsNativeExtraction => true;

  @override
  int get priority => 0;

  @override
  Uri getMovieEmbedUrl(int tmdbId, {String? subtitleLanguage}) {
    return Uri.https(_host, '/embed/movie/$tmdbId', _query(subtitleLanguage));
  }

  @override
  Uri getEpisodeEmbedUrl(int tmdbId, int season, int episode, {String? subtitleLanguage}) {
    return Uri.https(_host, '/embed/tv/$tmdbId/$season-$episode', _query(subtitleLanguage));
  }

  // VidSrc supports `ds_lang` (default subtitle language, ISO 639) alongside
  // `autoplay`. Only included when a language is provided.
  Map<String, String> _query(String? subtitleLanguage) {
    final query = {'autoplay': '1'};
    final lang = subtitleLanguage?.trim();
    if (lang != null && lang.isNotEmpty) query['ds_lang'] = lang;
    return query;
  }

  @override
  bool canHandleNavigation(Uri url) {
    // VidSrc's player legitimately redirects across its own mirror domains
    // and CDN sources. Anything outside that family is treated as an
    // unrelated page and blocked by the player.
    final host = url.host.toLowerCase();
    return _isKnownDomain(host) || host.contains('vidsrc');
  }

  @override
  bool isPlaybackUrl(Uri url) {
    final host = url.host.toLowerCase();
    return _isKnownDomain(host) && url.path.startsWith('/embed/');
  }

  bool _isKnownDomain(String host) {
    return _knownDomains.any((domain) => host == domain || host.endsWith('.$domain'));
  }
}
