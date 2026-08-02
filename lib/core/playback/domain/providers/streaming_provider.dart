/// Contract every embedded playback provider (VidSrc, and anything added
/// later) must implement.
///
/// This is the *only* thing the player UI, [StreamingProviderRegistry] and
/// [PlaybackProviderService] know about a provider. No provider-specific URL
/// pattern, header, or quirk may leak outside the class that implements this
/// interface - see `docs` on each concrete provider for where its rules live.
abstract class StreamingProvider {
  /// Stable, unique identifier (e.g. `'vidsrc'`). Used as the persistence key
  /// in [ProviderPreferences] and Hive, so it must never change once shipped.
  String get id;

  /// Human readable name shown in the provider selector and settings.
  String get displayName;

  /// Default try-order used when the user hasn't customized
  /// [ProviderPreferences.providerPriorityOrder]. Lower value = tried first.
  int get priority;

  /// Whether the player should load this provider's embed URL directly as the
  /// WebView's top document, rather than wrapping it in a local `<iframe>`
  /// page. Most providers only serve content when they detect they're inside
  /// an iframe (so this is `false`); a few (e.g. VidFast/VidLink) do the
  /// opposite and refuse to play inside a nested/sandboxed iframe, so they
  /// must be loaded direct.
  bool get loadDirect;

  /// Whether this provider is currently offered to the user. Starts at each
  /// provider's own sensible default and is then kept in sync with
  /// [ProviderPreferences.enabledProviderIds] by [StreamingProviderRegistry].
  bool get isEnabled;

  /// Flips [isEnabled]. Only ever called by [StreamingProviderRegistry] when
  /// applying persisted preferences or reacting to a settings toggle.
  void setEnabled(bool enabled);

  /// Builds this provider's embed URL for a movie, given its TMDB id.
  ///
  /// [subtitleLanguage] is the user's chosen language as a bare ISO 639-1
  /// code (e.g. `en`), passed through to whatever the provider supports for a
  /// default subtitle language; providers that don't support it ignore it.
  Uri getMovieEmbedUrl(int tmdbId, {String? subtitleLanguage});

  /// Builds this provider's embed URL for a single TV episode, given the
  /// TMDB show id plus season/episode numbers. See [getMovieEmbedUrl] for
  /// [subtitleLanguage].
  Uri getEpisodeEmbedUrl(int tmdbId, int season, int episode, {String? subtitleLanguage});

  /// Whether an in-page navigation the WebView is about to perform should be
  /// allowed to happen *inside* the existing WebView (same provider domain,
  /// a legitimate redirect, a same-site player asset, etc).
  ///
  /// Returning `false` tells the player to block the navigation, which is
  /// how unrelated external pages and obvious pop-ups are kept from
  /// replacing the app screen.
  bool canHandleNavigation(Uri url);

  /// Whether [url] is itself a page this provider considers "the player has
  /// loaded and is showing content", as opposed to an interstitial, ad
  /// redirect, or error page. Used purely to decide whether a load counts as
  /// a successful [ProviderPlaybackResult] - never to extract or proxy the
  /// underlying video stream.
  bool isPlaybackUrl(Uri url);
}

/// Convenience base class that implements the mutable [isEnabled] bookkeeping
/// so concrete providers only need to fill in their URL rules.
abstract class BaseStreamingProvider implements StreamingProvider {
  BaseStreamingProvider({bool enabledByDefault = true}) : _enabled = enabledByDefault;

  bool _enabled;

  /// Providers wrap in an iframe by default; direct-load providers override.
  @override
  bool get loadDirect => false;

  @override
  bool get isEnabled => _enabled;

  @override
  void setEnabled(bool enabled) => _enabled = enabled;
}
