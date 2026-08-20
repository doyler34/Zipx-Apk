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

class _AnimeHomeView extends StatefulWidget {
  const _AnimeHomeView();

  @override
  State<_AnimeHomeView> createState() => _AnimeHomeViewState();
}

class _AnimeHomeViewState extends State<_AnimeHomeView> {
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
              onChanged: (value) => context.read<AnimeHomeCubit>().search(value),
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
                  return _AnimeGrid(results: state.searchResults);
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

  Widget _movieRow(String title, List<MovieModel> movies) {
    if (movies.isEmpty) return const SizedBox.shrink();
    return TvRow(
      title: title,
      cards: [for (final m in movies) SizedBox(width: 150, child: AnimeMovieCard(movie: m))],
    );
  }

  Widget _tvRow(String title, List<TvModel> shows) {
    if (shows.isEmpty) return const SizedBox.shrink();
    return TvRow(
      title: title,
      cards: [for (var i = 0; i < shows.length; i++) SizedBox(width: 150, child: TvCard(show: shows[i], autofocus: false, isAnime: true))],
    );
  }
}

/// Responsive poster grid for search results (a mix of anime movies + series).
class _AnimeGrid extends StatelessWidget {
  const _AnimeGrid({required this.results});

  final List<dynamic> results;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const Center(child: Text('No anime found.', style: TextStyle(color: Colors.white70)));
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
