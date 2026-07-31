/// A language the user can pick in Settings. [code] is the TMDB language
/// parameter (ISO 639-1 + region, e.g. `en-US`) used for movie/TV metadata;
/// [iso639] is the bare two-letter code (e.g. `en`) used for a provider's
/// subtitle-language hint (VidSrc's `ds_lang`).
class SupportedLanguage {
  const SupportedLanguage(this.code, this.name);

  final String code;
  final String name;

  String get iso639 => code.split('-').first;
}

/// English is first so it's the default. TMDB understands all of these as its
/// `language` parameter.
const List<SupportedLanguage> kSupportedLanguages = [
  SupportedLanguage('en-US', 'English'),
  SupportedLanguage('es-ES', 'Spanish'),
  SupportedLanguage('fr-FR', 'French'),
  SupportedLanguage('de-DE', 'German'),
  SupportedLanguage('it-IT', 'Italian'),
  SupportedLanguage('pt-BR', 'Portuguese (Brazil)'),
  SupportedLanguage('pt-PT', 'Portuguese (Portugal)'),
  SupportedLanguage('nl-NL', 'Dutch'),
  SupportedLanguage('pl-PL', 'Polish'),
  SupportedLanguage('sv-SE', 'Swedish'),
  SupportedLanguage('tr-TR', 'Turkish'),
  SupportedLanguage('ru-RU', 'Russian'),
  SupportedLanguage('ar-SA', 'Arabic'),
  SupportedLanguage('hi-IN', 'Hindi'),
  SupportedLanguage('ja-JP', 'Japanese'),
  SupportedLanguage('ko-KR', 'Korean'),
  SupportedLanguage('zh-CN', 'Chinese'),
];

/// The display name for a stored language [code], falling back to English.
String languageNameForCode(String code) {
  for (final lang in kSupportedLanguages) {
    if (lang.code == code) return lang.name;
  }
  return kSupportedLanguages.first.name;
}

/// The bare ISO 639-1 code for a stored language [code] (e.g. `en-US` -> `en`).
String iso639ForCode(String code) {
  final trimmed = code.trim();
  if (trimmed.isEmpty) return kSupportedLanguages.first.iso639;
  return trimmed.split('-').first;
}
