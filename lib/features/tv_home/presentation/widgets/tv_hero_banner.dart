import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/strings/url_strings.dart';
import '../../models/tv_media_item.dart';
import 'tv_metadata_row.dart';
import 'tv_primary_button.dart';

/// Large cinematic hero at the top of the TV home. Shows the [item]'s backdrop
/// with dark horizontal + vertical gradients so the title/description stay
/// readable, plus Play and More Info actions.
class TvHeroBanner extends StatelessWidget {
  const TvHeroBanner({
    super.key,
    required this.item,
    required this.height,
    required this.onPlay,
    required this.onMoreInfo,
    this.autofocusPlay = false,
  });

  final TvMediaItem? item;
  final double height;
  final VoidCallback onPlay;
  final VoidCallback onMoreInfo;
  final bool autofocusPlay;

  @override
  Widget build(BuildContext context) {
    final data = item;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (data != null && data.backdropPath.trim().isNotEmpty)
            CachedNetworkImage(
              imageUrl: UrlStrings.imageUrl + data.backdropPath,
              fit: BoxFit.cover,
              placeholder: (_, __) => const ColoredBox(color: Colors.black),
              errorWidget: (_, __, ___) => const ColoredBox(color: Colors.black),
            )
          else
            const ColoredBox(color: Colors.black),

          // Vertical gradient: blends the bottom into the rows below.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black54, Colors.black],
                stops: [0.4, 0.8, 1.0],
              ),
            ),
          ),
          // Horizontal gradient: darkens the left so the text is readable.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Colors.black, Colors.transparent],
                stops: [0.05, 0.75],
              ),
            ),
          ),

          if (data != null)
            Positioned(
              left: 48,
              right: 48,
              bottom: 28,
              child: FractionallySizedBox(
                widthFactor: 0.55,
                alignment: Alignment.centerLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold, height: 1.05),
                    ),
                    const SizedBox(height: 12),
                    TvMetadataRow(item: data),
                    if (data.overview.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        data.overview,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        TvPrimaryButton(icon: Icons.play_arrow, label: 'Play', primary: true, autofocus: autofocusPlay, onPressed: onPlay),
                        const SizedBox(width: 16),
                        TvPrimaryButton(icon: Icons.info_outline, label: 'More Info', onPressed: onMoreInfo),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
