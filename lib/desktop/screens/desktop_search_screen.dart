import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../common/styles/zipx_ui.dart';
import '../../core/dependency_injection/di.dart';
import '../../features/movies/presentation/blocs/search/search/search_bloc.dart';
import '../../features/movies/presentation/widgets/search/custom_search_bar.dart';
import '../../features/personalization/presentation/blocs/settings/settings_bloc.dart';
import '../../common/widgets/movie/movie_card.dart';
import '../widgets/hover_scale.dart';

/// Desktop Search: the shared ZipX search bar over a poster grid (instead of the
/// phone's stacked list rows). Paginates on scroll and reuses the same
/// [SearchBloc] and [MovieCard] as the rest of the app.
class DesktopSearchScreen extends StatelessWidget {
  const DesktopSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<SearchBloc>(),
      child: SafeArea(
        left: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(48, 24, 48, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: const CustomSearchBar(),
              ),
              const SizedBox(height: 20),
              const Expanded(child: _Grid()),
            ],
          ),
        ),
      ),
    );
  }
}

class _Grid extends StatefulWidget {
  const _Grid();

  @override
  State<_Grid> createState() => _GridState();
}

class _GridState extends State<_Grid> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (_controller.position.pixels >= _controller.position.maxScrollExtent - 400) {
        context.read<SearchBloc>().add(SearchLoadMore());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, settings) {
        final showAdult = settings is SettingsChanged && settings.showAdultContent;
        return BlocBuilder<SearchBloc, SearchState>(
          builder: (context, state) {
            final bloc = context.read<SearchBloc>();
            final loaded = state is SearchLoaded;
            final hasCached = state is SearchInitial && bloc.movies.isNotEmpty;

            if (!loaded && !hasCached) {
              return _message(
                state is SearchNoInternet
                    ? 'No internet connection'
                    : state is SearchError
                        ? 'Something went wrong'
                        : state is SearchLoading
                            ? 'Searching…'
                            : 'Search for movies',
                icon: state is SearchLoading ? null : Icons.search,
              );
            }

            final raw = loaded ? state.movies : bloc.movies;
            final isMaxPage = loaded ? state.isMaxPage : bloc.isMaxPage;
            final movies = (showAdult ? raw : raw.where((m) => !m.adult))
                .where((m) => m.posterPath.trim().isNotEmpty)
                .toList();

            if (movies.isEmpty) return _message('No movies found', icon: Icons.search_off);

            return GridView.builder(
              controller: _controller,
              padding: const EdgeInsets.only(bottom: 32),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                childAspectRatio: 0.58,
                crossAxisSpacing: 18,
                mainAxisSpacing: 18,
              ),
              itemCount: isMaxPage ? movies.length : movies.length + 1,
              itemBuilder: (context, i) {
                if (i >= movies.length) {
                  return const Center(child: CircularProgressIndicator(color: ZipxUi.red));
                }
                return HoverScale(child: MovieCard(movie: movies[i], isHomePage: true));
              },
            );
          },
        );
      },
    );
  }

  Widget _message(String text, {IconData? icon}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) Icon(icon, color: Colors.white24, size: 54) else const CircularProgressIndicator(color: ZipxUi.red),
          const SizedBox(height: 14),
          Text(text, style: const TextStyle(color: ZipxUi.textMuted, fontSize: 15)),
        ],
      ),
    );
  }
}
