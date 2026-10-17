import 'package:google_mlkit_translation/google_mlkit_translation.dart';

/// A spoken language supported end to end: Whisper (speech), ML Kit (translation)
/// and the device text-to-speech engine.
class SpeechLanguage {
  const SpeechLanguage(this.code, this.nativeName, this.mlkit, this.ttsLocale);

  /// Whisper / BCP-47 base code, e.g. `en`, `vi`.
  final String code;
  final String nativeName;
  final TranslateLanguage mlkit;
  final String ttsLocale;

  String get shortCode => code.toUpperCase();
}

const List<SpeechLanguage> kSpeechLanguages = [
  SpeechLanguage('en', 'English', TranslateLanguage.english, 'en-US'),
  SpeechLanguage('vi', 'Tiếng Việt', TranslateLanguage.vietnamese, 'vi-VN'),
  SpeechLanguage('zh', '中文', TranslateLanguage.chinese, 'zh-CN'),
  SpeechLanguage('ja', '日本語', TranslateLanguage.japanese, 'ja-JP'),
  SpeechLanguage('ko', '한국어', TranslateLanguage.korean, 'ko-KR'),
  SpeechLanguage('th', 'ไทย', TranslateLanguage.thai, 'th-TH'),
  SpeechLanguage('id', 'Bahasa Indonesia', TranslateLanguage.indonesian, 'id-ID'),
  SpeechLanguage('fr', 'Français', TranslateLanguage.french, 'fr-FR'),
  SpeechLanguage('es', 'Español', TranslateLanguage.spanish, 'es-ES'),
  SpeechLanguage('de', 'Deutsch', TranslateLanguage.german, 'de-DE'),
  SpeechLanguage('ru', 'Русский', TranslateLanguage.russian, 'ru-RU'),
];

SpeechLanguage languageByCode(String code) => kSpeechLanguages.firstWhere(
      (l) => l.code == code,
      orElse: () => kSpeechLanguages.first,
    );
