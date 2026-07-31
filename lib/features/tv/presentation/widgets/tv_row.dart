import 'package:flutter/material.dart';

/// A labeled horizontal row of poster cards for the TV home. Scrolls
/// horizontally as the D-pad moves focus along it.
class TvRow extends StatelessWidget {
  const TvRow({super.key, required this.title, required this.cards});

  final String title;
  final List<Widget> cards;

  static const double _posterWidth = 150;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 16, 32, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        SizedBox(
          height: _posterWidth * 3 / 2 + 24,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
            itemCount: cards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (_, index) => cards[index],
          ),
        ),
      ],
    );
  }
}
