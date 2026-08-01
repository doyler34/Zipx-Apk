import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dependency_injection/di.dart';
import '../../../core/playback/domain/entities/playback_history_entry.dart';
import '../../../core/playback/services/playback_history_service.dart';
import '../../movies/data/datasources/remote/tmdb_datasource.dart';
import '../../tv/data/datasources/remote/tmdb_tv_datasource.dart';
import '../models/tv_media_item.dart';

/// All data the TV home needs, loaded once in parallel.
class TvHomeData {
  const TvHomeData({
    required this.continueWatching,
    required this.trending,
    required this.popularMovies,
    required this.popularShows,
    required this.recentlyAdded,
  });

  final List<PlaybackHistoryEntry> continueWatching;
  final List<TvMediaItem> trending;
  final List<TvMediaItem> popularMovies;
  final List<TvMediaItem> popularShows;
  final List<TvMediaItem> recentlyAdded;

  /// The item shown in the hero when nothing is focused yet.
  TvMediaItem? get initialFeatured => trending.isNotEmpty ? trending.first : (popularMovies.isNotEmpty ? popularMovies.first : null);
}

/// Loads the TV home rows from the existing TMDB datasources + playback
/// history. Uses the app's GetIt singletons so nothing about the data layer
/// changes.
final tvHomeDataProvider = FutureProvider<TvHomeData>((ref) async {
  final movieDs = sl<TmdbDatasource>();
  final tvDs = sl<TmdbTvDatasource>();

  final results = await Future.wait([
    movieDs.getTrendingMovies(),
    movieDs.getPopularMovies(),
    tvDs.getTrendingTv(),
    movieDs.getNowPlayingMovies(),
  ]);

  final trending = (results[0] as dynamic).movies as List?;
  final popular = (results[1] as dynamic).movies as List?;
  final shows = (results[2] as dynamic).shows as List?;
  final recent = (results[3] as dynamic).movies as List?;

  return TvHomeData(
    continueWatching: sl<PlaybackHistoryService>().getHistory(),
    trending: [for (final m in trending ?? const []) TvMediaItem.fromMovie(m)],
    popularMovies: [for (final m in popular ?? const []) TvMediaItem.fromMovie(m)],
    popularShows: [for (final t in shows ?? const []) TvMediaItem.fromTv(t)],
    recentlyAdded: [for (final m in recent ?? const []) TvMediaItem.fromMovie(m)],
  );
});

/// The currently featured item shown in the hero banner. Updated as the D-pad
/// moves focus across poster cards.
final featuredItemProvider = StateProvider<TvMediaItem?>((ref) => null);
