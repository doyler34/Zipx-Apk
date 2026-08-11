import 'playback_request.dart';

/// Arguments for the player route. Normally the player just gets a
/// [PlaybackRequest] and resolves sources itself; a [primaryUrl] is a
/// pre-resolved, directly-playable URL (e.g. from a ready Download) that should
/// be played first without going through the normal source lookup.
class PlayerArgs {
  const PlayerArgs({required this.request, this.primaryUrl});

  final PlaybackRequest request;
  final String? primaryUrl;
}
