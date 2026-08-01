import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';

import '../../styles/zipx_ui.dart';

/// Section header for the home rows: bold white title on the left and, when
/// [onTap] is given, a red "See All ›" affordance on the right.
class Header extends StatelessWidget {
  const Header({super.key, required this.title, this.delay = Duration.zero, this.onTap});

  final String title;
  final Duration delay;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FadeInLeft(
      delay: delay,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            if (onTap != null)
              TextButton(
                onPressed: onTap,
                style: TextButton.styleFrom(foregroundColor: ZipxUi.red),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('See All', style: TextStyle(fontWeight: FontWeight.w600)),
                    SizedBox(width: 2),
                    Icon(Icons.chevron_right, size: 18),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
