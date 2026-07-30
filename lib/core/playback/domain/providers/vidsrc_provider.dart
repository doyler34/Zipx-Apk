import 'streaming_provider.dart';

/// VidSrc embedded playback provider.
///
/// Every VidSrc-specific detail (domain, path structure, query params, which
/// hosts its player is allowed to navigate to) is contained in this file.
/// No other file in the app should ever construct or parse a vidsrc.* URL.
class VidSrcProvider extends BaseStreamingProvider {
  VidSrcProvider({super.enabledByDefault = true});

  static const String _host = 'vidsrc.to';

  @override
  String get id => 'vidsrc';

  @override
  String get displayName => 'VidSrc';

  @override
  int get priority => 0;

  @override
  Uri getMovieEmbedUrl(int tmdbId) {
    return Uri.https(_host, '/embed/movie/$tmdbId');
  }

  @override
  Uri getEpisodeEmbedUrl(int tmdbId, int season, int episode) {
    return Uri.https(_host, '/embed/tv/$tmdbId/$season/$episode');
  }

  @override
  bool canHandleNavigation(Uri url) {
    // VidSrc's player legitimately redirects across a handful of sibling
    // domains for its CDN/ad-free sources. Anything outside that family is
    // treated as an unrelated page and blocked by the player.
    final host = url.host.toLowerCase();
    return host == _host || host.endsWith('.$_host') || host.contains('vidsrc');
  }

  @override
  bool isPlaybackUrl(Uri url) {
    final host = url.host.toLowerCase();
    return (host == _host || host.endsWith('.$_host')) && url.path.startsWith('/embed/');
  }
}
