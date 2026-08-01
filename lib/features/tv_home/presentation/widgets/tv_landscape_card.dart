import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/strings/url_strings.dart';
import '../focus/tv_focus_builder.dart';

/// Wider landscape card used for the Continue Watching row. Enlarges on focus
/// and shows a title + subtitle overlay.
class TvLandscapeCard extends StatelessWidget {
  const TvLandscapeCard({
    super.key,
    required this.imagePath,
    required this.title,
    required this.onSelect,
    this.subtitle,
    this.onFocused,
    this.autofocus = false,
    this.width = 260,
  });

  final String imagePath;
  final String title;
  final String? subtitle;
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
          scale: focused ? 1.07 : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: width,
            height: width * 9 / 16,
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
                  if (imagePath.trim().isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: UrlStrings.imageUrl + imagePath,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: Colors.white10),
                      errorWidget: (_, __, ___) => const ColoredBox(color: Colors.white10, child: Icon(Icons.movie, color: Colors.white38)),
                    )
                  else
                    const ColoredBox(color: Colors.white10, child: Icon(Icons.movie, color: Colors.white38)),
                  Container(
                    padding: const EdgeInsets.fromLTRB(10, 24, 10, 8),
                    alignment: Alignment.bottomLeft,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black87],
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        if (subtitle != null && subtitle!.isNotEmpty)
                          Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                      ],
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
