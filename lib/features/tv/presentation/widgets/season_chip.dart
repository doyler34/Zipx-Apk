import 'package:flutter/material.dart';

import '../../../../common/styles/zipx_ui.dart';
import '../../../../common/widgets/tv/tv_focusable.dart';

/// One season pill in the season selector's horizontal scroll row (used on
/// both mobile and desktop TV details). A plain horizontal scroller instead
/// of a dropdown copes with any season count - a 10+ season show just
/// scrolls sideways instead of opening a menu that has to cram that many
/// items into a popup.
class SeasonChip extends StatelessWidget {
  const SeasonChip({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      onPressed: onTap,
      borderRadius: 10,
      focusScale: 1.06,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? ZipxUi.red : ZipxUi.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(color: selected ? Colors.white : ZipxUi.textMuted, fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
    );
  }
}
