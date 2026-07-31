/// The kind of TMDB content a [PlaybackRequest] refers to.
enum PlaybackMediaType {
  movie,
  tv;

  String get tmdbPath => this == PlaybackMediaType.movie ? 'movie' : 'tv';
}
