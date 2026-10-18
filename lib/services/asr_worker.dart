import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as so;

import '../core/breadcrumbs.dart';
import '../models/session.dart';
import 'model_manager.dart';
import 'voice_gender.dart';

/// What the background isolate returns for one utterance.
class AsrResult {
  const AsrResult({
    required this.text,
    required this.lang,
    required this.gender,
    this.pitchHz,
  });
  final String text;

  /// Whisper language code detected for this utterance, e.g. `en`, `vi`.
  final String lang;
  final VoiceGender gender;
  final double? pitchHz;
}

/// Runs Whisper (auto language detection) and pitch analysis on a long-lived
/// background isolate so the UI never stutters.
class AsrWorker {
  AsrWorker._(this._isolate, this._send, this._responses);

  final Isolate _isolate;
  final SendPort _send;
  final Stream<dynamic> _responses;
  int _nextId = 0;

  static Future<AsrWorker> spawn(AsrModelPaths paths, [String? crumbs]) async {
    final receive = ReceivePort();
    final isolate = await Isolate.spawn(_main, [
      receive.sendPort,
      paths.encoder,
      paths.decoder,
      paths.tokens,
      crumbs,
    ]);
    final responses = receive.asBroadcastStream();
    final first = await responses.first;
    if (first is String) {
      isolate.kill(priority: Isolate.immediate);
      throw StateError('Speech model failed to load: $first');
    }
    return AsrWorker._(isolate, first as SendPort, responses);
  }

  Future<AsrResult> transcribe(Float32List samples) async {
    final id = _nextId++;
    final future = _responses
        .where((m) => m is List && m.isNotEmpty && m[0] == id)
        .first
        .timeout(const Duration(seconds: 60));
    _send.send([id, TransferableTypedData.fromList([samples])]);
    final m = await future as List;
    return AsrResult(
      text: m[1] as String,
      lang: m[2] as String,
      gender: VoiceGender.values[m[3] as int],
      pitchHz: m[4] as double?,
    );
  }

  void dispose() {
    _send.send(null);
    _isolate.kill(priority: Isolate.beforeNextEvent);
  }

  static void _main(List<dynamic> args) {
    final reply = args[0] as SendPort;
    late final so.OfflineRecognizer recognizer;
    final crumbs = args.length > 4 ? args[4] as String? : null;
    try {
      Breadcrumbs.markAt(crumbs, 'worker: init sherpa bindings');
      so.initBindings();
      Breadcrumbs.markAt(crumbs, 'worker: create Whisper recognizer');
      recognizer = so.OfflineRecognizer(so.OfflineRecognizerConfig(
        model: so.OfflineModelConfig(
          whisper: so.OfflineWhisperModelConfig(
            encoder: args[1] as String,
            decoder: args[2] as String,
            language: '', // auto-detect
            task: 'transcribe',
            tailPaddings: -1,
          ),
          tokens: args[3] as String,
          modelType: 'whisper',
          numThreads: 2,
          debug: false,
          provider: 'cpu',
        ),
      ));
    } catch (e) {
      reply.send(e.toString());
      return;
    }
    Breadcrumbs.markAt(crumbs, 'worker: Whisper loaded');

    const pitch = VoiceGenderDetector();
    final inbox = ReceivePort();
    reply.send(inbox.sendPort);
    inbox.listen((msg) {
      if (msg == null) {
        recognizer.free();
        inbox.close();
        return;
      }
      final list = msg as List;
      final id = list[0] as int;
      final samples =
          (list[1] as TransferableTypedData).materialize().asFloat32List();
      var text = '';
      var lang = '';
      try {
        Breadcrumbs.markAt(crumbs, 'worker: decode start');
        final stream = recognizer.createStream();
        stream.acceptWaveform(samples: samples, sampleRate: 16000);
        recognizer.decode(stream);
        Breadcrumbs.markAt(crumbs, 'worker: decode done');
        final r = recognizer.getResult(stream);
        stream.free();
        text = r.text.trim();
        lang = r.lang.replaceAll(RegExp(r'[<>|]'), '').trim();
      } catch (_) {}
      Breadcrumbs.markAt(crumbs, 'worker: pitch');
      final pr = pitch.analyse(samples);
      reply.send([id, text, lang, pr.gender.index, pr.medianHz]);
    });
  }
}
