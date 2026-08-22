import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../common/styles/zipx_ui.dart';
import '../../../../core/dependency_injection/di.dart';
import '../../../movies/data/models/movie_model.dart';
import '../../../tv/data/models/tv_model.dart';
import '../../../tv/presentation/widgets/tv_card.dart';
import '../../../tv/presentation/widgets/tv_row.dart';
import '../widgets/anime_movie_card.dart';
import '../blocs/anime_home_cubit.dart';

class AnimeHomeScreen extends StatelessWidget {
  const AnimeHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<AnimeHomeCubit>()..loadHome(),
      child: const _AnimeHomeView(),
    );
  }
}

/// Which of a mixed movie+series search result to show. Search results have
/// no inherent type separation (One Piece alone turns up a dozen films and
/// specials mixed in with the main series), so this lets the user narrow
/// down to just one kind instead of hunting through both.
enum _SearchTypeFilter { all, movies, series }

class _AnimeHomeView extends StatefulWidget {
  const _AnimeHomeView();

  @override
  State<_AnimeHomeView> createState() => _AnimeHomeViewState();
}

class _AnimeHomeViewState extends State<_AnimeHomeView> {
  final _controller = TextEditingController();
  _SearchTypeFilter _searchFilter = _SearchTypeFilter.all;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<dynamic> _filtered(List<dynamic> results) {
    switch (_searchFilter) {
      case _SearchTypeFilter.all:
        return results;
      case _SearchTypeFilter.movies:
        return results.whereType<MovieModel>().toList();
      case _SearchTypeFilter.series:
        return results.whereType<TvModel>().toList();
    }
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
              onChanged: (value) {
                context.read<AnimeHomeCubit>().search(value);
                // A new search starts from "All" - a filter left over from a
                // previous query could otherwise hide every result with no
                // indication why.
                setState(() => _searchFilter = _SearchTypeFilter.all);
              },
              decoration: InputDecoration(
                hintText: 'Search anime...',
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
            child: BlocBuilder<AnimeHomeCubit, AnimeHomeState>(
              builder: (context, state) {
                if (state.isLoading && state.isEmpty && !state.isSearching) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.errorMessage != null && state.isEmpty) {
                  return Center(child: Text(state.errorMessage!, style: const TextStyle(color: Colors.white70)));
                }

                if (state.isSearching) {
                  if (state.isLoading) return const Center(child: CircularProgressIndicator());
                  return Column(
                    children: [
                      _SearchTypeChips(
                        selected: _searchFilter,
                        onChanged: (f) => setState(() => _searchFilter = f),
                      ),
                      Expanded(
                        child: _AnimeGrid(
                          results: _filtered(state.searchResults),
                          emptyLabel: state.searchResults.isEmpty
                              ? 'No anime found.'
                              : switch (_searchFilter) {
                                  _SearchTypeFilter.all => 'No anime found.',
                                  _SearchTypeFilter.movies => 'No matching movies - try Series or All.',
                                  _SearchTypeFilter.series => 'No matching series - try Movies or All.',
                                },
                        ),
                      ),
                    ],
                  );
                }

                return ListView(
                  children: [
                    if (state.movieSections.isNotEmpty) _groupHeader('Movies'),
                    for (final section in state.movieSections) _movieRow(section.$1, section.$2),
                    if (state.tvSections.isNotEmpty) _groupHeader('TV Shows'),
                    for (final section in state.tvSections) _tvRow(section.$1, section.$2),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupHeader(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      );

  // A row this thin reads as broken rather than intentional - hide it
  // instead of showing a couple of posters trailing into empty space.
  static const int _minRowSize = 6;

  Widget _movieRow(String title, List<MovieModel> movies) {
    if (movies.length < _minRowSize) return const SizedBox.shrink();
    return TvRow(
      title: title,
      cards: [for (final m in movies) SizedBox(width: 150, child: AnimeMovieCard(movie: m))],
    );
  }

  Widget _tvRow(String title, List<TvModel> shows) {
    if (shows.length < _minRowSize) return const SizedBox.shrink();
    return TvRow(
      title: title,
      cards: [for (var i = 0; i < shows.length; i++) SizedBox(width: 150, child: TvCard(show: shows[i], autofocus: false, isAnime: true))],
    );
  }
}

/// "All / Movies / Series" filter row shown above search results.
class _SearchTypeChips extends StatelessWidget {
  const _SearchTypeChips({required this.selected, required this.onChanged});

  final _SearchTypeFilter selected;
  final ValueChanged<_SearchTypeFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          _chip(label: 'All', value: _SearchTypeFilter.all),
          const SizedBox(width: 8),
          _chip(label: 'Movies', value: _SearchTypeFilter.movies),
          const SizedBox(width: 8),
          _chip(label: 'Series', value: _SearchTypeFilter.series),
        ],
      ),
    );
  }

  Widget _chip({required String label, required _SearchTypeFilter value}) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? ZipxUi.red : ZipxUi.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? ZipxUi.red : Colors.white24, width: 0.6),
        ),
        child: Text(
          label,
          style: TextStyle(color: Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500),
        ),
      ),
    );
  }
}

/// Responsive poster grid for search results (a mix of anime movies + series).
class _AnimeGrid extends StatelessWidget {
  const _AnimeGrid({required this.results, this.emptyLabel = 'No anime found.'});

  final List<dynamic> results;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
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
      itemCount: results.length,
      itemBuilder: (context, index) {
        final item = results[index];
        if (item is MovieModel) return AnimeMovieCard(movie: item);
        if (item is TvModel) return TvCard(show: item, autofocus: index == 0, isAnime: true);
        return const SizedBox.shrink();
      },
    );
  }
}
