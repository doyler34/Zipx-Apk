import 'package:flutter/material.dart';

import '../../common/styles/zipx_ui.dart';
import '../../common/widgets/tv/tv_focusable.dart';

/// A desktop navigation destination.
class DesktopNavItem {
  const DesktopNavItem(this.icon, this.label);
  final IconData icon;
  final String label;
}

const List<DesktopNavItem> kDesktopNavItems = [
  DesktopNavItem(Icons.home_rounded, 'Home'),
  DesktopNavItem(Icons.search_rounded, 'Search'),
  DesktopNavItem(Icons.tv_rounded, 'TV Shows'),
  DesktopNavItem(Icons.bookmark_rounded, 'Watchlist'),
];

/// Profile lives at the very bottom of the rail (its content index follows the
/// main destinations).
const int kDesktopProfileIndex = 4;

/// The persistent left navigation rail for the desktop UI: the ZIPX wordmark on
/// top, the destinations below with a red pill behind the active one. Collapses
/// to an icon-only rail on narrower desktop windows.
class DesktopSidebar extends StatelessWidget {
  const DesktopSidebar({
    super.key,
    required this.currentIndex,
    required this.onSelected,
    this.expanded = true,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: expanded ? 236 : 82,
      decoration: const BoxDecoration(
        color: ZipxUi.bg,
        border: Border(right: BorderSide(color: Colors.white10)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: expanded ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(expanded ? 24 : 0, 26, expanded ? 24 : 0, 30),
              child: expanded
                  ? Image.asset('assets/logos/zipx_logo.png', height: 34, fit: BoxFit.contain, alignment: Alignment.centerLeft)
                  : Image.asset('assets/logos/zipx_logo.png', height: 26, width: 40, fit: BoxFit.contain),
            ),
            for (int i = 0; i < kDesktopNavItems.length; i++)
              _NavTile(
                item: kDesktopNavItems[i],
                selected: i == currentIndex,
                expanded: expanded,
                onTap: () => onSelected(i),
              ),
            const Spacer(),
            // Profile pinned to the bottom-left as a circular account icon.
            Padding(
              padding: EdgeInsets.fromLTRB(expanded ? 18 : 0, 0, 0, 20),
              child: Align(
                alignment: expanded ? Alignment.centerLeft : Alignment.center,
                child: _ProfileButton(
                  selected: currentIndex == kDesktopProfileIndex,
                  onTap: () => onSelected(kDesktopProfileIndex),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Circular account button pinned to the bottom of the rail.
class _ProfileButton extends StatelessWidget {
  const _ProfileButton({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      onPressed: onTap,
      borderRadius: 23,
      focusScale: 1.1,
      child: Tooltip(
        message: 'Profile',
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? ZipxUi.red : ZipxUi.surfaceHigh,
            border: Border.all(color: selected ? ZipxUi.red : Colors.white24, width: 1.5),
          ),
          child: const Icon(Icons.person_rounded, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.item, required this.selected, required this.expanded, required this.onTap});

  final DesktopNavItem item;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : ZipxUi.textMuted;
    final tile = Container(
      margin: EdgeInsets.symmetric(horizontal: expanded ? 14 : 10, vertical: 3),
      padding: EdgeInsets.symmetric(horizontal: expanded ? 16 : 0, vertical: 13),
      decoration: BoxDecoration(
        color: selected ? ZipxUi.red : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          Icon(item.icon, color: color, size: 22),
          if (expanded) ...[
            const SizedBox(width: 14),
            Text(
              item.label,
              style: TextStyle(color: color, fontSize: 15, fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
            ),
          ],
        ],
      ),
    );

    return TvFocusable(
      onPressed: onTap,
      borderRadius: 12,
      focusScale: 1.03,
      child: expanded ? tile : Tooltip(message: item.label, child: tile),
    );
  }
}
