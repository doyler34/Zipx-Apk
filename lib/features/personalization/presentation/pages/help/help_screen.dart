import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../common/styles/zipx_ui.dart';
import '../../../../../core/utils/helpers/helper_functions.dart';

/// Profile -> Help: a short FAQ list plus a "Contact us" mailto button.
/// Same support address the beta "Report Issue" popup already uses.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const String _contactUrl =
      'mailto:garethark@outlook.com?subject=Zipx%20Movies%20Support';

  static const _faqs = [
    (
      'How do I install an update?',
      'Go to Profile -> App Updates and tap "Download Update". The app downloads it and hands it straight to your installer - no browser needed.',
    ),
    (
      '"Install blocked" or nothing happens when I tap install',
      'Android blocks installs from outside the Play Store until you allow it once, per app. Go to Settings -> Apps -> Zipx Movies -> Install unknown apps, and turn on "Allow from this source". You only need to do this once - after that, updates install normally.',
    ),
    (
      'A movie or show says no streams found',
      'Some titles - especially very new or less common ones - don\'t have a working stream yet. Try again later, or try a different episode/title in the meantime.',
    ),
    (
      'How do Downloads work?',
      'Downloads (Profile -> Downloads) are titles prepared on our servers for smoother playback, not files saved to your device. They\'ll show as queued, then ready to play once prepared.',
    ),
    (
      'Is my data tracked?',
      'No. See Profile -> About Us for details on the app\'s privacy approach - no ads, no unnecessary tracking, no selling data.',
    ),
  ];

  Future<void> _contact(BuildContext context) async {
    final uri = Uri.tryParse(_contactUrl);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) HelperFunctions.showSnackBar(context, 'Could not open your email app.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZipxUi.bg,
      appBar: AppBar(
        backgroundColor: ZipxUi.bg,
        foregroundColor: Colors.white,
        title: const Text('Help'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          Text(
            'FAQs',
            style: Theme.of(context).textTheme.titleMedium!.copyWith(
                  color: ZipxUi.red,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
          ),
          const SizedBox(height: 12),
          for (final (question, answer) in _faqs)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: ZipxUi.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  iconColor: ZipxUi.red,
                  collapsedIconColor: Colors.white54,
                  title: Text(
                    question,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(answer, style: const TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.5)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ZipxUi.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Still need help?",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Send us an email and we'll get back to you.",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _contact(context),
                    style: ElevatedButton.styleFrom(backgroundColor: ZipxUi.red),
                    icon: const Icon(Icons.email_outlined, color: Colors.white),
                    label: const Text('Contact Us', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
