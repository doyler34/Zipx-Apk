import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../styles/zipx_ui.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget title;
  final bool hasBackButton;
  final List<Widget> actions;

  const CustomAppBar({super.key, required this.title, required this.hasBackButton, required this.actions});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: hasBackButton,
      floating: !hasBackButton,
      snap: !hasBackButton,
      title: title,
      centerTitle: true,
      backgroundColor: ZipxUi.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      leading: hasBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
              onPressed: () => context.pop(),
            )
          : null,
      titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
      actions: actions,
    );
  }
}
