import '../entities/provider_preferences.dart';
import 'streaming_provider.dart';

/// Central catalogue of every [StreamingProvider] the app knows about.
///
/// This is the *only* place providers get registered. The player UI and
/// [PlaybackProviderService] never construct a provider directly - they ask
/// the registry for one by id, or for the current enabled/priority-sorted
/// list. Adding a provider means creating one new [StreamingProvider] class
/// and adding one line to the list below; nothing else in the app changes.
class StreamingProviderRegistry {
  StreamingProviderRegistry(List<StreamingProvider> providers) : _providers = List.of(providers);

  final List<StreamingProvider> _providers;

  /// User-customized try order (provider ids, highest priority first).
  /// `null` entries fall back to [StreamingProvider.priority].
  List<String>? _customPriorityOrder;

  String? _defaultProviderId;

  /// Every registered provider, regardless of enabled state.
  List<StreamingProvider> get allProviders => List.unmodifiable(_providers);

  /// Enabled providers, sorted by priority (custom order first, then each
  /// provider's own declared [StreamingProvider.priority] as a tiebreak/
  /// fallback for anything not present in the custom order).
  List<StreamingProvider> get enabledProviders {
    final enabled = _providers.where((p) => p.isEnabled).toList();
    enabled.sort(_comparePriority);
    return enabled;
  }

  int _comparePriority(StreamingProvider a, StreamingProvider b) {
    final order = _customPriorityOrder;
    if (order != null) {
      final indexA = order.indexOf(a.id);
      final indexB = order.indexOf(b.id);
      if (indexA != -1 && indexB != -1) return indexA.compareTo(indexB);
      if (indexA != -1) return -1;
      if (indexB != -1) return 1;
    }
    return a.priority.compareTo(b.priority);
  }

  StreamingProvider? getById(String id) {
    for (final provider in _providers) {
      if (provider.id == id) return provider;
    }
    return null;
  }

  void setEnabled(String id, bool enabled) {
    getById(id)?.setEnabled(enabled);
  }

  void reorder(List<String> providerIdsInPriorityOrder) {
    _customPriorityOrder = List.of(providerIdsInPriorityOrder);
  }

  void setDefaultProvider(String id) {
    if (getById(id) != null) _defaultProviderId = id;
  }

  /// The provider that should be tried first for a new playback request:
  /// the user's chosen default if it's still enabled, otherwise the highest
  /// priority enabled provider.
  StreamingProvider? get defaultProvider {
    final defaultId = _defaultProviderId;
    if (defaultId != null) {
      final provider = getById(defaultId);
      if (provider != null && provider.isEnabled) return provider;
    }
    final enabled = enabledProviders;
    return enabled.isEmpty ? null : enabled.first;
  }

  /// Ordered list of providers to attempt for automatic fallback, starting
  /// with [startingProviderId] (if it's enabled) followed by the remaining
  /// enabled providers in priority order. Never contains duplicates and
  /// never loops - callers exhaust this list exactly once per playback
  /// attempt, which is what keeps fallback from retrying forever.
  List<StreamingProvider> fallbackSequence(String startingProviderId) {
    final sequence = <StreamingProvider>[];
    final starting = getById(startingProviderId);
    if (starting != null && starting.isEnabled) sequence.add(starting);
    for (final provider in enabledProviders) {
      if (!sequence.contains(provider)) sequence.add(provider);
    }
    return sequence;
  }

  /// Applies persisted [ProviderPreferences] to every registered provider's
  /// enabled state, the custom priority order and the default provider.
  /// Called once at startup by [ProviderPreferencesService] and again
  /// whenever the user changes something in Settings > Streaming Providers.
  void applyPreferences(ProviderPreferences preferences) {
    // `providerPriorityOrder` lists every provider that existed when these
    // preferences were saved. A provider whose id ISN'T in it is new - added
    // to the registry since - so we must NOT force it off just because it's
    // absent from the saved enabled list; we leave it at its own default
    // enabled state. Without this, providers added later are silently hidden
    // by preferences saved on an earlier launch (e.g. a saved "VidSrc-only"
    // state would hide a freshly-added test batch).
    final known = preferences.providerPriorityOrder.toSet();
    for (final provider in _providers) {
      if (known.contains(provider.id)) {
        provider.setEnabled(preferences.enabledProviderIds.contains(provider.id));
      }
      // else: brand-new provider - keep its built-in default (enabledByDefault).
    }
    _customPriorityOrder = preferences.providerPriorityOrder;
    _defaultProviderId = preferences.defaultProviderId;
  }
}
