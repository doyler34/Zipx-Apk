import 'package:flutter/material.dart';

import '../../../../../common/styles/zipx_ui.dart';

/// Profile → About Us: static copy about ZipX's privacy stance. No state,
/// no network calls - just a scrollable page matching the other Profile
/// sub-screens (Downloads).
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZipxUi.bg,
      appBar: AppBar(
        backgroundColor: ZipxUi.bg,
        foregroundColor: Colors.white,
        title: const Text('About Us'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ABOUT ZIPX',
              style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    color: ZipxUi.red,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
            ),
            const SizedBox(height: 16),
            _paragraph(
              "ZipxMovies is built around a simple idea: the internet doesn't need to know everything about you.",
            ),
            _paragraph(
              'We built the platform to keep things simple, private and accessible. No intrusive advertising. No unnecessary tracking. No selling user data.',
            ),
            _paragraph(
              'The infrastructure is distributed across multiple servers and layers, with traffic filtering, tracker blocking and security measures built into the system.',
            ),
            _paragraph(
              "We don't need to know who you are to provide the service.",
            ),
            _paragraph(
              'Less tracking. Less noise. More control.',
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: ZipxUi.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: const [
                  _StatusLine(label: 'SYSTEM STATUS', value: 'ONLINE'),
                  SizedBox(height: 8),
                  _StatusLine(label: 'TRACKING', value: 'BLOCKED'),
                  SizedBox(height: 8),
                  _StatusLine(label: 'UNWANTED TRAFFIC', value: 'FILTERED'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paragraph(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white70, fontSize: 14.5, height: 1.5),
        ),
      );
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.circle, color: Colors.greenAccent, size: 8),
        const SizedBox(width: 10),
        Text(
          '$label:',
          style: const TextStyle(
            color: Colors.white70,
            fontFamily: 'monospace',
            fontSize: 13,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.greenAccent,
            fontFamily: 'monospace',
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
