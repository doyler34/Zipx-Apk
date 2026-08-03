import 'streaming_provider.dart';

/// A [StreamingProvider] whose only per-provider logic is the shape of its
/// embed URL, supplied as builder functions. This lets a whole catalogue of
/// TMDB-id-keyed embed providers be registered as *data* (see
/// [buildEmbedProviders]) instead of a class per provider.
class TemplateEmbedProvider extends BaseStreamingProvider {
  TemplateEmbedProvider({
    required this.id,
    required this.displayName,
    required this.priority,
    required String Function(int tmdbId) movieUrl,
    required String Function(int tmdbId, int season, int episode) episodeUrl,
    bool loadDirect = false,
    super.enabledByDefault,
  })  : _movieUrl = movieUrl,
        _episodeUrl = episodeUrl,
        _loadDirect = loadDirect;

  @override
  final String id;

  @override
  final String displayName;

  @override
  final int priority;

  final String Function(int tmdbId) _movieUrl;
  final String Function(int tmdbId, int season, int episode) _episodeUrl;
  final bool _loadDirect;

  @override
  bool get loadDirect => _loadDirect;

  /// The provider's own host, derived once from a sample built URL. Used to
  /// recognize its own (and same-registrable-domain) navigations.
  late final String _host = Uri.parse(_movieUrl(1)).host.toLowerCase();

  /// Registrable domain (last two labels, e.g. `vidsrc.pm`) so a provider's
  /// CDN/mirror subdomains still count as "its own".
  late final String _baseDomain = () {
    final parts = _host.split('.');
    return parts.length >= 2 ? parts.sublist(parts.length - 2).join('.') : _host;
  }();

  @override
  Uri getMovieEmbedUrl(int tmdbId, {String? subtitleLanguage}) => Uri.parse(_movieUrl(tmdbId));

  @override
  Uri getEpisodeEmbedUrl(int tmdbId, int season, int episode, {String? subtitleLanguage}) => Uri.parse(_episodeUrl(tmdbId, season, episode));

  @override
  bool canHandleNavigation(Uri url) {
    final host = url.host.toLowerCase();
    return host == _host || host.endsWith('.$_baseDomain') || host == _baseDomain;
  }

  @override
  bool isPlaybackUrl(Uri url) => canHandleNavigation(url);
}

/// The embed-provider catalogue, adapted from the MIT-licensed
/// `tmdb-embed-providers` package (Astralchemist/tmdb-embed-providers). Each
/// entry is just a TMDB-id-keyed iframe URL shape; adding/removing one is a
/// single line here.
///
/// "Core" global providers are enabled by default (fresh installs) to give a
/// healthy fallback chain; the Asian-content "extras" rotate domains more
/// often, so they're registered but off by default - users can enable them in
/// Settings > Streaming Providers.
List<StreamingProvider> buildEmbedProviders() {
  return [
    // The providers confirmed working + ad-free on-device (alongside VidSrc,
    // registered separately as the priority-0 default). Others tested but
    // dropped: VidFast, 2Embed, VidSrc.to, VidSrc.cc, AutoEmbed, MoviesAPI.
    TemplateEmbedProvider(
      id: 'vidlink',
      displayName: 'VidLink',
      priority: 1,
      loadDirect: true,
      movieUrl: (id) => 'https://vidlink.pro/movie/$id',
      episodeUrl: (id, s, e) => 'https://vidlink.pro/tv/$id/$s/$e',
    ),
    TemplateEmbedProvider(
      id: 'vidsrc-pm',
      displayName: 'VidSrc.pm',
      priority: 2,
      movieUrl: (id) => 'https://vidsrc.pm/embed/movie/$id',
      episodeUrl: (id, s, e) => 'https://vidsrc.pm/embed/tv/$id/$s/$e',
    ),
    TemplateEmbedProvider(
      id: 'superembed',
      displayName: 'SuperEmbed',
      priority: 3,
      // SuperEmbed's embed lives on multiembed.mov; tmdb=1 is required since
      // we only ever pass TMDB ids. Its player has its own multi-server picker.
      movieUrl: (id) => 'https://multiembed.mov/?video_id=$id&tmdb=1',
      episodeUrl: (id, s, e) => 'https://multiembed.mov/?video_id=$id&tmdb=1&s=$s&e=$e',
    ),
  ];
}
