import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../common/styles/zipx_ui.dart';
import '../../../../../core/playback/domain/entities/playback_media_type.dart';
import '../../../../../core/playback/domain/entities/playback_request.dart';
import '../../../data/models/movie_model.dart';

/// Entry point into the streaming provider system from the movie details
/// page. Builds a [PlaybackRequest] from TMDB movie data and hands off to
/// the player route - it never touches a provider or a provider URl.
class WatchNowButton extends StatelessWidget {
  const WatchNowButton({super.key, required this.movie});

  final MovieModel movie;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: ZipxUi.red,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () {
            context.push(
              '/player',
              extra: PlaybackRequest(
                tmdbId: movie.id,
                mediaType: PlaybackMediaType.movie,
                title: movie.title,
                posterPath: movie.posterPath,
              ),
            );
          },
          icon: const Icon(Icons.play_arrow, color: Colors.white),
          label: const Text('Watch Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
