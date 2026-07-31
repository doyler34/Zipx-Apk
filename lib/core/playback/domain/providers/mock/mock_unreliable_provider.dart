import '../streaming_provider.dart';

/// Test/demo provider that always fails to load (points at a `.invalid`
/// host, reserved by RFC 2606 to never resolve).
///
/// Lets QA and automated checks exercise the "provider fails -> automatic
/// fallback to next provider -> failed providers list -> manual retry" path
/// deterministically, again without touching [VidSrcProvider]. Disabled by
/// default, same as [MockReliableProvider].
class MockUnreliableProvider extends BaseStreamingProvider {
  MockUnreliableProvider({super.enabledByDefault = false});

  static const String _host = 'mock-unreliable.invalid';

  @override
  String get id => 'mock_unreliable';

  @override
  String get displayName => 'Mock Provider (Always Fails)';

  @override
  int get priority => 91;

  @override
  Uri getMovieEmbedUrl(int tmdbId, {String? subtitleLanguage}) {
    return Uri.https(_host, '/mock-embed/movie/$tmdbId');
  }

  @override
  Uri getEpisodeEmbedUrl(int tmdbId, int season, int episode, {String? subtitleLanguage}) {
    return Uri.https(_host, '/mock-embed/tv/$tmdbId/$season/$episode');
  }

  @override
  bool canHandleNavigation(Uri url) => url.host.toLowerCase() == _host;

  @override
  bool isPlaybackUrl(Uri url) => false;
}
