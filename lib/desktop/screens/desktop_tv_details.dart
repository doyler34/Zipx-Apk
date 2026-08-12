import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../common/styles/zipx_ui.dart';
import '../../core/dependency_injection/di.dart';
import '../../core/playback/domain/entities/favourite_entry.dart';
import '../../core/playback/domain/entities/playback_media_type.dart';
import '../../core/playback/domain/entities/playback_request.dart';
import '../../core/playback/services/favourite_service.dart';
import '../../core/utils/strings/url_strings.dart';
import '../../features/tv/data/models/tv_model.dart';
import '../../features/tv/presentation/blocs/tv_details_cubit.dart';
import '../../features/tv/presentation/widgets/episode_tile.dart';
import '../../common/widgets/youtube_player/trailer_preview.dart';

/// Desktop TV details: a cinematic backdrop banner, the poster beside
/// title/meta/overview and actions, then the trailer and a season selector with
/// its episode list. Wired to [TvDetailsCubit], reusing [EpisodeTile].
class DesktopTvDetails extends StatelessWidget {
  const DesktopTvDetails({super.key, required this.show});

  final TvModel show;

  static String _backdrop(String path) => 'https://image.tmdb.org/t/p/w1280$path';
  static const double _pad = 48;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<TvDetailsCubit>()..loadDetails(show.id),
      child: Scaffold(
        backgroundColor: ZipxUi.bg,
        body: BlocBuilder<TvDetailsCubit, TvDetailsState>(
          builder: (context, state) {
            final details = state.details;
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _banner(context),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(_pad, 0, _pad, 8),
                    child: _info(context, genres: details?.genres ?? const <String>[]),
                  ),
                  if (details != null && details.trailerKey.isNotEmpty) _Trailer(videoId: details.trailerKey),
                  if (state.isLoadingDetails)
                    const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: ZipxUi.red)))
                  else if (details != null && details.seasons.isNotEmpty)
                    _Seasons(show: show, state: state),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _banner(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final height = (c.maxWidth * 0.38).clamp(320.0, 480.0);
        return SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (show.backdropPath.trim().isNotEmpty)
                ExtendedImage.network(_backdrop(show.backdropPath), fit: BoxFit.cover, cache: true, printError: false)
              else
                const ColoredBox(color: ZipxUi.surface),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [ZipxUi.bg, Colors.transparent, Color(0x330A0A0C)],
                  ),
                ),
              ),
              Positioned(
                top: 16,
                left: 16,
                child: _CircleButton(icon: Icons.arrow_back, onTap: () => context.pop()),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _info(BuildContext context, {required List<String> genres}) {
    final year = show.firstAirDate.length >= 4 ? show.firstAirDate.substring(0, 4) : '';
    final meta = <String>[
      if (year.isNotEmpty) year,
      ...genres.take(3),
    ];
    return Transform.translate(
      offset: const Offset(0, -64),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 200,
              height: 300,
              child: show.posterPath.trim().isEmpty
                  ? const ColoredBox(color: ZipxUi.surface, child: Icon(Icons.tv, color: Colors.white24))
                  : ExtendedImage.network(UrlStrings.imageUrl + show.posterPath, fit: BoxFit.cover, cache: true, printError: false),
            ),
          ),
          const SizedBox(width: 28),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 84),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(show.name,
                      style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800, height: 1.1)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (show.voteAverage > 0) ...[
                        const Icon(Icons.star_rounded, color: ZipxUi.red, size: 20),
                        const SizedBox(width: 4),
                        Text(show.voteAverage.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 12),
                      ],
                      if (meta.isNotEmpty)
                        Flexible(
                          child: Text(meta.join('  ·  '),
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ZipxUi.textMuted)),
                        ),
                    ],
                  ),
                  if (show.overview.trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Text(show.overview, style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.5)),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      _ActionButton(
                        icon: Icons.play_arrow_rounded,
                        label: 'Play S1 · E1',
                        filled: true,
                        onTap: () => context.push(
                          '/player',
                          extra: PlaybackRequest(
                            tmdbId: show.id,
                            mediaType: PlaybackMediaType.tv,
                            title: '${show.name} - S1E1',
                            seasonNumber: 1,
                            episodeNumber: 1,
                            posterPath: show.posterPath,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      _BookmarkToggle(show: show),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Seasons extends StatelessWidget {
  const _Seasons({required this.show, required this.state});

  final TvModel show;
  final TvDetailsState state;

  @override
  Widget build(BuildContext context) {
    final details = state.details!;
    final selected = state.selectedSeason ?? details.seasons.first.seasonNumber;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(DesktopTvDetails._pad, 26, DesktopTvDetails._pad, 12),
          child: Text('Episodes', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w700)),
        ),
        // Season chips.
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: DesktopTvDetails._pad),
            children: [
              for (final season in details.seasons)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: _SeasonChip(
                    label: season.name,
                    selected: season.seasonNumber == selected,
                    onTap: () => context.read<TvDetailsCubit>().loadSeason(show.id, season.seasonNumber),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (state.isLoadingEpisodes)
          const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator(color: ZipxUi.red)))
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DesktopTvDetails._pad - 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                children: [
                  for (final episode in state.episodes)
                    EpisodeTile(
                      episode: episode,
                      onPlay: () => context.push(
                        '/player',
                        extra: PlaybackRequest(
                          tmdbId: show.id,
                          mediaType: PlaybackMediaType.tv,
                          title: '${show.name} - S${episode.seasonNumber}E${episode.episodeNumber}',
                          seasonNumber: episode.seasonNumber,
                          episodeNumber: episode.episodeNumber,
                          posterPath: show.posterPath,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SeasonChip extends StatelessWidget {
  const _SeasonChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? ZipxUi.red : ZipxUi.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label,
              style: TextStyle(
                  color: selected ? Colors.white : ZipxUi.textMuted,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
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
  late bool _isBookmarked = sl<FavouriteService>().isFavourite(PlaybackMediaType.tv, widget.show.id);

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () async {
          await sl<FavouriteService>().toggleFavourite(
            FavouriteEntry(
              tmdbId: widget.show.id,
              mediaType: PlaybackMediaType.tv,
              title: widget.show.name,
              posterPath: widget.show.posterPath,
            ),
          );
          setState(() => _isBookmarked = !_isBookmarked);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            children: [
              Icon(_isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  color: _isBookmarked ? ZipxUi.red : Colors.white, size: 22),
              const SizedBox(width: 8),
              Text(_isBookmarked ? 'Saved' : 'Watchlist',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Trailer extends StatelessWidget {
  const _Trailer({required this.videoId});

  final String videoId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(DesktopTvDetails._pad, 26, DesktopTvDetails._pad, 12),
          child: Text('Trailer', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w700)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DesktopTvDetails._pad),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ClipRRect(borderRadius: BorderRadius.circular(12), child: TrailerPreview(videoId: videoId)),
          ),
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x99000000)),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.filled, required this.onTap});

  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
          decoration: BoxDecoration(
            color: filled ? ZipxUi.red : Colors.white10,
            borderRadius: BorderRadius.circular(12),
            border: filled ? null : Border.all(color: Colors.white24),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }
}
