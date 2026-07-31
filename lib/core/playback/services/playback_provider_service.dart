import '../../settings/supported_languages.dart';
import '../../settings/user_settings.dart';
import '../domain/entities/playback_request.dart';
import '../domain/entities/provider_playback_result.dart';
import '../domain/providers/streaming_provider.dart';
import '../domain/providers/streaming_provider_registry.dart';
import 'provider_preferences_service.dart';

/// The single entry point the player screen uses to turn a [PlaybackRequest]
/// into a URL to load, and to figure out what to try next when a provider
/// fails. It never builds a URL itself - that's each [StreamingProvider]'s
/// job - it only orchestrates the registry.
class PlaybackProviderService {
  PlaybackProviderService(this._registry, this._preferencesService, this._userSettings);

  final StreamingProviderRegistry _registry;
  final ProviderPreferencesService _preferencesService;
  final UserSettings _userSettings;

  /// The provider that should be offered/tried first, per persisted
  /// preferences.
  StreamingProvider? get preferredProvider => _registry.defaultProvider;

  List<StreamingProvider> get enabledProviders => _registry.enabledProviders;

  bool get automaticFallbackEnabled => _preferencesService.preferences.automaticFallbackEnabled;

  StreamingProvider? providerById(String id) => _registry.getById(id);

  /// Ordered list of providers to attempt for a playback session, starting
  /// with [startingProviderId]. The player screen walks this list one
  /// provider at a time; once it's exhausted, it stops - this is what
  /// prevents an infinite retry loop.
  List<StreamingProvider> fallbackSequence(String startingProviderId) {
    return _registry.fallbackSequence(startingProviderId);
  }

  /// Builds the embed URL for [request] using [provider], wrapped in a
  /// [ProviderPlaybackResult]. `success` here only means "a URL was
  /// constructed" - the player screen updates it once the WebView actually
  /// finishes (or fails to) load it.
  ProviderPlaybackResult buildResult(PlaybackRequest request, StreamingProvider provider) {
    // The user's chosen language (TMDB code, e.g. en-US) becomes the bare
    // ISO 639 subtitle hint (e.g. en) providers can use.
    final languageCode = (_userSettings.getSettings()['language'] as String?) ?? '';
    final subtitleLanguage = iso639ForCode(languageCode);

    final url = request.isTvEpisode
        ? provider.getEpisodeEmbedUrl(request.tmdbId, request.seasonNumber!, request.episodeNumber!, subtitleLanguage: subtitleLanguage)
        : provider.getMovieEmbedUrl(request.tmdbId, subtitleLanguage: subtitleLanguage);

    return ProviderPlaybackResult(providerId: provider.id, embedUrl: url, success: true);
  }

  void setDefaultProvider(String providerId) => _preferencesService.setDefaultProvider(providerId);
}
