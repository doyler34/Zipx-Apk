/// One playable stream returned by the self-hosted sources backend
/// (TMDB-Embed-API). Each is a direct video URL (m3u8/mp4) plus any headers it
/// needs, so it can be played in a native player - no WebView, no ads.
class StreamSource {
  const StreamSource({
    required this.title,
    required this.url,
    required this.quality,
    required this.provider,
    required this.headers,
    this.releaseName,
  });

  /// Human label, e.g. "1080p" or the release name.
  final String title;

  /// The raw release/torrent name (e.g. "Pursuit.of.Jade.S01E01.1080p.WEB-DL...")
  /// when known. Used to fetch subtitles made for this exact release, which are
  /// in sync - unlike a generic title-matched sub. Null for sources that don't
  /// expose it.
  final String? releaseName;

  /// Direct video URL (HLS `.m3u8` or progressive `.mp4`).
  final String url;

  /// Quality label from the backend ("1080p", "Auto", ...).
  final String quality;

  /// Which backend provider produced it (VixSrc, NoTorrent, ...).
  final String provider;

  /// Request headers the stream needs (User-Agent/Referer). Often empty.
  final Map<String, String> headers;

  bool get isHls => url.toLowerCase().contains('.m3u8');

  factory StreamSource.fromJson(Map<String, dynamic> json) {
    final headers = <String, String>{};
    final rawHeaders = json['headers'];
    if (rawHeaders is Map) {
      rawHeaders.forEach((key, value) {
        // The backend sometimes returns a Range header ("bytes=0-"); the video
        // player manages ranges itself, so never forward that one.
        if (key.toString().toLowerCase() == 'range') return;
        headers[key.toString()] = value.toString();
      });
    }
    return StreamSource(
      title: (json['title'] ?? json['name'] ?? 'Stream').toString(),
      url: (json['url'] ?? '').toString(),
      quality: (json['quality'] ?? '').toString(),
      provider: (json['provider'] ?? json['name'] ?? '').toString(),
      headers: headers,
    );
  }
}
