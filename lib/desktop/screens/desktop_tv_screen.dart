import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../common/styles/zipx_ui.dart';
import '../../core/dependency_injection/di.dart';
import '../../core/playback/domain/entities/playback_media_type.dart';
import '../../core/playback/domain/entities/playback_request.dart';
import '../../features/tv/data/models/tv_model.dart';
import '../../features/tv/presentation/blocs/tv_home_cubit.dart';
import '../../features/tv/presentation/widgets/tv_card.dart';
import '../widgets/hover_scale.dart';
import '../widgets/h_scroll_row.dart';
import '../../common/widgets/tv/tv_focusable.dart';
import '../../core/platform/tv.dart';
import '../../common/widgets/tv/tv_focusable.dart';

/// Desktop TV Shows: its own cinematic hero + horizontal rows of shows, wired to
/// [TvHomeCubit]. Same shape as the desktop movie home but populated with TV
/// categories and genre rows, using the shared [TvCard].
class DesktopTvScreen extends StatelessWidget {
  const DesktopTvScreen({super.key});

  static String _backdrop(String path) => 'https://image.tmdb.org/t/p/w1280$path';

  List<TvModel> _clean(List<TvModel> shows) =>
      shows.where((s) => s.posterPath.trim().isNotEmpty && !s.isLikelyUnstreamable).toList();

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<TvHomeCubit>()..loadHome(),
      child: BlocBuilder<TvHomeCubit, TvHomeState>(
        builder: (context, state) {
          if (state.isLoading && state.trending.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: ZipxUi.red));
          }
          if (state.errorMessage != null && state.trending.isEmpty) {
            return Center(child: Text(state.errorMessage!, style: const TextStyle(color: Colors.white70)));
          }
          final trending = _clean(state.trending);
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (trending.isNotEmpty) _TvHero(show: trending.first),
                const SizedBox(height: 12),
                _TvRow(title: 'Trending Now', shows: trending),
                _TvRow(title: 'Popular', shows: _clean(state.popular)),
                _TvRow(title: 'Top Rated', shows: _clean(state.topRated)),
                _TvRow(title: 'On The Air', shows: _clean(state.onTheAir)),
                _TvRow(title: 'Airing Today', shows: _clean(state.airingToday)),
                for (final section in state.genreSections)
                  _TvRow(title: section.$1, shows: _clean(section.$2)),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TvHero extends StatelessWidget {
  const _TvHero({required this.show});

  final TvModel show;

  void _play(BuildContext context) {
    context.push(
      '/player',
      extra: PlaybackRequest(
        tmdbId: show.id,
        mediaType: PlaybackMediaType.tv,
        title: show.name,
        seasonNumber: 1,
        episodeNumber: 1,
        posterPath: show.posterPath,
      ),
    );
  }

  void _moreInfo(BuildContext context) => context.push('/tv/${show.id}', extra: show);

  @override
  Widget build(BuildContext context) {
    final year = show.firstAirDate.length >= 4 ? show.firstAirDate.substring(0, 4) : '';
    return LayoutBuilder(
      builder: (context, c) {
        final height = (c.maxWidth * 0.42).clamp(360.0, 560.0);
        return SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (show.backdropPath.trim().isNotEmpty)
                ExtendedImage.network(DesktopTvScreen._backdrop(show.backdropPath), fit: BoxFit.cover, cache: true, printError: false)
              else
                const ColoredBox(color: ZipxUi.surface),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0xF20A0A0C), Color(0x660A0A0C), Colors.transparent],
                  ),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.center,
                    colors: [ZipxUi.bg, Colors.transparent],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(48, 0, 48, 44),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          show.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w800, height: 1.05),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: ZipxUi.red, size: 20),
                            const SizedBox(width: 4),
                            Text(show.voteAverage.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            if (year.isNotEmpty) ...[
                              const SizedBox(width: 12),
                              Text(year, style: const TextStyle(color: ZipxUi.textMuted)),
                            ],
                          ],
                        ),
                        if (show.overview.trim().isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text(
                            show.overview,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
                          ),
                        ],
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            _HeroButton(icon: Icons.play_arrow_rounded, label: 'Play', filled: true, autofocus: isAndroidTv, onTap: () => _play(context)),
                            const SizedBox(width: 14),
                            _HeroButton(icon: Icons.info_outline_rounded, label: 'More Info', filled: false, onTap: () => _moreInfo(context)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeroButton extends StatelessWidget {
  const _HeroButton({required this.icon, required this.label, required this.filled, required this.onTap, this.autofocus = false});

  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      onPressed: onTap,
      autofocus: autofocus,
      borderRadius: 12,
      focusScale: 1.05,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
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
    );
  }
}

class _TvRow extends StatelessWidget {
  const _TvRow({required this.title, required this.shows});

  final String title;
  final List<TvModel> shows;

  @override
  Widget build(BuildContext context) {
    if (shows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(48, 20, 48, 10),
          child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w700)),
        ),
        HScrollRow(
          height: 360,
          padding: const EdgeInsets.symmetric(horizontal: 44),
          itemCount: shows.length,
          itemBuilder: (context, i) => SizedBox(
            width: 215,
            child: HoverScale(child: TvCard(show: shows[i])),
          ),
        ),
      ],
    );
  }
}
