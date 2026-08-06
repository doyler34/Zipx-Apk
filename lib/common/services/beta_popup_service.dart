import 'package:shared_preferences/shared_preferences.dart';

/// Decides whether the Beta launch popup should be shown, and records when it
/// was dismissed. State is persisted with [SharedPreferences].
///
/// - To show the popup again for a NEW release, bump [versionKey] (e.g. to
///   `'beta_v2_seen'`). Each version key is independent, so every beta gets its
///   own single showing.
/// - [minReshowInterval] throttles re-showing after a dismissal. It's set to 12
///   hours so the popup doesn't nag on every launch. For strict
///   once-per-version behaviour (never again for that version), set it to
///   something huge like `Duration(days: 3650)`.
class BetaPopupService {
  BetaPopupService._();

  /// The SharedPreferences key for the current beta version. Change this per
  /// release to re-show the popup.
  static const String versionKey = 'beta_v1_seen';

  /// How long to wait before showing again after a dismissal.
  static const Duration minReshowInterval = Duration(hours: 12);

  /// In-memory guard so the popup shows at most once per app session, even if
  /// the host widget (e.g. the home screen) is rebuilt or re-mounted.
  static bool _handledThisSession = false;

  /// True if the popup should be shown now.
  static Future<bool> shouldShow() async {
    if (_handledThisSession) return false;
    final prefs = await SharedPreferences.getInstance();
    final lastMillis = prefs.getInt(versionKey);
    if (lastMillis == null) return true;
    final last = DateTime.fromMillisecondsSinceEpoch(lastMillis);
    return DateTime.now().difference(last) >= minReshowInterval;
  }

  /// Marks the popup as handled for this session (call as soon as we've decided
  /// to show it, so a rebuild can't trigger a second one).
  static void markHandledThisSession() => _handledThisSession = true;

  /// Persists the dismissal timestamp under [versionKey].
  static Future<void> markSeen() async {
    _handledThisSession = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(versionKey, DateTime.now().millisecondsSinceEpoch);
  }
}
