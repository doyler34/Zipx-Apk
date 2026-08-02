import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../common/styles/zipx_ui.dart';
import '../../blocs/search/search/search_bloc.dart';

class CustomSearchBar extends StatelessWidget {
  const CustomSearchBar({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return FadeIn(
      child: BlocBuilder(
        bloc: context.read<SearchBloc>(),
        builder: (context, state) {
          return TextField(
            controller: context.read<SearchBloc>().controller,
            style: const TextStyle(color: Colors.white),
            cursorColor: ZipxUi.red,
            decoration: InputDecoration(
              hintText: 'Search movies...',
              hintStyle: const TextStyle(color: ZipxUi.textMuted),
              filled: true,
              fillColor: ZipxUi.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              prefixIcon: const Icon(Icons.search, color: ZipxUi.textMuted),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: ZipxUi.red, width: 1.2),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              suffixIcon: context.read<SearchBloc>().controller.text.trim().isNotEmpty
                  ? FadeIn(
                      child: IconButton(
                        onPressed: () {
                          context.read<SearchBloc>().controller.clear();
                          context.read<SearchBloc>().add(SearchMovies(context.read<SearchBloc>().controller.text));
                        },
                        icon: const Icon(Icons.clear, color: ZipxUi.textMuted),
                      ),
                    )
                  : null,
            ),
            onChanged: (_) {
              context.read<SearchBloc>().add(SearchMovies(context.read<SearchBloc>().controller.text));
            },
            onTapOutside: (_) {
              FocusManager.instance.primaryFocus?.unfocus();
            },
          );
        },
      ),
    );
  }
}
