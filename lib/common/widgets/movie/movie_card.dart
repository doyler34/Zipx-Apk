import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:movie_bloc_app/common/styles/zipx_ui.dart';
import 'package:movie_bloc_app/common/widgets/tv/tv_focusable.dart';
import 'package:movie_bloc_app/common/widgets/movie/adult_widget.dart';
import 'package:movie_bloc_app/common/widgets/movie/mark_widget.dart';
import 'package:movie_bloc_app/common/widgets/movie/vote_avg_widget.dart';
import 'package:movie_bloc_app/core/utils/strings/url_strings.dart';
import 'package:movie_bloc_app/features/movies/data/models/movie_model.dart';
import 'package:movie_bloc_app/features/personalization/presentation/blocs/settings/settings_bloc.dart';

class MovieCard extends StatelessWidget {
  const MovieCard({
    super.key,
    required this.movie,
    this.aspectRatio = 10 / 16,
    this.verticalPadding = 16,
    this.horizontalPadding = 12,
    this.showInfo = true,
    this.touchable = true,
    this.isHomePage = false,
  });

  final MovieModel movie;
  final double aspectRatio;
  final double verticalPadding;
  final double horizontalPadding;
  final bool showInfo;
  final bool touchable;
  final bool isHomePage;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        if (state is SettingsChanged) {
          final card = Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  decoration: BoxDecoration(
                    color: ZipxUi.surface,
                    image: movie.posterPath.trim() != ''
                        ? DecorationImage(
                            image: ExtendedNetworkImageProvider(UrlStrings.imageUrl + movie.posterPath, cache: true, printError: false),
                            fit: BoxFit.cover,
                            onError: (_, __) {},
                          )
                        : null,
                  ),
                  child: Stack(
                    children: [
                      if (movie.posterPath.trim() == '')
                        const Center(
                          child: FaIcon(FontAwesomeIcons.film, color: Colors.white24, size: 40),
                        ),
                      if (showInfo) MarkWidget(movie: movie),
                      if (showInfo) VoteAvgWidget(voteAvg: movie.voteAverage, alignment: Alignment.bottomRight),
                      if (movie.adult && showInfo) const AdultWidget(),
                    ],
                  ),
                ),
              ),
            ),
          );

          // Only make it a focusable/tappable target when it actually
          // navigates. A non-touchable card (e.g. the poster on the details
          // header) stays a plain image so it isn't a dead D-pad stop.
          if (!touchable) return card;

          return TvFocusable(
            onPressed: () {
              if (isHomePage) {
                context.push('/details/${movie.id}', extra: movie);
              } else {
                context.pushReplacement('/details/${movie.id}', extra: movie);
              }
            },
            child: card,
          );
        } else {
          return const SizedBox.shrink();
        }
      },
    );
  }
}
