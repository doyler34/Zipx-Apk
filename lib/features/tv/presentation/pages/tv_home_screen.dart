import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../common/styles/zipx_ui.dart';
import '../../../../core/dependency_injection/di.dart';
import '../../../movies/data/models/genre_model.dart';
import '../../data/models/tv_model.dart';
import '../blocs/tv_home_cubit.dart';
import '../widgets/tv_card.dart';
import '../widgets/tv_row.dart';

class TvHomeScreen extends StatelessWidget {
  const TvHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<TvHomeCubit>()..loadHome(),
      child: const _TvHomeView(),
    );
  }
}

class _TvHomeView extends StatefulWidget {
  const _TvHomeView();

  @override
  State<_TvHomeView> createState() => _TvHomeViewState();
}

class _TvHomeViewState extends State<_TvHomeView> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              cursorColor: ZipxUi.red,
              onChanged: (value) => context.read<TvHomeCubit>().search(value),
              decoration: InputDecoration(
                hintText: 'Search TV shows...',
                hintStyle: const TextStyle(color: ZipxUi.textMuted),
                filled: true,
                fillColor: ZipxUi.surface,
                prefixIcon: const Icon(Icons.search, color: ZipxUi.textMuted),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: ZipxUi.red, width: 1.2)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: BlocBuilder<TvHomeCubit, TvHomeState>(
              builder: (context, state) {
                if (state.isLoading && state.trending.isEmpty && !state.isSearching) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.errorMessage != null && state.trending.isEmpty) {
                  return Center(child: Text(state.errorMessage!, style: const TextStyle(color: Colors.white70)));
                }

                // Search overrides everything else.
                if (state.isSearching) {
                  if (state.isLoading) return const Center(child: CircularProgressIndicator());
                  return _TvGrid(shows: state.searchResults, emptyLabel: 'No TV shows found.');
                }

                return Column(
                  children: [
                    if (state.genres.isNotEmpty) _GenreChips(genres: state.genres, selectedId: state.selectedGenreId),
                    Expanded(
                      child: state.isFilteringGenre
                          ? (state.isLoadingGenre
                              ? const Center(child: CircularProgressIndicator())
                              : _TvGrid(shows: state.genreResults, emptyLabel: 'No ${state.selectedGenreName ?? ''} shows found.'))
                          : _TvSections(state: state),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal genre-filter chips with a leading "All" chip that clears the
/// filter and returns to the section rows.
class _GenreChips extends StatelessWidget {
  const _GenreChips({required this.genres, required this.selectedId});

  final List<GenreModel> genres;
  final int? selectedId;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _chip(context, label: 'All', selected: selectedId == null, onTap: () => context.read<TvHomeCubit>().clearGenre()),
          for (final genre in genres)
            _chip(
              context,
              label: genre.name,
              selected: selectedId == genre.id,
              onTap: () => context.read<TvHomeCubit>().filterByGenre(genre.id, genre.name),
            ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, {required String label, required bool selected, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? ZipxUi.red : ZipxUi.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? ZipxUi.red : Colors.white24, width: 0.6),
          ),
          child: Text(
            label,
            style: TextStyle(color: Colors.white, fontWeight: selected ? FontWeight.bold : FontWeight.w500),
          ),
        ),
      ),
    );
  }
}

/// The stacked category rows shown when no search or genre filter is active.
class _TvSections extends StatelessWidget {
  const _TvSections({required this.state});

  final TvHomeState state;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _row('Trending', state.trending),
        _row('Popular', state.popular),
        _row('Top Rated', state.topRated),
        _row('On The Air', state.onTheAir),
        _row('Airing Today', state.airingToday),
        // Extra genre rows so there's plenty more to browse.
        for (final section in state.genreSections) _row(section.$1, section.$2),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _row(String title, List<TvModel> shows) {
    if (shows.isEmpty) return const SizedBox.shrink();
    return TvRow(
      title: title,
      cards: [
        for (var i = 0; i < shows.length; i++)
          SizedBox(width: 140, child: TvCard(show: shows[i], autofocus: false)),
      ],
    );
  }
}

/// Responsive poster grid, reused for search and genre-filter results.
class _TvGrid extends StatelessWidget {
  const _TvGrid({required this.shows, required this.emptyLabel});

  final List<TvModel> shows;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (shows.isEmpty) {
      return Center(child: Text(emptyLabel, style: const TextStyle(color: Colors.white70)));
    }
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = (width / 200).floor().clamp(2, 6);
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.62,
      ),
      itemCount: shows.length,
      itemBuilder: (context, index) => TvCard(show: shows[index], autofocus: index == 0),
    );
  }
}
