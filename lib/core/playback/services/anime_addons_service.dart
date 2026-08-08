import 'package:hive_flutter/hive_flutter.dart';

/// How an addon identifies content in its `/stream/...` path.
enum AddonIdScheme {
  /// Standard Stremio IMDb id: `tt1234567` (+ `:season:episode` for series).
  /// Works with no extra mapping - the app already resolves TMDB -> IMDb.
  imdb,

  /// Kitsu id: `kitsu:1234:episode`. Requires the TMDB -> Kitsu + absolute
  /// episode mapping (Stage 2); such addons are skipped until that lands.
  kitsu,
}

/// One extra Stremio-compatible addon queried alongside Comet.
class StremioAddon {
  const StremioAddon({
    required this.name,
    required this.baseUrl,
    this.idScheme = AddonIdScheme.imdb,
    this.animeOnly = false,
  });

  /// Shown as the source's provider label in the picker.
  final String name;

  /// Everything before `/stream/...` - including any `/<config>` path segment,
  /// no trailing slash. e.g. `http://2.24.98.35:8001/<config>`.
  final String baseUrl;

  final AddonIdScheme idScheme;

  /// True for anime-specialised addons (Torii): only queried for anime titles,
  /// so non-anime playback never pays for a request that returns nothing.
  final bool animeOnly;
}

/// The configurable list of anime-focused Stremio addons that are queried in
/// parallel with Comet. Kept separate from Comet so it can never affect it, and
/// backed by a Hive box so more addon URLs can be added later (self-hosted Torii,
/// etc.) without an app update.
class AnimeAddonsService {
  static const String boxName = 'anime_addons';
  static const String _urlsKey = 'urls';

  /// Base URLs (everything before `/manifest.json`) injected at build time via
  /// `--dart-define`, so URLs carrying the Real-Debrid key stay out of source
  /// control. Empty in a plain local build (that provider just isn't queried).
  static const String _toriiUrl = String.fromEnvironment('TORII_ADDON_URL');
  static const String _mediaFusionUrl = String.fromEnvironment('MEDIAFUSION_ADDON_URL');

  Box get _box => Hive.box(boxName);

  static String _clean(String url) => url.trim().replaceAll(RegExp(r'/+$'), '');

  /// The build-time addons (Torii = anime-only; MediaFusion = all content) plus
  /// any user-added addon URLs. Trailing slashes are normalised.
  List<StremioAddon> addons() {
    final out = <StremioAddon>[];
    final torii = _clean(_toriiUrl);
    if (torii.isNotEmpty) {
      out.add(StremioAddon(name: 'Torii', baseUrl: torii, animeOnly: true));
    }
    final mediaFusion = _clean(_mediaFusionUrl);
    if (mediaFusion.isNotEmpty) {
      out.add(StremioAddon(name: 'MediaFusion', baseUrl: mediaFusion));
    }
    final raw = _box.get(_urlsKey);
    if (raw is List) {
      for (final u in raw) {
        final url = _clean(u.toString());
        if (url.isNotEmpty) out.add(StremioAddon(name: 'Addon', baseUrl: url));
      }
    }
    return out;
  }

  /// Replaces the user-added addon URL list (for a future settings screen).
  Future<void> setUrls(List<String> urls) => _box.put(_urlsKey, urls);
}
