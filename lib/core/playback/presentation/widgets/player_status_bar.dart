import 'package:flutter/material.dart';

/// Top bar for the player screen: shows the movie/episode title, which
/// provider is currently active, a "switch provider" action and a close
/// button. Purely presentational - all it knows is a display name string.
class PlayerStatusBar extends StatelessWidget implements PreferredSizeWidget {
  const PlayerStatusBar({
    super.key,
    required this.title,
    required this.activeProviderName,
    required this.onSwitchProvider,
    required this.onClose,
  });

  final String title;
  final String? activeProviderName;
  final VoidCallback onSwitchProvider;
  final VoidCallback onClose;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Close player',
        onPressed: onClose,
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16)),
          if (activeProviderName != null)
            Text(
              'Playing via $activeProviderName',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.swap_horiz),
          tooltip: 'Switch provider',
          onPressed: onSwitchProvider,
        ),
      ],
    );
  }
}
