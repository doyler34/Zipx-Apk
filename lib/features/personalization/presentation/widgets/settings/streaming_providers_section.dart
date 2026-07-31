import 'package:flutter/material.dart';

import '../../../../../common/styles/styles.dart';
import '../../../../../core/dependency_injection/di.dart';
import '../../../../../core/playback/domain/providers/streaming_provider.dart';
import '../../../../../core/playback/domain/providers/streaming_provider_registry.dart';
import '../../../../../core/playback/services/provider_preferences_service.dart';

/// Settings > Streaming Providers. Talks only to [StreamingProviderRegistry]
/// and [ProviderPreferencesService] - it lists whatever providers are
/// registered and never hardcodes a provider name, so a newly registered
/// provider shows up here automatically.
class StreamingProvidersSection extends StatefulWidget {
  const StreamingProvidersSection({super.key});

  @override
  State<StreamingProvidersSection> createState() => _StreamingProvidersSectionState();
}

class _StreamingProvidersSectionState extends State<StreamingProvidersSection> {
  final _registry = sl<StreamingProviderRegistry>();
  final _preferencesService = sl<ProviderPreferencesService>();
  bool _isClearingData = false;

  List<StreamingProvider> get _orderedProviders {
    final order = _preferencesService.preferences.providerPriorityOrder;
    final providers = List.of(_registry.allProviders);
    providers.sort((a, b) {
      final indexA = order.indexOf(a.id);
      final indexB = order.indexOf(b.id);
      if (indexA != -1 && indexB != -1) return indexA.compareTo(indexB);
      if (indexA != -1) return -1;
      if (indexB != -1) return 1;
      return a.priority.compareTo(b.priority);
    });
    return providers;
  }

  Future<void> _reload() async {
    setState(() {});
  }

  Future<void> _move(int index, int delta) async {
    final providers = _orderedProviders;
    final newIndex = index + delta;
    if (newIndex < 0 || newIndex >= providers.length) return;
    final ids = providers.map((p) => p.id).toList();
    final moved = ids.removeAt(index);
    ids.insert(newIndex, moved);
    await _preferencesService.reorderProviders(ids);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final preferences = _preferencesService.preferences;
    final providers = _orderedProviders;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: Styles(context: context).cardBoxDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Streaming Providers',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            for (int i = 0; i < providers.length; i++)
              _ProviderRow(
                provider: providers[i],
                isDefault: providers[i].id == preferences.defaultProviderId,
                canMoveUp: i > 0,
                canMoveDown: i < providers.length - 1,
                onMoveUp: () => _move(i, -1),
                onMoveDown: () => _move(i, 1),
                onToggleEnabled: (enabled) async {
                  await _preferencesService.setProviderEnabled(providers[i].id, enabled);
                  await _reload();
                },
                onSetDefault: () async {
                  await _preferencesService.setDefaultProvider(providers[i].id);
                  await _reload();
                },
              ),
            const Divider(color: Colors.white24, height: 24),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Automatic fallback', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Try the next enabled provider if one fails', style: TextStyle(color: Colors.white54, fontSize: 12)),
              value: preferences.automaticFallbackEnabled,
              onChanged: (value) async {
                await _preferencesService.setAutomaticFallbackEnabled(value);
                await _reload();
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _isClearingData
                      ? null
                      : () async {
                          setState(() => _isClearingData = true);
                          await _preferencesService.clearProviderWebsiteData();
                          if (mounted) setState(() => _isClearingData = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Provider cookies and website data cleared.')),
                            );
                          }
                        },
                  icon: const Icon(Icons.cookie_outlined),
                  label: Text(_isClearingData ? 'Clearing...' : 'Clear provider cookies & data'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    await _preferencesService.resetToDefaults();
                    await _reload();
                  },
                  icon: const Icon(Icons.restore),
                  label: const Text('Reset provider settings'),
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

class _ProviderRow extends StatelessWidget {
  const _ProviderRow({
    required this.provider,
    required this.isDefault,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onToggleEnabled,
    required this.onSetDefault,
  });

  final StreamingProvider provider;
  final bool isDefault;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final ValueChanged<bool> onToggleEnabled;
  final VoidCallback onSetDefault;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                iconSize: 18,
                icon: const Icon(Icons.keyboard_arrow_up, color: Colors.white54),
                onPressed: canMoveUp ? onMoveUp : null,
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                iconSize: 18,
                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white54),
                onPressed: canMoveDown ? onMoveDown : null,
              ),
            ],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    provider.displayName,
                    style: const TextStyle(color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isDefault)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.star, color: Colors.amber, size: 16),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: isDefault ? null : onSetDefault,
            child: Text(isDefault ? 'Default' : 'Set default', style: const TextStyle(fontSize: 12)),
          ),
          Switch(
            value: provider.isEnabled,
            onChanged: onToggleEnabled,
          ),
        ],
      ),
    );
  }
}
