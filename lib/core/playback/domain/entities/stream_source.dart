/// One playable stream returned by AIOStreams. `url` is the final playback URL
/// (a Real-Debrid stream resolved server-side by AIOStreams) and is played
/// exactly as returned - the client never rebuilds it from a torrent hash.
class StreamSource {
  const StreamSource({
    required this.title,
    required this.url,
    required this.quality,
    required this.provider,
    required this.headers,
    this.releaseName,
    this.filename,
    this.videoSize,
    this.bingeGroup,
    this.infohash,
    this.cached = true,
  });

  /// Whether AIOStreams reports this stream as already cached on the debrid
  /// service (instant-play). Cached streams are preferred, but uncached ones
  /// are still offered as a fallback so obscure/older content isn't lost.
  final bool cached;

  /// Human label, e.g. "Real-Debrid · 1080p".
  final String title;

  /// The release/torrent name (from `behaviorHints.filename`, else the parsed
  /// name/description). Used to fetch subtitles made for this exact release,
  /// which are in sync - unlike a generic title-matched sub.
  final String? releaseName;

  /// `behaviorHints.filename` verbatim, when present. Preserved for autoplay /
  /// release matching.
  final String? filename;

  /// `behaviorHints.videoSize` in bytes, when present. Metadata only - never
  /// used to reject a stream (a BluRay REMUX is legitimately large).
  final int? videoSize;

  /// `behaviorHints.bingeGroup`, when present. Preserved for next-episode
  /// autoplay matching.
  final String? bingeGroup;

  /// The 40-hex torrent infohash, when the stream exposes one (`infoHash` field
  /// or embedded in `bingeGroup`). Sent to the preparation backend so it can
  /// add an uncached release to Real-Debrid server-side. Null when unknown.
  final String? infohash;

  /// Final playback URL from AIOStreams (played as-is).
  final String url;

  /// Quality label ("1080p", "720p", ...).
  final String quality;

  /// Which backend produced it (here, always AIOStreams).
  final String provider;

  /// Request headers the stream needs (User-Agent/Referer). Often empty.
  final Map<String, String> headers;

  bool get isHls => url.toLowerCase().contains('.m3u8');
}
