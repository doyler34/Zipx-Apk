import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../common/styles/zipx_ui.dart';
import '../../../../core/dependency_injection/di.dart';
import '../blocs/tv_home_cubit.dart';
import '../widgets/tv_card.dart';

class TvHomeScreen extends StatelessWidget {
  const TvHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<TvHomeCubit>()..loadTrending(),
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
                if (state.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.errorMessage != null) {
                  return Center(child: Text(state.errorMessage!));
                }
                final shows = state.isSearching ? state.searchResults : state.trending;
                if (shows.isEmpty) {
                  return const Center(child: Text('No TV shows found.'));
                }
                // Responsive columns: keeps posters a sensible size instead
                // of two giant ones on a wide TV screen (~2 on a phone, up to
                // 6 on a TV).
                final width = MediaQuery.of(context).size.width;
                final crossAxisCount = (width / 200).floor().clamp(2, 6);
                return GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 0.62,
                  ),
                  itemCount: shows.length,
                  itemBuilder: (context, index) => TvCard(show: shows[index], autofocus: index == 0),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
