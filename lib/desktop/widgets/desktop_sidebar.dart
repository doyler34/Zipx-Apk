import 'package:flutter/material.dart';

import '../../common/styles/zipx_ui.dart';

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
  DesktopNavItem(Icons.person_rounded, 'Profile'),
];

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
          ],
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

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: expanded ? tile : Tooltip(message: item.label, child: tile),
      ),
    );
  }
}
