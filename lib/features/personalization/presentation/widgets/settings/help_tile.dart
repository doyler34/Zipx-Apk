import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../common/styles/zipx_ui.dart';

/// Profile entry that opens the Help (FAQ + Contact) screen. Styled to match
/// the other settings tiles (DownloadsTile, AboutTile).
class HelpTile extends StatelessWidget {
  const HelpTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: ZipxUi.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => context.push('/help'),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(
              children: [
                const Icon(Icons.help_outline_rounded, color: Colors.white),
                const SizedBox(width: 14),
                Expanded(
                  child: Text('Help',
                      style: Theme.of(context).textTheme.titleSmall!.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          )),
                ),
                const Icon(Icons.chevron_right, color: Colors.white38),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
