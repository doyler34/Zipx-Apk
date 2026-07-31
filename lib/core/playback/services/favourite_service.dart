import 'package:hive_flutter/hive_flutter.dart';

import '../domain/entities/favourite_entry.dart';
import '../domain/entities/playback_media_type.dart';

/// Movie/TV favourites, backed by their own Hive box. Independent of the
/// pre-existing movie-only bookmarks feature.
class FavouriteService {
  static const String _boxName = 'favourites';

  Box get _box => Hive.box(_boxName);

  List<FavouriteEntry> getFavourites() {
    return _box.values.whereType<Map>().map(FavouriteEntry.fromMap).toList();
  }

  bool isFavourite(PlaybackMediaType mediaType, int tmdbId) {
    return _box.containsKey('${mediaType.name}_$tmdbId');
  }

  Future<void> toggleFavourite(FavouriteEntry entry) async {
    if (_box.containsKey(entry.storageKey)) {
      await _box.delete(entry.storageKey);
    } else {
      await _box.put(entry.storageKey, entry.toMap());
    }
  }
}
