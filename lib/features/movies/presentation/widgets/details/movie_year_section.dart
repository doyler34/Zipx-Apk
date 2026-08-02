import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:movie_bloc_app/common/styles/styles.dart';
import 'package:movie_bloc_app/common/widgets/texts/header.dart';
import 'package:movie_bloc_app/core/utils/extensions/string_extensions.dart';

class MovieYearSection extends StatelessWidget {
  const MovieYearSection({
    super.key,
    required this.year,
    required this.budget,
    required this.language,
    required this.runtime,
  });

  final String year;
  final int budget;
  final String language;
  final int runtime;

  static const double _boxHeight = 58;

  Widget _detailBox(BuildContext context, String text) {
    return Container(
      height: _boxHeight,
      decoration: Styles(context: context).cardBoxDecoration,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: AutoSizeText(
            text,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: Theme.of(context).textTheme.titleSmall!.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Header(title: 'Movie Details'),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Column(
            children: [
              Row(
                children: [
                  if (year != '') Expanded(child: _detailBox(context, 'Release Date: ${year.displayDate()}')),
                  if (runtime != -1 && year != "") const SizedBox(width: 16),
                  if (runtime != -1) Expanded(child: _detailBox(context, 'Runtime: $runtime mins')),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (budget != -1) Expanded(child: _detailBox(context, 'Budget: \$${budget.toString().changeToMilion()}')),
                  if (budget != -1 && language != "UNKNOWN") const SizedBox(width: 16),
                  if (language != "UNKNOWN") Expanded(child: _detailBox(context, 'Original language: ${language.toUpperCase()}')),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
