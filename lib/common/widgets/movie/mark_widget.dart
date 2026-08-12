import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:movie_bloc_app/common/styles/zipx_ui.dart';
import 'package:movie_bloc_app/features/movies/data/models/movie_model.dart';

import '../../../core/utils/helpers/helper_functions.dart';
import '../../../features/personalization/presentation/blocs/bookmarks/bookmarks_bloc.dart';

/// Compact bookmark toggle: a small translucent circular button that shows an
/// outline bookmark when unsaved and a filled red one when saved, instead of
/// the old large red square. [width]/[height]/[hasShadow] are kept for call
/// -site compatibility.
class MarkWidget extends StatelessWidget {
  const MarkWidget({
    super.key,
    required this.movie,
    this.width = 45,
    this.height = 45,
    this.hasShadow = false,
    this.align = true,
  });

  final MovieModel movie;
  final double width;
  final double height;
  final bool hasShadow;
  final bool align;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder(
      bloc: context.read<BookmarksBloc>(),
      builder: (context, state) {
        if (state is BookmarksChanged) {
          final isBookmarked = state.bookmarkIds.contains(movie.id);

          return Align(
            alignment: align ? Alignment.topRight : Alignment.center,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onTap: () {
                  if (isBookmarked) {
                    context.read<BookmarksBloc>().add(RemoveBookmark(movie));
                    HelperFunctions.showSnackBar(context, 'Removed from Watchlist');
                  } else {
                    context.read<BookmarksBloc>().add(AddBookmark(movie));
                    HelperFunctions.showSnackBar(context, 'Added to Watchlist');
                  }
                },
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 0.5),
                  ),
                  child: Icon(
                    isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    color: isBookmarked ? ZipxUi.red : Colors.white,
                    size: 17,
                  ),
                ),
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
