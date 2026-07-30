import 'package:flutter/material.dart';

/// Error state shown when a provider fails to load (network error, provider
/// down, etc). Offers a plain retry of the same provider and a way to pick a
/// different one, plus a summary of everything that has already failed this
/// session.
class PlayerErrorView extends StatelessWidget {
  const PlayerErrorView({
    super.key,
    required this.message,
    required this.failedProviderNames,
    required this.onRetry,
    required this.onTryAnotherProvider,
    required this.exhausted,
  });

  final String message;
  final List<String> failedProviderNames;
  final VoidCallback onRetry;
  final VoidCallback onTryAnotherProvider;

  /// True once every enabled provider has been tried and failed.
  final bool exhausted;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(
              exhausted ? 'All providers failed to load this title.' : message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            if (failedProviderNames.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Failed: ${failedProviderNames.join(', ')}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
                OutlinedButton.icon(
                  onPressed: onTryAnotherProvider,
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Try another provider'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
