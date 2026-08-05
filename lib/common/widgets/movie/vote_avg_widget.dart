import 'package:flutter/material.dart';

/// Compact rating chip: a small translucent pill with an amber star and the
/// vote average. Sized to sit unobtrusively in a poster corner rather than the
/// old bright-yellow box. [width]/[height]/[hasShadow] are retained for call
/// -site compatibility but no longer drive a fixed box.
class VoteAvgWidget extends StatelessWidget {
  const VoteAvgWidget({
    super.key,
    this.width = 45,
    this.height = 45,
    this.hasShadow = false,
    this.alignment = Alignment.topRight,
    this.padding,
    required this.voteAvg,
  });

  final double width;
  final double height;
  final bool hasShadow;
  final Alignment alignment;
  final EdgeInsetsGeometry? padding;
  final double voteAvg;

  @override
  Widget build(BuildContext context) {
    // An unrated title (vote average 0) shouldn't show a meaningless "0.0"
    // badge - hide the chip entirely in that case.
    if (voteAvg <= 0) return const SizedBox.shrink();
    final rating = voteAvg >= 10 ? '10' : voteAvg.toStringAsFixed(1);
    return Align(
      alignment: alignment,
      child: Padding(
        padding: padding ?? const EdgeInsets.all(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white24, width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star_rounded, color: Color(0xFFFFC529), size: 13),
              const SizedBox(width: 3),
              Text(
                rating,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
