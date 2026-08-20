import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../common/styles/zipx_ui.dart';

/// Profile entry that opens the About Us screen. Styled to match the other
/// settings tiles (DownloadsTile).
class AboutTile extends StatelessWidget {
  const AboutTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: ZipxUi.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => context.push('/about'),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.white),
                const SizedBox(width: 14),
                Expanded(
                  child: Text('About Us',
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
