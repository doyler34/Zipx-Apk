import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import '../../../../core/playback/domain/entities/playback_media_type.dart';
import '../../../../core/playback/domain/entities/playback_request.dart';
import '../../../movies/presentation/pages/search/search_screen.dart';
import '../../../personalization/presentation/pages/bookmarks/bookmarks_screen.dart';
import '../../../personalization/presentation/pages/settings/settings_screen.dart';
import '../../models/tv_media_item.dart';
import '../../providers/tv_home_providers.dart';
import '../widgets/tv_content_row.dart';
import '../widgets/tv_hero_banner.dart';
import '../widgets/tv_landscape_card.dart';
import '../widgets/tv_navigation_rail.dart';
import '../widgets/tv_poster_card.dart';

/// The full TV experience shell: a collapsed navigation rail on the left and
/// a content area on the right that switches by rail selection. Used only on
/// TV (see the router) - the mobile app keeps NavigationMenu.
class TvShellScreen extends ConsumerStatefulWidget {
  const TvShellScreen({super.key});

  @override
  ConsumerState<TvShellScreen> createState() => _TvShellScreenState();
}

class _TvShellScreenState extends ConsumerState<TvShellScreen> {
  int _selectedIndex = 0;
  bool _railFocused = false;
  final FocusNode _railFirstItem = FocusNode(debugLabel: 'railFirstItem');

  @override
  void dispose() {
    _railFirstItem.dispose();
    super.dispose();
  }

  void _handleBack() {
    // Back from the content moves focus to the rail first; Back while already
    // on the rail exits the app.
    if (_railFocused) {
      SystemNavigator.pop();
    } else {
      _railFirstItem.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Row(
          children: [
            TvNavigationRail(
              selectedIndex: _selectedIndex,
              firstItemFocusNode: _railFirstItem,
              onFocusChange: (focused) => _railFocused = focused,
              onSelect: (index) => setState(() => _selectedIndex = index),
            ),
            Expanded(child: _content()),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    switch (_selectedIndex) {
      case 3:
        return const SearchScreen();
      case 4:
        return const BookmarksScreen();
      case 5:
        return const SettingsScreen();
      case 1:
        return const _TvGridPage(kind: _GridKind.movies);
      case 2:
        return const _TvGridPage(kind: _GridKind.shows);
      case 0:
      default:
        return const _TvHomeBody();
    }
  }
}

// --- Navigation helpers ------------------------------------------------------

void _openItem(BuildContext context, TvMediaItem item) {
  if (item.kind == TvMediaKind.movie && item.movie != null) {
    context.push('/details/${item.id}', extra: item.movie);
  } else if (item.tv != null) {
    context.push('/tv/${item.id}', extra: item.tv);
  }
}

void _playItem(BuildContext context, TvMediaItem item) {
  if (item.kind == TvMediaKind.movie) {
    context.push(
      '/player',
      extra: PlaybackRequest(
        tmdbId: item.id,
        mediaType: PlaybackMediaType.movie,
        title: item.title,
        posterPath: item.posterPath,
      ),
    );
  } else {
    // A show needs an episode chosen first.
    _openItem(context, item);
  }
}

// --- Home body (hero + rows) -------------------------------------------------

class _TvHomeBody extends ConsumerWidget {
  const _TvHomeBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(tvHomeDataProvider);
    return async.when(
      loading: () => Center(child: LoadingAnimationWidget.beat(color: Theme.of(context).colorScheme.tertiary, size: 50)),
      error: (_, __) => const Center(child: Text('Error while fetching data', style: TextStyle(color: Colors.white))),
      data: (data) {
        final size = MediaQuery.of(context).size;
        final heroHeight = (size.height * 0.5).clamp(260.0, 500.0);
        final posterWidth = (size.width / 12).clamp(96.0, 132.0);
        final rowHeight = posterWidth * 3 / 2 + 40;
        final landscapeWidth = posterWidth * 1.7;

        final featured = ref.watch(featuredItemProvider) ?? data.initialFeatured;

        void setFeatured(TvMediaItem item) {
          ref.read(featuredItemProvider.notifier).state = item;
        }

        List<Widget> posters(List<TvMediaItem> items) {
          return [
            for (final item in items)
              TvPosterCard(
                item: item,
                width: posterWidth,
                onFocused: () => setFeatured(item),
                onSelect: () => _openItem(context, item),
              ),
          ];
        }

        return ListView(
          padding: EdgeInsets.zero,
          children: [
            TvHeroBanner(
              item: featured,
              height: heroHeight,
              autofocusPlay: true,
              onPlay: () {
                if (featured != null) _playItem(context, featured);
              },
              onMoreInfo: () {
                if (featured != null) _openItem(context, featured);
              },
            ),
            if (data.continueWatching.isNotEmpty)
              TvContentRow(
                title: 'Continue Watching',
                height: landscapeWidth * 9 / 16 + 44,
                cards: [
                  for (final entry in data.continueWatching)
                    TvLandscapeCard(
                      imagePath: entry.posterPath ?? '',
                      title: entry.title,
                      width: landscapeWidth,
                      subtitle: entry.seasonNumber != null ? 'S${entry.seasonNumber}E${entry.episodeNumber}' : null,
                      onSelect: () => context.push('/player', extra: entry.toPlaybackRequest()),
                    ),
                ],
              ),
            TvContentRow(title: 'Trending', height: rowHeight, cards: posters(data.trending)),
            TvContentRow(title: 'Popular Movies', height: rowHeight, cards: posters(data.popularMovies)),
            TvContentRow(title: 'Popular TV Shows', height: rowHeight, cards: posters(data.popularShows)),
            TvContentRow(title: 'Recently Added', height: rowHeight, cards: posters(data.recentlyAdded)),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }
}

// --- Movies / TV Shows grid --------------------------------------------------

enum _GridKind { movies, shows }

class _TvGridPage extends ConsumerWidget {
  const _TvGridPage({required this.kind});

  final _GridKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(tvHomeDataProvider);
    return async.when(
      loading: () => Center(child: LoadingAnimationWidget.beat(color: Theme.of(context).colorScheme.tertiary, size: 50)),
      error: (_, __) => const Center(child: Text('Error while fetching data', style: TextStyle(color: Colors.white))),
      data: (data) {
        final items = kind == _GridKind.movies ? [...data.popularMovies, ...data.trending, ...data.recentlyAdded] : data.popularShows;
        final width = MediaQuery.of(context).size.width;
        final crossAxisCount = ((width - 72) / 150).floor().clamp(4, 9);
        return Padding(
          padding: const EdgeInsets.fromLTRB(48, 32, 48, 24),
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 2 / 3,
              crossAxisSpacing: 18,
              mainAxisSpacing: 18,
            ),
            itemCount: items.length,
            itemBuilder: (_, index) => TvPosterCard(
              item: items[index],
              autofocus: index == 0,
              onSelect: () => _openItem(context, items[index]),
            ),
          ),
        );
      },
    );
  }
}
