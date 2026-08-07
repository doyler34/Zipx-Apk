import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:movie_bloc_app/common/blocs/bloc/nav_bar_bloc.dart';
import 'package:movie_bloc_app/common/responsive/responsive.dart';
import 'package:movie_bloc_app/common/styles/zipx_ui.dart';
import 'package:movie_bloc_app/common/widgets/appbars_navbars/zipx_side_nav.dart';
import 'package:movie_bloc_app/core/dependency_injection/di.dart';
import 'package:movie_bloc_app/features/movies/presentation/widgets/home/zipx_home_header.dart';
import 'package:movie_bloc_app/features/movies/presentation/blocs/home/home/home_bloc.dart';
import 'package:movie_bloc_app/features/movies/presentation/pages/search/search_screen.dart';
import 'package:movie_bloc_app/features/personalization/presentation/pages/settings/settings_screen.dart';

import 'common/widgets/appbars_navbars/custom_bottom_navbar.dart';
import 'features/movies/presentation/pages/home/home_screen.dart';
import 'features/personalization/presentation/pages/bookmarks/bookmarks_screen.dart';
import 'features/tv/presentation/pages/tv_home_screen.dart';

class NavigationMenu extends StatelessWidget {
  const NavigationMenu({super.key});

  /// The screen for a given nav index. Shared by the phone and desktop shells.
  Widget _bodyFor(int index) {
    switch (index) {
      case 1:
        return const SearchScreen();
      case 2:
        return const TvHomeScreen();
      case 3:
        return const BookmarksScreen();
      case 4:
        return const SettingsScreen();
      case 0:
      default:
        return const HomeScreen();
    }
  }

  int _indexOf(NavBarState state) => state is NavBarChanged ? state.currentIndex : 0;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<HomeBloc>(),
      child: Responsive.isDesktop(context) ? _desktopShell() : _phoneShell(),
    );
  }

  /// Phone / narrow layout: the original bottom-bar shell with a floating header.
  Widget _phoneShell() {
    return Scaffold(
      backgroundColor: ZipxUi.bg,
      resizeToAvoidBottomInset: false,
      bottomNavigationBar: const CustomBottomNavbar(),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return const [ZipxHomeHeader()];
        },
        body: BlocBuilder<NavBarBloc, NavBarState>(
          builder: (context, state) => _bodyFor(_indexOf(state)),
        ),
      ),
    );
  }

  /// Desktop / wide layout: a left navigation rail with width-constrained,
  /// centred content so nothing stretches edge-to-edge.
  Widget _desktopShell() {
    return Scaffold(
      backgroundColor: ZipxUi.bg,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ZipxSideNav(),
          Expanded(
            child: SafeArea(
              left: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: Responsive.maxContentWidth),
                  child: BlocBuilder<NavBarBloc, NavBarState>(
                    builder: (context, state) => _bodyFor(_indexOf(state)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
