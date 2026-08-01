import 'package:flutter/material.dart';

import '../focus/tv_focus_builder.dart';

/// A focusable button for the hero banner (Play / More Info). Fills red when
/// focused or when it's the primary action; outlined otherwise.
class TvPrimaryButton extends StatelessWidget {
  const TvPrimaryButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.autofocus = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool primary;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.tertiary;
    return TvFocusBuilder(
      autofocus: autofocus,
      onSelect: onPressed,
      builder: (context, focused) {
        final filled = focused || primary;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: filled ? accent : Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: focused ? Colors.white : Colors.transparent, width: 2),
            boxShadow: focused ? [BoxShadow(color: accent.withOpacity(0.5), blurRadius: 16, spreadRadius: 1)] : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
        );
      },
    );
  }
}
