import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:movie_bloc_app/features/movies/presentation/blocs/home/all_movies/all_movies_bloc.dart';
import 'package:movie_bloc_app/features/personalization/presentation/widgets/bookmarks/bookmark_card.dart';

import '../../../data/models/movie_model.dart';

class AllMoviesSection extends StatefulWidget {
  const AllMoviesSection({super.key, required this.movies, required this.isMaxPage, required this.section});

  final List<MovieModel> movies;
  final bool isMaxPage;
  final String section;

  @override
  State<AllMoviesSection> createState() => _AllMoviesSectionState();
}

class _AllMoviesSectionState extends State<AllMoviesSection> {
  // A page whose titles mostly got filtered for availability can be too
  // short to fill the viewport, so it never becomes scrollable - the old
  // scroll-position listener then never fires and the "load more" spinner
  // spins forever. A persistent controller (instead of a fresh one every
  // build) plus a post-frame check lets it top up on its own until the grid
  // is actually scrollable; AllMoviesBloc budgets these auto top-ups (this
  // widget gets torn down and recreated every load-more cycle via the
  // bloc's interim Loading state, so any cap kept here wouldn't survive).
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _topUpIfNotScrollable());
  }

  @override
  void didUpdateWidget(covariant AllMoviesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Always re-check, not just when movies.length changed: a load-more page
    // that filtered down to zero newly-available titles leaves the count
    // unchanged, and gating on the count meant that case never got another
    // auto top-up dispatched - the spinner just hung forever.
    WidgetsBinding.instance.addPostFrameCallback((_) => _topUpIfNotScrollable());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!widget.isMaxPage && _scrollController.position.pixels >= _scrollController.position.maxScrollExtent) {
      context.read<AllMoviesBloc>().add(LoadMoreAllMovies(widget.section));
    }
  }

  void _topUpIfNotScrollable() {
    if (!mounted || widget.isMaxPage) return;
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.maxScrollExtent <= 0) {
      context.read<AllMoviesBloc>().add(LoadMoreAllMovies(widget.section, auto: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GridView.count(
        childAspectRatio: 9 / 16,
        padding: const EdgeInsets.all(6),
        crossAxisCount: 3,
        controller: _scrollController,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        children: [
          for (final movie in widget.movies) BookmarkCard(movie: movie),
          if (!widget.isMaxPage)
            Center(
              child: LoadingAnimationWidget.beat(color: Theme.of(context).primaryColor, size: 50),
            ),
        ],
      ),
    );
  }
}
