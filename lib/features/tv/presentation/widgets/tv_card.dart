import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../../common/styles/styles.dart';
import '../../../../common/widgets/movie/vote_avg_widget.dart';
import '../../../../core/utils/strings/url_strings.dart';
import '../../data/models/tv_model.dart';

class TvCard extends StatelessWidget {
  const TvCard({super.key, required this.show, this.aspectRatio = 10 / 16});

  final TvModel show;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return GestureDetector(
      onTap: () => context.push('/tv/${show.id}', extra: show),
      child: Padding(
        padding: const EdgeInsets.only(top: 16, left: 12, right: 12, bottom: 16),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: Container(
            height: size.height * 0.4,
            decoration: Styles(context: context).cardBoxDecoration.copyWith(
                  image: show.posterPath.trim() != ''
                      ? DecorationImage(
                          image: ExtendedNetworkImageProvider(UrlStrings.imageUrl + show.posterPath, cache: true, printError: false),
                          fit: BoxFit.cover,
                          onError: (_, __) {},
                        )
                      : null,
                ),
            child: Stack(
              children: [
                if (show.posterPath.trim() == '')
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: FaIcon(FontAwesomeIcons.tv, color: Colors.white),
                    ),
                  ),
                VoteAvgWidget(voteAvg: show.voteAverage, alignment: Alignment.bottomRight),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
