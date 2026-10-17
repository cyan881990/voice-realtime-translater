import 'dart:async';
import 'dart:io';

import 'package:flutter_tts/flutter_tts.dart';

import '../core/languages.dart';
import '../models/session.dart';

/// Reads translations aloud with the device's own text-to-speech engine,
/// choosing a male or female voice to match the original speaker when possible.
class TtsService {
  TtsService() {
    _init();
  }

  final FlutterTts _tts = FlutterTts();
  List<Map<String, String>> _voices = const [];
  bool _speaking = false;

  bool get isSpeaking => _speaking;

  Future<void> _init() async {
    await _tts.awaitSpeakCompletion(true);
    if (Platform.isIOS) {
      await _tts.setSharedInstance(true);
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playAndRecord,
        [
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ],
        IosTextToSpeechAudioMode.defaultMode,
      );
    }
    try {
      final raw = await _tts.getVoices;
      if (raw is List) {
        _voices = raw
            .whereType<Map>()
            .map((m) => m.map((k, v) => MapEntry(k.toString(), v.toString())))
            .toList();
      }
    } catch (_) {}
  }

  Future<void> speak(String text, String langCode, VoiceGender gender) async {
    if (text.trim().isEmpty) return;
    final locale = languageByCode(langCode).ttsLocale;
    await _tts.stop();
    await _tts.setLanguage(locale);

    final prefix = locale.toLowerCase().split('-').first;
    final candidates = _voices
        .where((v) => (v['locale'] ?? '').toLowerCase().replaceAll('_', '-').startsWith(prefix))
        .toList();
    final wanted = switch (gender) {
      VoiceGender.male => 'male',
      VoiceGender.female => 'female',
      VoiceGender.unknown => '',
    };
    final match = wanted.isEmpty
        ? null
        : candidates.where((v) => (v['gender'] ?? '').toLowerCase() == wanted).firstOrNull;
    if (match != null) {
      await _tts.setVoice({'name': match['name']!, 'locale': match['locale']!});
      await _tts.setPitch(1.0);
    } else {
      // No gendered voice metadata: approximate with pitch.
      await _tts.setPitch(switch (gender) {
        VoiceGender.male => 0.85,
        VoiceGender.female => 1.15,
        VoiceGender.unknown => 1.0,
      });
    }
    await _tts.setSpeechRate(Platform.isIOS ? 0.5 : 0.48);
    _speaking = true;
    try {
      await _tts.speak(text);
    } finally {
      _speaking = false;
    }
  }

  Future<void> stop() => _tts.stop();
}
