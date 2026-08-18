import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:movie_bloc_app/common/blocs/bloc/nav_bar_bloc.dart';

import '../../styles/zipx_ui.dart';

/// Bottom navigation restyled to the ZIPX mockup: flat black bar, a short red
/// indicator above the active tab, red icon + label when selected, muted grey
/// otherwise. Tabs map 1:1 to [NavigationMenu]'s body switch.
class CustomBottomNavbar extends StatelessWidget {
  const CustomBottomNavbar({super.key});

  static const List<_NavItem> _items = [
    _NavItem(Icons.home_rounded, 'Home'),
    _NavItem(Icons.search_rounded, 'Search'),
    _NavItem(Icons.tv_rounded, 'TV Shows'),
    _NavItem(Icons.animation_rounded, 'Anime'),
    _NavItem(Icons.bookmark_rounded, 'Watchlist'),
    _NavItem(Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NavBarBloc, NavBarState>(
      builder: (context, state) {
        final current = state is NavBarChanged ? state.currentIndex : 0;
        return Container(
          decoration: const BoxDecoration(
            color: ZipxUi.bg,
            border: Border(top: BorderSide(color: Colors.white10)),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: Row(
                children: [
                  for (int i = 0; i < _items.length; i++)
                    Expanded(
                      child: _NavButton(
                        item: _items[i],
                        selected: i == current,
                        onTap: () => context.read<NavBarBloc>().add(NavBarTapEvent(i)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.selected, required this.onTap});

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? ZipxUi.red : ZipxUi.textMuted;
    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 22,
            height: 3,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: selected ? ZipxUi.red : Colors.transparent,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Icon(item.icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(item.label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.icon, this.label);
  final IconData icon;
  final String label;
}
