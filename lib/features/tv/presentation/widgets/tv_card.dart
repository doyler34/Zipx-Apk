import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../../common/styles/zipx_ui.dart';
import '../../../../common/widgets/tv/tv_focusable.dart';
import '../../../../common/widgets/movie/vote_avg_widget.dart';
import '../../../../core/utils/strings/url_strings.dart';
import '../../data/models/tv_model.dart';

class TvCard extends StatelessWidget {
  const TvCard({super.key, required this.show, this.aspectRatio = 10 / 16, this.autofocus = false});

  final TvModel show;
  final double aspectRatio;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      autofocus: autofocus,
      onPressed: () => context.push('/tv/${show.id}', extra: show),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              decoration: BoxDecoration(
                color: ZipxUi.surface,
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
                  if (show.posterPath.trim() == '') const Center(child: FaIcon(FontAwesomeIcons.tv, color: Colors.white24, size: 40)),
                  VoteAvgWidget(voteAvg: show.voteAverage, alignment: Alignment.bottomRight),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
