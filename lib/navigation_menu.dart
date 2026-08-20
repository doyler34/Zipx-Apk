import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:movie_bloc_app/common/blocs/bloc/nav_bar_bloc.dart';
import 'package:movie_bloc_app/common/styles/zipx_ui.dart';
import 'package:movie_bloc_app/core/dependency_injection/di.dart';
import 'package:movie_bloc_app/features/movies/presentation/widgets/home/zipx_home_header.dart';
import 'package:movie_bloc_app/features/movies/presentation/blocs/home/home/home_bloc.dart';
import 'package:movie_bloc_app/features/movies/presentation/pages/search/search_screen.dart';
import 'package:movie_bloc_app/features/personalization/presentation/pages/settings/settings_screen.dart';

import 'common/widgets/appbars_navbars/custom_bottom_navbar.dart';
import 'features/anime/presentation/pages/anime_home_screen.dart';
import 'features/movies/presentation/pages/home/home_screen.dart';
import 'features/personalization/presentation/pages/bookmarks/bookmarks_screen.dart';
import 'features/tv/presentation/pages/tv_home_screen.dart';

/// Phone / tablet navigation shell: a floating header, the tab body, and the
/// bottom navigation bar. Desktop windows use [DesktopShell] instead (branched
/// in the router), so this stays the mobile layout only.
class NavigationMenu extends StatelessWidget {
  const NavigationMenu({super.key});

  Widget _bodyFor(int index) {
    switch (index) {
      case 1:
        return const TvHomeScreen();
      case 2:
        return const AnimeHomeScreen();
      case 3:
        return const SearchScreen();
      case 4:
        return const BookmarksScreen();
      case 5:
        return const SettingsScreen();
      case 0:
      default:
        return const HomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<HomeBloc>(),
      child: Scaffold(
        backgroundColor: ZipxUi.bg,
        resizeToAvoidBottomInset: false,
        bottomNavigationBar: const CustomBottomNavbar(),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return const [ZipxHomeHeader()];
          },
          body: BlocBuilder<NavBarBloc, NavBarState>(
            builder: (context, state) {
              final index = state is NavBarChanged ? state.currentIndex : 0;
              return _bodyFor(index);
            },
          ),
        ),
      ),
    );
  }
}
