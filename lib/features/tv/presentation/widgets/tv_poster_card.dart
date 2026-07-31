import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../common/styles/styles.dart';
import '../../../../common/widgets/movie/vote_avg_widget.dart';
import '../../../../common/widgets/tv/tv_focusable.dart';
import '../../../../core/utils/strings/url_strings.dart';

/// A fixed-size, D-pad focusable poster used to build the TV home rows.
/// Sized for a 10-foot screen (not a fraction of screen height), so posters
/// stay a sensible size on any TV.
class TvPosterCard extends StatelessWidget {
  const TvPosterCard({
    super.key,
    required this.posterPath,
    required this.onPressed,
    this.voteAverage,
    this.autofocus = false,
    this.width = 150,
  });

  final String posterPath;
  final VoidCallback onPressed;
  final double? voteAverage;
  final bool autofocus;
  final double width;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      autofocus: autofocus,
      borderRadius: 10,
      onPressed: onPressed,
      child: SizedBox(
        width: width,
        height: width * 3 / 2,
        child: Container(
          decoration: Styles(context: context).cardBoxDecoration.copyWith(
                image: posterPath.trim().isNotEmpty
                    ? DecorationImage(
                        image: ExtendedNetworkImageProvider(UrlStrings.imageUrl + posterPath, cache: true, printError: false),
                        fit: BoxFit.cover,
                        onError: (_, __) {},
                      )
                    : null,
              ),
          child: Stack(
            children: [
              if (posterPath.trim().isEmpty)
                const Center(child: FaIcon(FontAwesomeIcons.film, color: Colors.white54)),
              if (voteAverage != null && voteAverage! > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: VoteAvgWidget(voteAvg: voteAverage!, width: 34, height: 34),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
