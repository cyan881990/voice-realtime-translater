import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import '../core/languages.dart';

/// Offline translation with Google ML Kit on-device models (free).
class TranslatorService {
  final Map<String, OnDeviceTranslator> _cache = {};

  Future<String> translate(String text, String from, String to) async {
    if (text.trim().isEmpty || from == to) return text;
    final key = '$from>$to';
    final t = _cache[key] ??= OnDeviceTranslator(
      sourceLanguage: languageByCode(from).mlkit,
      targetLanguage: languageByCode(to).mlkit,
    );
    return t.translateText(text);
  }

  Future<void> dispose() async {
    for (final t in _cache.values) {
      await t.close();
    }
    _cache.clear();
  }
}
