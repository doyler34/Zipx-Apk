import '../streaming_provider.dart';

/// Test/demo provider that always resolves to a page that loads successfully.
///
/// Exists so the provider registry, fallback sequencing and provider
/// selector UI can be exercised end-to-end without depending on a real
/// third-party embed, and without any of that test scaffolding living inside
/// [VidSrcProvider]. Disabled by default - a real user never sees it unless
/// they enable it from Settings > Streaming Providers.
class MockReliableProvider extends BaseStreamingProvider {
  MockReliableProvider({super.enabledByDefault = false});

  static const String _host = 'example.com';

  @override
  String get id => 'mock_reliable';

  @override
  String get displayName => 'Mock Provider (Reliable)';

  @override
  int get priority => 90;

  @override
  Uri getMovieEmbedUrl(int tmdbId) {
    return Uri.https(_host, '/mock-embed/movie/$tmdbId');
  }

  @override
  Uri getEpisodeEmbedUrl(int tmdbId, int season, int episode) {
    return Uri.https(_host, '/mock-embed/tv/$tmdbId/$season/$episode');
  }

  @override
  bool canHandleNavigation(Uri url) => url.host.toLowerCase() == _host;

  @override
  bool isPlaybackUrl(Uri url) => url.host.toLowerCase() == _host && url.path.startsWith('/mock-embed/');
}
