import 'package:flutter/material.dart';

/// A labeled horizontal row of cards. Wrapped in its own FocusTraversalgroup
/// so left/right moves along the row; up/down crosses to other rows. The
/// framework's directional traversal auto-scrolls the list to keep the
/// focused card visible (via Scrollable.ensureVisible), so no manual scroll
/// handling is needed.
class TvContentRow extends StatelessWidget {
  const TvContentRow({
    super.key,
    required this.title,
    required this.cards,
    required this.height,
  });

  final String title;
  final List<Widget> cards;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();
    return FocusTraversalGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 20, 48, 10),
            child: Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            height: height,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 12),
              itemCount: cards.length,
              clipBehavior: Clip.none,
              separatorBuilder: (_, __) => const SizedBox(width: 18),
              itemBuilder: (_, index) => cards[index],
            ),
          ),
        ],
      ),
    );
  }
}
