import 'package:hive_flutter/hive_flutter.dart';

class UserSettings {
  /// TMDB key baked into the build via `--dart-define=TMDB_API_KEY=...` in CI.
  /// Empty when not provided at build time; the app then falls back to a key
  /// the user enters in Settings. A key the user sets themselves always wins
  /// over this build-time default.
  static const String _buildTimeApiKey = String.fromEnvironment('TMDB_API_KEY', defaultValue: '');

  static final Map<String, dynamic> _defaultSettings = {
    'api_key': '',
    'language': 'en-US',
    'include_adult': false,
  };

  late Map<String, dynamic> _settings;

  static const String _defaultThemeMode = 'auto';

  late String _themeMode;

  UserSettings() {
    _settings = _defaultSettings;
    _themeMode = _defaultThemeMode;
    loadFromStorage();
  }

  String getThemeMode() {
    return _themeMode;
  }

  Map<String, dynamic> getSettings() {
    final settings = Map<String, dynamic>.from(_settings);
    // Fall back to the build-time key when the user hasn't set their own.
    final stored = (settings['api_key'] as String?)?.trim() ?? '';
    if (stored.isEmpty && _buildTimeApiKey.isNotEmpty) {
      settings['api_key'] = _buildTimeApiKey;
    }
    return settings;
  }

  void setThemeMode(String themeMode) {
    _themeMode = themeMode;
    saveToStorage();
  }

  void setLanguage(String language) {
    _settings['language'] = language;
    saveToStorage();
  }

  void setAdultContent(bool includeAdult) {
    _settings['include_adult'] = includeAdult;
    saveToStorage();
  }

  void setApiKey(String apiKey) {
    _settings['api_key'] = apiKey;
    saveToStorage();
  }

  String getApiKey() {
    final stored = (_settings['api_key'] as String?)?.trim() ?? '';
    return stored.isNotEmpty ? stored : _buildTimeApiKey;
  }

  void saveToStorage() {
    Hive.box('settings').put('settings', _settings);
    Hive.box('theme_mode').put('theme_mode', _themeMode);
  }

  void loadFromStorage() async {
    try {
      var box = Hive.box('settings');
      var loadedSettings = box.get('settings', defaultValue: _settings);
      _settings = Map<String, dynamic>.from(loadedSettings);

      var boxTheme = Hive.box('theme_mode');
      var loadedTheme = boxTheme.get('theme_mode', defaultValue: _themeMode);
      _themeMode = loadedTheme as String;
    } catch (e) {
      var box = Hive.box('settings');
      box.put('settings', _defaultSettings);
      _settings = _defaultSettings;

      var boxTheme = Hive.box('theme_mode');
      boxTheme.put('theme_mode', _defaultThemeMode);
      _themeMode = _defaultThemeMode;
    }
  }

  void reset() {
    var box = Hive.box('settings');
    box.clear();
    box.put('settings', _defaultSettings);
    _settings = _defaultSettings;

    var boxTheme = Hive.box('theme_mode');
    boxTheme.clear();
    boxTheme.put('theme_mode', _defaultThemeMode);
    _themeMode = _defaultThemeMode;
  }
}
