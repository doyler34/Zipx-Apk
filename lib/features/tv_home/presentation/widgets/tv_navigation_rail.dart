import 'package:flutter/material.dart';

import '../focus/tv_focus_builder.dart';

class TvNavDestination {
  const TvNavDestination(this.icon, this.label);
  final IconData icon;
  final String label;
}

const List<TvNavDestination> kTvNavDestinations = [
  TvNavDestination(Icons.home_rounded, 'Home'),
  TvNavDestination(Icons.movie_rounded, 'Movies'),
  TvNavDestination(Icons.tv_rounded, 'TV Shows'),
  TvNavDestination(Icons.search_rounded, 'Search'),
  TvNavDestination(Icons.bookmark_rounded, 'Watchlist'),
  TvNavDestination(Icons.settings_rounded, 'Settings'),
];

/// Collapsed navigation rail down the left. Expands (shows labels) when any
/// item is focused and collapses when focus moves into the content area.
class TvNavigationRail extends StatefulWidget {
  const TvNavigationRail({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    this.onFocusChange,
    this.firstItemFocusNode,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  /// Fires when focus enters/leaves the whole rail (used to expand it and to
  /// tell the shell whether focus is currently on the rail).
  final ValueChanged<bool>? onFocusChange;

  /// Attached to the first rail item so the shell can move focus to the rail
  /// (e.g. on Back from the content area).
  final FocusNode? firstItemFocusNode;

  @override
  State<TvNavigationRail> createState() => _TvNavigationRailState();
}

class _TvNavigationRailState extends State<TvNavigationRail> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.tertiary;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (hasFocus) {
        widget.onFocusChange?.call(hasFocus);
        if (mounted && hasFocus != _expanded) setState(() => _expanded = hasFocus);
      },
      child: FocusTraversalGroup(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: _expanded ? 210 : 72,
          color: Colors.black.withOpacity(_expanded ? 0.92 : 0.55),
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < kTvNavDestinations.length; i++)
                _RailItem(
                  destination: kTvNavDestinations[i],
                  expanded: _expanded,
                  selected: i == widget.selectedIndex,
                  accent: accent,
                  focusNode: i == 0 ? widget.firstItemFocusNode : null,
                  onSelect: () => widget.onSelect(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.destination,
    required this.expanded,
    required this.selected,
    required this.accent,
    required this.onSelect,
    this.focusNode,
  });

  final TvNavDestination destination;
  final bool expanded;
  final bool selected;
  final Color accent;
  final VoidCallback onSelect;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return TvFocusBuilder(
      focusNode: focusNode,
      onSelect: onSelect,
      builder: (context, focused) {
        final highlight = focused;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: highlight ? accent : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                destination.icon,
                color: highlight || selected ? Colors.white : Colors.white60,
                size: 24,
              ),
              if (expanded) ...[
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: highlight || selected ? Colors.white : Colors.white70,
                      fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
