import 'dart:math' as math;
import 'dart:typed_data';

import '../models/session.dart';

/// Result of pitch analysis on one utterance.
class PitchResult {
  const PitchResult(this.medianHz, this.gender);
  final double? medianHz;
  final VoiceGender gender;
}

/// Estimates the speaker's fundamental frequency (F0) with normalised
/// autocorrelation and maps it to a male / female label.
///
/// Typical adult F0: male ~85–155 Hz, female ~165–255 Hz. The boundary is
/// [thresholdHz]. Children and some voices near the boundary can be mislabelled,
/// so the UI lets users correct the label.
class VoiceGenderDetector {
  const VoiceGenderDetector({this.sampleRate = 16000, this.thresholdHz = 160});

  final int sampleRate;
  final double thresholdHz;

  PitchResult analyse(Float32List samples) {
    const minHz = 70.0, maxHz = 400.0;
    final frame = (sampleRate * 0.04).round(); // 40 ms
    final hop = (sampleRate * 0.02).round(); // 20 ms
    final minLag = (sampleRate / maxHz).floor();
    final maxLag = (sampleRate / minHz).ceil();
    if (samples.length < frame + maxLag) {
      return const PitchResult(null, VoiceGender.unknown);
    }

    // Loudness gate relative to the loudest frame, so quiet gaps are ignored.
    var peakRms = 0.0;
    final rmsList = <double>[];
    for (var start = 0; start + frame + maxLag <= samples.length; start += hop) {
      var sum = 0.0;
      for (var i = start; i < start + frame; i++) {
        sum += samples[i] * samples[i];
      }
      final rms = math.sqrt(sum / frame);
      rmsList.add(rms);
      if (rms > peakRms) peakRms = rms;
    }
    if (peakRms < 1e-3) return const PitchResult(null, VoiceGender.unknown);

    final f0s = <double>[];
    var idx = 0;
    for (var start = 0; start + frame + maxLag <= samples.length; start += hop, idx++) {
      if (rmsList[idx] < peakRms * 0.25) continue;
      var bestLag = 0;
      var bestCorr = 0.0;
      var energy0 = 0.0;
      for (var i = start; i < start + frame; i++) {
        energy0 += samples[i] * samples[i];
      }
      final corrs = Float64List(maxLag + 1);
      for (var lag = minLag; lag <= maxLag; lag++) {
        var num = 0.0, energyL = 0.0;
        for (var i = start; i < start + frame; i++) {
          final b = samples[i + lag];
          num += samples[i] * b;
          energyL += b * b;
        }
        final denom = math.sqrt(energy0 * energyL);
        if (denom <= 0) continue;
        final corr = num / denom;
        corrs[lag] = corr;
        if (corr > bestCorr) {
          bestCorr = corr;
          bestLag = lag;
        }
      }
      // Avoid octave errors: prefer the shortest period that is almost as good.
      for (var lag = minLag; lag < bestLag; lag++) {
        final isPeak = corrs[lag] >= corrs[lag - 1] && corrs[lag] >= corrs[lag + 1];
        if (isPeak && corrs[lag] >= bestCorr * 0.9) {
          bestLag = lag;
          break;
        }
      }
      if (bestLag > 0 && bestCorr > 0.6) {
        f0s.add(sampleRate / bestLag);
      }
    }
    if (f0s.length < 5) return const PitchResult(null, VoiceGender.unknown);
    f0s.sort();
    final median = f0s[f0s.length ~/ 2];
    return PitchResult(
      median,
      median < thresholdHz ? VoiceGender.male : VoiceGender.female,
    );
  }
}
