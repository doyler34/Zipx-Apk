import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../common/responsive/responsive.dart';
import '../common/styles/zipx_ui.dart';
import '../core/dependency_injection/di.dart';
import '../features/movies/presentation/blocs/home/home/home_bloc.dart';
import '../features/movies/presentation/pages/search/search_screen.dart';
import '../features/personalization/presentation/pages/bookmarks/bookmarks_screen.dart';
import '../features/personalization/presentation/pages/settings/settings_screen.dart';
import '../features/tv/presentation/pages/tv_home_screen.dart';
import 'screens/desktop_home_screen.dart';
import 'widgets/desktop_sidebar.dart';

/// Root of the dedicated desktop UI. A persistent left sidebar plus a swapping
/// content area. Home is a purpose-built desktop screen; the other tabs render
/// the existing screens for now and are being rebuilt for desktop next.
class DesktopShell extends StatefulWidget {
  const DesktopShell({super.key});

  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    // Full labels on wide monitors, icon-only rail on smaller desktop windows.
    final expanded = Responsive.isWide(context);
    final screens = <Widget>[
      const DesktopHomeScreen(),
      const SearchScreen(),
      const TvHomeScreen(),
      const BookmarksScreen(),
      const SettingsScreen(),
    ];

    return BlocProvider(
      create: (_) => sl<HomeBloc>(),
      child: Scaffold(
        backgroundColor: ZipxUi.bg,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DesktopSidebar(
              currentIndex: _index,
              expanded: expanded,
              onSelected: (i) => setState(() => _index = i),
            ),
            Expanded(
              child: SafeArea(
                left: false,
                child: IndexedStack(index: _index, children: screens),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
