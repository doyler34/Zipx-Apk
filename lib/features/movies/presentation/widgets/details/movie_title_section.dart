import 'package:animate_do/animate_do.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';

import '../../../../../common/styles/styles.dart';

class MovieTitleSection extends StatelessWidget {
  const MovieTitleSection({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return FadeIn(
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 16, left: 16, right: 16),
        child: Container(
          width: double.infinity,
          decoration: Styles(context: context).cardBoxDecoration.copyWith(
                color: Theme.of(context).colorScheme.primary.withOpacity(1),
              ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: AutoSizeText(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge!.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}
