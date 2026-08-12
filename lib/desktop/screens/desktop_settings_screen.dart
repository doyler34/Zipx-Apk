import 'package:flutter/material.dart';

import '../../common/styles/zipx_ui.dart';
import '../../features/personalization/presentation/widgets/settings/settings_list.dart';

/// Desktop Profile/Settings: a pinned profile header over the shared settings
/// tiles, centered and width-constrained so the controls don't stretch across a
/// wide monitor. Reuses [SettingsList] for the actual settings.
class DesktopSettingsScreen extends StatelessWidget {
  const DesktopSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      left: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 28, 24, 20),
                child: _ProfileHeader(),
              ),
              const Expanded(child: SettingsList()),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: ZipxUi.surfaceHigh),
          child: const Icon(Icons.person, color: Colors.white70, size: 34),
        ),
        const SizedBox(width: 18),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text('Profile', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
            SizedBox(height: 4),
            Text('Manage your ZipX preferences', style: TextStyle(color: ZipxUi.textMuted, fontSize: 14)),
          ],
        ),
      ],
    );
  }
}
