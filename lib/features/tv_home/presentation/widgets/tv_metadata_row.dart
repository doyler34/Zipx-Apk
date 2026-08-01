import 'package:flutter/material.dart';

import '../../models/tv_media_item.dart';

/// Compact metadata line for the hero: year • rating • type.
class TvMetadataRow extends StatelessWidget {
  const TvMetadataRow({super.key, required this.item});

  final TvMediaItem item;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (item.year.isNotEmpty) item.year,
      if (item.voteAverage > 0) '★ ${item.voteAverage.toStringAsFixed(1)}',
      item.kind == TvMediaKind.movie ? 'Movie' : 'TV Series',
    ];
    return Row(
      children: [
        for (int i = 0; i < parts.length; i++) ...[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text('•', style: TextStyle(color: Colors.white54)),
            ),
          Text(parts[i], style: const TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w500)),
        ],
      ],
    );
  }
}
