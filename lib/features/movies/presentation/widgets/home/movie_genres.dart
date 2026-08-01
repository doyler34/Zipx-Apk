import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/genre_model.dart';

class MovieGenres extends StatelessWidget {
  const MovieGenres({super.key, required this.genres});

  final List<GenreModel> genres;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      width: double.infinity,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: genres.length,
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final genre = genres[index];
          return GestureDetector(
            onTap: () => context.push('/genre/${genre.id}', extra: genre.name),
            child: Container(
              width: 150,
              margin: const EdgeInsets.only(right: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset('assets/placeholders/genre_placeholder.png', fit: BoxFit.cover),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0x99000000), Color(0xCC000000)],
                        ),
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          genre.name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
