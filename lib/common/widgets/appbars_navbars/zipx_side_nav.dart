import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/bloc/nav_bar_bloc.dart';
import '../../styles/zipx_ui.dart';

/// Desktop / wide-screen navigation rail. Replaces the mobile bottom bar on
/// wide windows: the ZIPX wordmark on top, then the five destinations stacked
/// vertically with a red pill behind the active one. Tabs map 1:1 to the same
/// [NavBarBloc] indices the bottom bar uses.
class ZipxSideNav extends StatelessWidget {
  const ZipxSideNav({super.key});

  static const List<_NavItem> _items = [
    _NavItem(Icons.home_rounded, 'Home'),
    _NavItem(Icons.search_rounded, 'Search'),
    _NavItem(Icons.tv_rounded, 'TV Shows'),
    _NavItem(Icons.bookmark_rounded, 'Watchlist'),
    _NavItem(Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NavBarBloc, NavBarState>(
      builder: (context, state) {
        final current = state is NavBarChanged ? state.currentIndex : 0;
        return Container(
          width: 232,
          decoration: const BoxDecoration(
            color: ZipxUi.bg,
            border: Border(right: BorderSide(color: Colors.white10)),
          ),
          child: SafeArea(
            right: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 26, 24, 30),
                  child: Image.asset(
                    'assets/logos/zipx_logo.png',
                    height: 34,
                    fit: BoxFit.contain,
                    alignment: Alignment.centerLeft,
                  ),
                ),
                for (int i = 0; i < _items.length; i++)
                  _NavTile(
                    item: _items[i],
                    selected: i == current,
                    onTap: () => context.read<NavBarBloc>().add(NavBarTapEvent(i)),
                  ),
                const Spacer(),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.item, required this.selected, required this.onTap});

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : ZipxUi.textMuted;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      child: Material(
        color: selected ? ZipxUi.red : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Icon(item.icon, color: color, size: 22),
                const SizedBox(width: 14),
                Text(
                  item.label,
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.icon, this.label);
  final IconData icon;
  final String label;
}
