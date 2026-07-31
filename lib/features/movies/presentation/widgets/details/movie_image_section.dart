import 'package:animate_do/animate_do.dart';
import 'package:blur/blur.dart';
import 'package:flutter/material.dart';
import 'package:movie_bloc_app/common/styles/styles.dart';
import 'package:movie_bloc_app/common/widgets/movie/adult_widget.dart';
import 'package:movie_bloc_app/common/widgets/movie/movie_card.dart';
import 'package:movie_bloc_app/common/widgets/movie/vote_avg_widget.dart';

import 'package:movie_bloc_app/features/movies/data/models/movie_model.dart';

class MovieImageSection extends StatelessWidget {
  const MovieImageSection({super.key, required this.movie});

  final MovieModel movie;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // Capped so the header doesn't fill a whole wide TV screen.
    final headerHeight = (size.height * 0.4).clamp(220.0, 380.0);
    final posterHeight = headerHeight * 0.88;
    return FadeIn(
      child: SizedBox(
        height: headerHeight,
        child: FadeIn(
          child: Stack(
            children: [
              Blur(
                colorOpacity: 0.25,
                blurColor: Colors.black,
                child: Container(
                  width: double.infinity,
                  height: headerHeight,
                  decoration: Styles(context: context, imagePath: movie.backdropPath).cardBoxDecoration,
                ),
              ),
              Center(
                child: SizedBox(
                  height: posterHeight,
                  child: MovieCard(
                    movie: movie,
                    showInfo: false,
                    aspectRatio: 10 / 16,
                    touchable: false,
                  ),
                ),
              ),
              if (movie.adult)
                const AdultWidget(
                  alignment: Alignment.topRight,
                  padding: EdgeInsets.only(right: 20, top: 20),
                  width: 50,
                  height: 50,
                  hasShadow: true,
                ),
              VoteAvgWidget(
                alignment: Alignment.bottomRight,
                voteAvg: movie.voteAverage,
                width: 70,
                height: 70,
                hasShadow: true,
                padding: const EdgeInsets.only(bottom: 20, right: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
