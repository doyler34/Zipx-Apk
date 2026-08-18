import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../common/blocs/bloc/nav_bar_bloc.dart';
import '../../../../../common/styles/zipx_ui.dart';

/// Top bar for the home shell: the ZIPX wordmark on the left, search + profile
/// on the right. Rendered as a floating [SliverAppBar] so it scrolls away with
/// content. Search jumps to the Search tab, profile to the Profile/Settings
/// tab, both via [NavBarBloc].
class ZipxHomeHeader extends StatelessWidget {
  const ZipxHomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      floating: true,
      snap: true,
      pinned: false,
      backgroundColor: ZipxUi.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 20,
      toolbarHeight: 72,
      title: Image.asset(
        'assets/logos/zipx_logo.png',
        height: 40,
        fit: BoxFit.contain,
        alignment: Alignment.centerLeft,
      ),
      actions: [
        IconButton(
          splashRadius: 22,
          icon: const Icon(Icons.search, color: Colors.white, size: 26),
          onPressed: () => context.read<NavBarBloc>().add(const NavBarTapEvent(1)),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 16, left: 4),
          child: GestureDetector(
            onTap: () => context.read<NavBarBloc>().add(const NavBarTapEvent(5)),
            child: const CircleAvatar(
              radius: 18,
              backgroundColor: ZipxUi.surfaceHigh,
              child: Icon(Icons.person, color: Colors.white70, size: 22),
            ),
          ),
        ),
      ],
    );
  }
}
