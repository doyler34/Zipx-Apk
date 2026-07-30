import 'package:equatable/equatable.dart';

/// The outcome of asking a single [StreamingProvider] for an embed URL, and
/// later, of the WebView actually trying to load it. Returned by
/// [PlaybackProviderService] so the player UI can show which provider is
/// active and which ones already failed, without knowing any provider's
/// internal URL rules.
class ProviderPlaybackResult extends Equatable {
  const ProviderPlaybackResult({
    required this.providerId,
    required this.embedUrl,
    required this.success,
    this.errorMessage,
  });

  final String providerId;
  final Uri embedUrl;
  final bool success;
  final String? errorMessage;

  ProviderPlaybackResult copyWith({
    bool? success,
    String? errorMessage,
  }) {
    return ProviderPlaybackResult(
      providerId: providerId,
      embedUrl: embedUrl,
      success: success ?? this.success,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [providerId, embedUrl, success, errorMessage];
}
