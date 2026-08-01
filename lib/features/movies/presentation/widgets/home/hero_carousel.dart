import 'package:auto_size_text/auto_size_text.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../common/styles/zipx_ui.dart';
import '../../../../../core/playback/domain/entities/playback_media_type.dart';
import '../../../../../core/playback/domain/entities/playback_request.dart';
import '../../../../../core/utils/strings/url_strings.dart';
import '../../../data/models/movie_model.dart';

/// The home "hero" coverflow: a peeking carousel of featured posters with the
/// centred title/rating overlaid, page dots, and Play / More Info buttons that
/// act on whichever card is centred.
class HeroCarousel extends StatefulWidget {
  const HeroCarousel({super.key, required this.movies});

  final List<MovieModel> movies;

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    final movies = widget.movies;
    if (movies.isEmpty) return const SizedBox.shrink();
    final activeIndex = _current.clamp(0, movies.length - 1);
    final active = movies[activeIndex];

    return Column(
      children: [
        const SizedBox(height: 8),
        CarouselSlider.builder(
          itemCount: movies.length,
          options: CarouselOptions(
            height: 430,
            viewportFraction: 0.66,
            enlargeCenterPage: true,
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 6),
            autoPlayCurve: Curves.easeOutCubic,
            onPageChanged: (index, _) => setState(() => _current = index),
          ),
          itemBuilder: (context, index, realIndex) {
            return _HeroCard(movie: movies[index], highlighted: index == activeIndex);
          },
        ),
        const SizedBox(height: 16),
        _Dots(count: movies.length, active: activeIndex),
        const SizedBox(height: 20),
        _HeroButtons(movie: active),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.movie, required this.highlighted});

  final MovieModel movie;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final poster = movie.posterPath.trim();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlighted ? ZipxUi.red : Colors.white12,
          width: highlighted ? 2 : 1,
        ),
        boxShadow: highlighted ? [BoxShadow(color: ZipxUi.red.withOpacity(0.35), blurRadius: 26, spreadRadius: 1)] : const [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (poster.isNotEmpty) ExtendedImage.network(UrlStrings.imageUrl + poster, fit: BoxFit.cover, cache: true) else Container(color: ZipxUi.surface),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xE6000000)],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AutoSizeText(
                      movie.title.toUpperCase(),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      minFontSize: 12,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 3,
                        shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _MetaRow(movie: movie),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.movie});

  final MovieModel movie;

  @override
  Widget build(BuildContext context) {
    final year = movie.releaseDate.length >= 4 ? movie.releaseDate.substring(0, 4) : '';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.star, color: ZipxUi.red, size: 15),
        const SizedBox(width: 4),
        Text(
          movie.voteAverage.toStringAsFixed(1),
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        if (year.isNotEmpty) ...[
          const _MetaDot(),
          Text(year, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ],
    );
  }
}

class _MetaDot extends StatelessWidget {
  const _MetaDot();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Text('•', style: TextStyle(color: Colors.white38, fontSize: 13)),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    // Cap the visible dots so a long trending list doesn't overflow.
    final shown = count > 6 ? 6 : count;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(shown, (i) {
        final isActive = i == (active % shown);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive ? ZipxUi.red : Colors.white24,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

class _HeroButtons extends StatelessWidget {
  const _HeroButtons({required this.movie});

  final MovieModel movie;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ZipxUi.red,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => context.push(
                  '/player',
                  extra: PlaybackRequest(
                    tmdbId: movie.id,
                    mediaType: PlaybackMediaType.movie,
                    title: movie.title,
                    posterPath: movie.posterPath,
                  ),
                ),
                icon: const Icon(Icons.play_arrow, size: 26),
                label: const Text('Play', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ZipxUi.surfaceHigh,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => context.push('/details/${movie.id}', extra: movie),
                icon: const Icon(Icons.info_outline, size: 22),
                label: const Text('More Info', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
