import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../common/widgets/appbars_navbars/custom_appbar.dart';
import '../../../../common/widgets/texts/header.dart';
import '../../../../common/widgets/youtube_player/trailer_preview.dart';
import '../../../../core/dependency_injection/di.dart';
import '../../../../core/playback/domain/entities/favourite_entry.dart';
import '../../../../core/playback/domain/entities/playback_media_type.dart';
import '../../../../core/playback/domain/entities/playback_request.dart';
import '../../../../core/playback/services/favourite_service.dart';
import '../../../../core/utils/strings/url_strings.dart';
import '../../data/models/tv_model.dart';
import '../blocs/tv_details_cubit.dart';
import '../widgets/episode_tile.dart';
import '../widgets/season_chip.dart';

class TvDetailsScreen extends StatelessWidget {
  const TvDetailsScreen({super.key, required this.show});

  final TvModel show;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<TvDetailsCubit>()..loadDetails(show.id),
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              CustomAppBar(
                hasBackButton: true,
                title: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Text(show.name)),
                actions: [_BookmarkToggle(show: show)],
              ),
            ];
          },
          body: _TvDetailsBody(show: show),
        ),
      ),
    );
  }
}

class _BookmarkToggle extends StatefulWidget {
  const _BookmarkToggle({required this.show});

  final TvModel show;

  @override
  State<_BookmarkToggle> createState() => _BookmarkToggleState();
}

class _BookmarkToggleState extends State<_BookmarkToggle> {
  // No explicit "opened from Anime" flag is threaded through navigation, so
  // this reuses the same Animation-genre signal that keeps anime out of TV
  // Home's rows - it's already present on the real TMDB-sourced show.
  bool get _isAnime => widget.show.isAnimation;

  late bool _isBookmarked = sl<FavouriteService>().isFavourite(PlaybackMediaType.tv, widget.show.id, isAnime: _isAnime);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: IconButton(
        icon: Icon(_isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            color: _isBookmarked ? const Color(0xFFE11D2A) : Colors.white),
        onPressed: () async {
          await sl<FavouriteService>().toggleFavourite(
            FavouriteEntry(
              tmdbId: widget.show.id,
              mediaType: PlaybackMediaType.tv,
              title: widget.show.name,
              posterPath: widget.show.posterPath,
              isAnime: _isAnime,
            ),
          );
          setState(() => _isBookmarked = !_isBookmarked);
        },
      ),
    );
  }
}

class _TvDetailsBody extends StatelessWidget {
  const _TvDetailsBody({required this.show});

  final TvModel show;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TvDetailsCubit, TvDetailsState>(
      builder: (context, state) {
        if (state.isLoadingDetails) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.errorMessage != null && state.details == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(state.errorMessage!, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => context.read<TvDetailsCubit>().loadDetails(show.id),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        final details = state.details;
        final hasSeasons = details != null && details.seasons.isNotEmpty;
        final selectedSeason = hasSeasons ? (state.selectedSeason ?? details.seasons.first.seasonNumber) : null;

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (show.backdropPath.trim().isNotEmpty)
                    SizedBox(
                      // Capped so the backdrop doesn't fill a whole wide TV screen.
                      height: (MediaQuery.of(context).size.height * 0.45).clamp(180.0, 340.0),
                      width: double.infinity,
                      child: ExtendedImage.network(UrlStrings.imageUrl + show.backdropPath, fit: BoxFit.cover, cache: true),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(show.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white)),
                        const SizedBox(height: 8),
                        if (show.overview.trim().isNotEmpty) Text(show.overview, style: const TextStyle(color: Colors.white70)),
                        if (details != null && details.genres.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(details.genres.join(', '), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        ],
                      ],
                    ),
                  ),
                  if (details != null && details.trailerKey.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Header(title: 'Trailer'),
                    const SizedBox(height: 8),
                    TrailerPreview(videoId: details.trailerKey),
                    const SizedBox(height: 8),
                  ],
                  if (hasSeasons) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Text('Season', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    // Horizontal scroll instead of a dropdown: a show with a
                    // dozen+ seasons just scrolls sideways instead of a menu
                    // trying to cram every season into a popup.
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          for (final season in details.seasons)
                            Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: SeasonChip(
                                label: season.name,
                                selected: season.seasonNumber == selectedSeason,
                                onTap: () => context.read<TvDetailsCubit>().loadSeason(show.id, season.seasonNumber),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (state.isLoadingEpisodes)
                      const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
                    else if (state.errorMessage != null && state.episodes.isEmpty)
                      // A failed episode fetch (network hiccup, timeout) used to
                      // render nothing here - identical to a season that genuinely
                      // has no episodes, so a transient failure looked like "this
                      // show has no episodes" with no way to tell the two apart or
                      // retry without leaving the page.
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                        child: Column(
                          children: [
                            Text(state.errorMessage!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () => context.read<TvDetailsCubit>().loadSeason(show.id, selectedSeason!),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    else if (state.episodes.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                        child: Center(
                          child: Text('No episodes found for this season.', style: TextStyle(color: Colors.white54)),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            // A real sliver list instead of unrolling every episode into the
            // Column above: a long season (20+ episodes, each with its own
            // thumbnail) used to build and paint every tile at once - this
            // only builds the ones actually near the viewport.
            if (hasSeasons && !state.isLoadingEpisodes && state.episodes.isNotEmpty)
              SliverList.builder(
                itemCount: state.episodes.length,
                itemBuilder: (context, index) {
                  final episode = state.episodes[index];
                  return EpisodeTile(
                    episode: episode,
                    onPlay: () {
                      context.push(
                        '/player',
                        extra: PlaybackRequest(
                          tmdbId: show.id,
                          mediaType: PlaybackMediaType.tv,
                          title: '${show.name} - S${episode.seasonNumber}E${episode.episodeNumber}',
                          seasonNumber: episode.seasonNumber,
                          episodeNumber: episode.episodeNumber,
                          posterPath: show.posterPath,
                        ),
                      );
                    },
                  );
                },
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        );
      },
    );
  }
}
