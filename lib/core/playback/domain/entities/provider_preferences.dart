import 'package:equatable/equatable.dart';

/// Persisted, user-controlled configuration for the streaming provider
/// system. Deliberately separate from [UserSettings] (TMDB config) so that
/// provider configuration never mixes with metadata configuration.
class ProviderPreferences extends Equatable {
  const ProviderPreferences({
    required this.defaultProviderId,
    required this.enabledProviderIds,
    required this.providerPriorityOrder,
    required this.automaticFallbackEnabled,
  });

  factory ProviderPreferences.initial({
    required String defaultProviderId,
    required List<String> allProviderIds,
  }) {
    return ProviderPreferences(
      defaultProviderId: defaultProviderId,
      enabledProviderIds: [defaultProviderId],
      providerPriorityOrder: allProviderIds,
      automaticFallbackEnabled: true,
    );
  }

  /// The provider id tried first for every new playback request.
  final String defaultProviderId;

  /// Providers the user has switched on. Providers not in this list are
  /// never offered, even if the app ships a class for them.
  final List<String> enabledProviderIds;

  /// User-customized try-order (highest priority first). Providers absent
  /// from this list fall back to their own declared [StreamingProvider.priority].
  final List<String> providerPriorityOrder;

  /// Whether the player should silently try the next enabled provider when
  /// the active one fails, instead of just showing an error.
  final bool automaticFallbackEnabled;

  ProviderPreferences copyWith({
    String? defaultProviderId,
    List<String>? enabledProviderIds,
    List<String>? providerPriorityOrder,
    bool? automaticFallbackEnabled,
  }) {
    return ProviderPreferences(
      defaultProviderId: defaultProviderId ?? this.defaultProviderId,
      enabledProviderIds: enabledProviderIds ?? this.enabledProviderIds,
      providerPriorityOrder: providerPriorityOrder ?? this.providerPriorityOrder,
      automaticFallbackEnabled: automaticFallbackEnabled ?? this.automaticFallbackEnabled,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'defaultProviderId': defaultProviderId,
      'enabledProviderIds': enabledProviderIds,
      'providerPriorityOrder': providerPriorityOrder,
      'automaticFallbackEnabled': automaticFallbackEnabled,
    };
  }

  factory ProviderPreferences.fromMap(Map<dynamic, dynamic> map) {
    return ProviderPreferences(
      defaultProviderId: map['defaultProviderId'] as String,
      enabledProviderIds: List<String>.from(map['enabledProviderIds'] as List),
      providerPriorityOrder: List<String>.from(map['providerPriorityOrder'] as List),
      automaticFallbackEnabled: map['automaticFallbackEnabled'] as bool,
    );
  }

  @override
  List<Object?> get props => [defaultProviderId, enabledProviderIds, providerPriorityOrder, automaticFallbackEnabled];
}
