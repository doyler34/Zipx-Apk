import 'package:flutter/material.dart';

import '../../../../common/styles/zipx_ui.dart';
import '../../data/models/tv_season_summary_model.dart';

/// Compact "Season: [ Season 1 ▾ ]" selector for the TV details screen.
/// Built on [PopupMenuButton] rather than [DropdownButton] - it anchors to
/// the button reliably regardless of season count (DropdownButton's popup
/// could misplace/overflow with 7+ seasons), and its `color`/`shape` let the
/// popup look like part of this app instead of a stock Material dropdown.
/// Used on both mobile and desktop.
class SeasonDropdown extends StatelessWidget {
  const SeasonDropdown({
    super.key,
    required this.seasons,
    required this.selectedSeasonNumber,
    required this.onChanged,
  });

  final List<TvSeasonSummaryModel> seasons;
  final int selectedSeasonNumber;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = seasons.firstWhere(
      (s) => s.seasonNumber == selectedSeasonNumber,
      orElse: () => seasons.first,
    );

    return PopupMenuButton<int>(
      onSelected: onChanged,
      tooltip: '',
      padding: EdgeInsets.zero,
      color: ZipxUi.surfaceHigh,
      elevation: 12,
      offset: const Offset(0, 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 260, maxHeight: 320),
      itemBuilder: (context) => [
        for (final season in seasons)
          PopupMenuItem<int>(
            value: season.seasonNumber,
            child: _SeasonMenuRow(label: season.name, selected: season.seasonNumber == selectedSeasonNumber),
          ),
      ],
      child: Container(
        constraints: const BoxConstraints(minWidth: 180, maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: ZipxUi.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                selected.name,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 20),
          ],
        ),
      ),
    );
  }
}

class _SeasonMenuRow extends StatelessWidget {
  const _SeasonMenuRow({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 20,
          child: selected ? const Icon(Icons.check_rounded, color: ZipxUi.red, size: 18) : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : ZipxUi.textMuted,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
