import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voice_realtime_translater/models/session.dart';
import 'package:voice_realtime_translater/services/update_service.dart';
import 'package:voice_realtime_translater/services/voice_gender.dart';

Float32List voiced(double f0, {double seconds = 1.0}) {
  const sr = 16000;
  final n = (sr * seconds).round();
  final out = Float32List(n);
  for (var i = 0; i < n; i++) {
    final t = i / sr;
    // Fundamental plus two harmonics, like a simple vowel.
    out[i] = (0.5 * math.sin(2 * math.pi * f0 * t) +
            0.25 * math.sin(2 * math.pi * 2 * f0 * t) +
            0.12 * math.sin(2 * math.pi * 3 * f0 * t))
        .toDouble();
  }
  return out;
}

void main() {
  test('low voice is labelled male, high voice female', () {
    const d = VoiceGenderDetector();
    final male = d.analyse(voiced(118));
    final female = d.analyse(voiced(215));
    expect(male.gender, VoiceGender.male);
    expect(female.gender, VoiceGender.female);
    expect(male.medianHz!, closeTo(118, 6));
    expect(female.medianHz!, closeTo(215, 10));
  });

  test('silence is unknown', () {
    expect(const VoiceGenderDetector().analyse(Float32List(16000)).gender, VoiceGender.unknown);
  });

  test('semantic version comparison', () {
    expect(UpdateService.isNewer('1.10.0', '1.9.3'), isTrue);
    expect(UpdateService.isNewer('1.0.0', '1.0.0'), isFalse);
    expect(UpdateService.isNewer('1.0.1+5', '1.0.0+9'), isTrue);
  });

  test('session JSON round trip', () {
    final s = Session(
      id: '1',
      title: 'Test',
      createdAt: DateTime(2026, 10, 17, 15, 0),
      languageA: 'en',
      languageB: 'vi',
      durationMs: 5000,
      segments: [
        Segment(
          startMs: 0,
          endMs: 1200,
          sourceLang: 'en',
          targetLang: 'vi',
          sourceText: 'Hello',
          translatedText: 'Xin chào',
          gender: VoiceGender.female,
          pitchHz: 210,
        ),
      ],
    );
    final back = Session.fromJson(s.toJson());
    expect(back.segments.single.translatedText, 'Xin chào');
    expect(back.segments.single.gender, VoiceGender.female);
  });
}
