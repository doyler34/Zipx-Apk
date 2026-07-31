import 'package:hive_flutter/hive_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../domain/entities/provider_preferences.dart';
import '../domain/providers/streaming_provider_registry.dart';

/// Owns persistence for [ProviderPreferences] and keeps the
/// [StreamingProviderRegistry] in sync with whatever is stored.
///
/// Deliberately backed by its own Hive box (`provider_preferences`),
/// completely separate from `UserSettings`'s `settings` box - streaming
/// provider configuration must never mix with TMDB configuration.
class ProviderPreferencesService {
  ProviderPreferencesService(this._registry);

  static const String _boxName = 'provider_preferences';
  static const String _key = 'preferences';

  final StreamingProviderRegistry _registry;
  late ProviderPreferences _preferences;

  ProviderPreferences get preferences => _preferences;

  Future<void> initialize() async {
    final box = Hive.box(_boxName);
    final stored = box.get(_key);

    if (stored is Map) {
      try {
        _preferences = ProviderPreferences.fromMap(stored);
      } catch (_) {
        _preferences = _buildDefaultPreferences();
      }
    } else {
      _preferences = _buildDefaultPreferences();
    }

    _registry.applyPreferences(_preferences);
  }

  ProviderPreferences _buildDefaultPreferences() {
    final providers = List.of(_registry.allProviders)..sort((a, b) => a.priority.compareTo(b.priority));
    final enabledByDefault = providers.where((p) => p.isEnabled).map((p) => p.id).toList();
    final defaultId = enabledByDefault.isNotEmpty ? enabledByDefault.first : providers.first.id;

    return ProviderPreferences(
      defaultProviderId: defaultId,
      enabledProviderIds: enabledByDefault,
      providerPriorityOrder: providers.map((p) => p.id).toList(),
      automaticFallbackEnabled: true,
    );
  }

  Future<void> _persist() async {
    await Hive.box(_boxName).put(_key, _preferences.toMap());
    _registry.applyPreferences(_preferences);
  }

  Future<void> setDefaultProvider(String providerId) async {
    _preferences = _preferences.copyWith(defaultProviderId: providerId);
    await _persist();
  }

  Future<void> setProviderEnabled(String providerId, bool enabled) async {
    final ids = List<String>.from(_preferences.enabledProviderIds);
    if (enabled && !ids.contains(providerId)) {
      ids.add(providerId);
    } else if (!enabled) {
      ids.remove(providerId);
    }
    _preferences = _preferences.copyWith(enabledProviderIds: ids);
    await _persist();
  }

  Future<void> reorderProviders(List<String> providerIdsInPriorityOrder) async {
    _preferences = _preferences.copyWith(providerPriorityOrder: providerIdsInPriorityOrder);
    await _persist();
  }

  Future<void> setAutomaticFallbackEnabled(bool enabled) async {
    _preferences = _preferences.copyWith(automaticFallbackEnabled: enabled);
    await _persist();
  }

  Future<void> resetToDefaults() async {
    _preferences = _buildDefaultPreferences();
    await _persist();
  }

  /// Clears cookies and on-disk website data (localStorage/cache) that
  /// providers' embedded pages may have written, without touching TMDB
  /// settings, bookmarks, or playback history.
  Future<void> clearProviderWebsiteData() async {
    await WebViewCookieManager().clearCookies();
    final controller = WebViewController();
    await controller.clearCache();
    await controller.clearLocalStorage();
  }
}
