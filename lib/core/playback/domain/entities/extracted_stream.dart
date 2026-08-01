/// A real, directly-playable video stream (usually an HLS `.m3u8`) resolved
/// out of a provider's embed page, together with the HTTP headers a native
/// player must send to fetch it (providers' CDNs 403 without the right
/// Referer/Origin).
///
/// This is what lets playback move off the un-controllable embed WebView and
/// onto a native ExoPlayer: feed [url] + [headers] to a VideoPlayerController
/// and the Fire TV remote controls it natively.
class ExtractedStream {
  const ExtractedStream({
    required this.url,
    required this.headers,
    required this.extractedAt,
    this.sourceHost,
  });

  final String url;
  final Map<String, String> headers;

  /// When this was resolved - used by the cache to expire it, since these
  /// URLs are signed/tokenised and stop working after a while.
  final DateTime extractedAt;

  /// Which mirror host produced it (diagnostics only).
  final String? sourceHost;

  Map<String, dynamic> toMap() => {
        'url': url,
        'headers': headers,
        'extractedAt': extractedAt.millisecondsSinceEpoch,
        'sourceHost': sourceHost,
      };

  static ExtractedStream fromMap(Map map) => ExtractedStream(
        url: map['url'] as String,
        headers: (map['headers'] as Map).map((k, v) => MapEntry(k.toString(), v.toString())),
        extractedAt: DateTime.fromMillisecondsSinceEpoch(map['extractedAt'] as int),
        sourceHost: map['sourceHost'] as String?,
      );
}
