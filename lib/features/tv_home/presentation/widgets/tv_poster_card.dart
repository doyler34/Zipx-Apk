import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/strings/url_strings.dart';
import '../../models/tv_media_item.dart';
import '../focus/tv_focus_builder.dart';

/// Portrait poster card for the TV rows. Smoothly enlarges when focused, with
/// an accent border, elevation and a title overlay. Notifies [onFocused] so
/// the hero banner can update to this item.
class TvPosterCard extends StatelessWidget {
  const TvPosterCard({
    super.key,
    required this.item,
    required this.onSelect,
    this.onFocused,
    this.autofocus = false,
    this.width = 150,
  });

  final TvMediaItem item;
  final VoidCallback onSelect;
  final VoidCallback? onFocused;
  final bool autofocus;
  final double width;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.tertiary;
    return TvFocusBuilder(
      autofocus: autofocus,
      onSelect: onSelect,
      onFocusChange: (focused) {
        if (focused) onFocused?.call();
      },
      builder: (context, focused) {
        return AnimatedScale(
          scale: focused ? 1.09 : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: width,
            height: width * 3 / 2,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: focused ? accent : Colors.transparent, width: 3),
              boxShadow: focused
                  ? [BoxShadow(color: accent.withOpacity(0.55), blurRadius: 18, spreadRadius: 1)]
                  : const [BoxShadow(color: Colors.black45, blurRadius: 6)],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (item.posterPath.trim().isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: UrlStrings.imageUrl + item.posterPath,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: Colors.white10),
                      errorWidget: (_, __, ___) => const ColoredBox(color: Colors.white10, child: Icon(Icons.movie, color: Colors.white38)),
                    )
                  else
                    const ColoredBox(color: Colors.white10, child: Icon(Icons.movie, color: Colors.white38)),
                  if (focused)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black87],
                          ),
                        ),
                        child: Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
