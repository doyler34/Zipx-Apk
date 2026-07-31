import 'package:flutter/material.dart';

import '../../domain/providers/streaming_provider.dart';

/// Bottom sheet that lists every enabled [StreamingProvider] and lets the
/// user pick which one to play with. Shown before the first playback
/// attempt, and again any time the user taps "Switch provider" or
/// "Try another provider" on the player screen.
///
/// Purely a picker: it knows nothing about VidSrc or any other provider's
/// URL rules, only the generic [StreamingProvider.displayName] shape.
class ProviderSelectorSheet extends StatelessWidget {
  const ProviderSelectorSheet({
    super.key,
    required this.providers,
    required this.failedProviderIds,
    this.activeProviderId,
  });

  final List<StreamingProvider> providers;
  final Set<String> failedProviderIds;
  final String? activeProviderId;

  static Future<StreamingProvider?> show(
    BuildContext context, {
    required List<StreamingProvider> providers,
    required Set<String> failedProviderIds,
    String? activeProviderId,
  }) {
    return showModalBottomSheet<StreamingProvider>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.primary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ProviderSelectorSheet(
        providers: providers,
        failedProviderIds: failedProviderIds,
        activeProviderId: activeProviderId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Choose a provider',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            if (providers.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Text('No streaming providers are enabled. Enable one in Settings.', style: TextStyle(color: Colors.white70)),
              ),
            for (final provider in providers)
              ListTile(
                leading: Icon(
                  Icons.play_circle_fill,
                  color: provider.id == activeProviderId ? Theme.of(context).colorScheme.tertiary : Colors.white70,
                ),
                title: Text(provider.displayName, style: const TextStyle(color: Colors.white)),
                subtitle: failedProviderIds.contains(provider.id)
                    ? const Text('Failed last attempt - tap to retry', style: TextStyle(color: Colors.redAccent))
                    : null,
                trailing: provider.id == activeProviderId ? const Icon(Icons.check, color: Colors.white) : null,
                onTap: () => Navigator.of(context).pop(provider),
              ),
          ],
        ),
      ),
    );
  }
}
