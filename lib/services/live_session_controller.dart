import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as so;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/breadcrumbs.dart';
import '../core/languages.dart';
import '../core/settings_controller.dart';
import '../data/session_repository.dart';
import '../models/session.dart';
import 'asr_worker.dart';
import 'model_manager.dart';
import 'translator_service.dart';
import 'tts_service.dart';

enum LiveState { idle, starting, recording, paused, finishing }

/// Orchestrates: microphone → VAD → Whisper (auto language) → ML Kit
/// translation → male/female label → optional read-aloud.
class LiveSessionController extends ChangeNotifier {
  LiveSessionController({
    required this.settings,
    required this.models,
    required this.repository,
    required this.translator,
    required this.tts,
  });

  final SettingsController settings;
  final ModelManager models;
  final SessionRepository repository;
  final TranslatorService translator;
  final TtsService tts;

  static const _sampleRate = 16000;

  final AudioRecorder _recorder = AudioRecorder();
  AsrWorker? _worker;
  String? _workerModelKey;
  so.VoiceActivityDetector? _vad;
  StreamSubscription<Uint8List>? _sub;

  LiveState _state = LiveState.idle;
  LiveState get state => _state;

  final List<Segment> segments = [];
  final Stopwatch _clock = Stopwatch();
  Duration get elapsed => _clock.elapsed;

  /// True while the VAD hears speech that has not been transcribed yet.
  bool speechActive = false;
  int pendingCount = 0;
  String? lastError;

  /// Recent input levels (0..1) for the waveform.
  final List<double> levels = List.filled(40, 0.0, growable: true);

  BytesBuilder? _pcm;
  String? _lastSourceLang;
  int _samplesSeen = 0;
  DateTime? _ignoreUntil;
  Future<void> _queue = Future.value();
  Timer? _ticker;

  bool get isActive => _state == LiveState.recording || _state == LiveState.paused;

  // ------------------------------------------------ device recognizer engine
  // Uses the phone's built-in speech recognizer (Google / Apple). Works on
  // almost every device; each person taps their language button to speak.
  final SpeechToText _stt = SpeechToText();
  bool _sttReady = false;
  bool get usesDeviceEngine => settings.engine == SpeechEngine.device;

  /// Language currently being listened to in device mode (null = waiting).
  String? listeningLang;

  /// Words heard so far in the current device-mode turn.
  String partialText = '';

  Future<void> _startDevice() async {
    Breadcrumbs.mark('device recognizer: initialize');
    if (!_sttReady) {
      _sttReady = await _stt.initialize(
        onError: (e) {
          Breadcrumbs.mark('device recognizer error: ${e.errorMsg}');
          if (e.permanent) {
            listeningLang = null;
            partialText = '';
            notifyListeners();
          }
        },
        onStatus: (st) {
          if ((st == 'done' || st == 'notListening') && listeningLang != null && partialText.isEmpty) {
            listeningLang = null;
            notifyListeners();
          }
        },
      );
    }
    if (!_sttReady) throw StateError('device-recognizer-unavailable');
    Breadcrumbs.mark('device recognizer ready');
  }

  /// Device mode: listen to one turn in [lang], then translate it.
  Future<void> listenTurn(String lang) async {
    if (_state != LiveState.recording || !usesDeviceEngine) return;
    if (listeningLang != null) await _stt.stop();
    listeningLang = lang;
    partialText = '';
    notifyListeners();
    final locale = languageByCode(lang).ttsLocale.replaceAll('-', '_');
    final startMs = _clock.elapsedMilliseconds;
    await _stt.listen(
      onResult: (SpeechRecognitionResult r) {
        partialText = r.recognizedWords;
        if (r.finalResult) {
          final text = partialText.trim();
          final from = listeningLang ?? lang;
          listeningLang = null;
          partialText = '';
          if (text.isNotEmpty) {
            pendingCount++;
            _queue = _queue.then((_) => _translateText(text, from, startMs, _clock.elapsedMilliseconds));
          }
        }
        notifyListeners();
      },
      onSoundLevelChange: (level) {
        // Android reports roughly -2..10 dB, iOS 0..-160.
        final v = level > 0 ? (level / 10).clamp(0.05, 1.0) : 0.05;
        levels
          ..removeAt(0)
          ..add(v.toDouble());
      },
      listenOptions: SpeechListenOptions(
        localeId: locale,
        partialResults: true,
        listenMode: ListenMode.dictation,
        pauseFor: Duration(milliseconds: (settings.silenceSeconds * 1000).round() + 1200),
        listenFor: const Duration(seconds: 60),
        cancelOnError: true,
        autoPunctuation: true,
      ),
    );
  }

  Future<void> stopTurn() async {
    if (listeningLang == null) return;
    await _stt.stop();
  }

  Future<void> _translateText(String text, String source, int startMs, int endMs) async {
    try {
      final a = settings.languageA, b = settings.languageB;
      final target = source == a ? b : a;
      final translated = await translator.translate(text, source, target);
      final s = Segment(
        startMs: startMs,
        endMs: endMs,
        sourceLang: source,
        targetLang: target,
        sourceText: text,
        translatedText: translated,
      );
      segments.add(s);
      notifyListeners();
      if (settings.autoReadAloud && _state == LiveState.recording) {
        await tts.speak(s.translatedText, s.targetLang, s.gender);
      }
    } catch (e) {
      lastError = e.toString();
    } finally {
      pendingCount = (pendingCount - 1).clamp(0, 1 << 30);
      notifyListeners();
    }
  }

  Future<bool> hasMicPermission() => _recorder.hasPermission();

  Future<void> _ensureEngines() async {
    final paths = await models.paths();
    Breadcrumbs.mark('check model files');
    await models.verifyFiles(paths);
    final key = paths.encoder;
    if (_worker == null || _workerModelKey != key) {
      _worker?.dispose();
      Breadcrumbs.mark('spawn speech worker (load Whisper)');
      _worker = await AsrWorker.spawn(paths, Breadcrumbs.path);
      _workerModelKey = key;
      Breadcrumbs.mark('speech worker ready');
    }
    _vad?.free();
    Breadcrumbs.mark('init sherpa bindings (main)');
    so.initBindings();
    Breadcrumbs.mark('create VAD');
    _vad = so.VoiceActivityDetector(
      config: so.VadModelConfig(
        sileroVad: so.SileroVadModelConfig(
          model: paths.vad,
          minSilenceDuration: settings.silenceSeconds,
          minSpeechDuration: 0.25,
          maxSpeechDuration: 12.0,
        ),
        sampleRate: _sampleRate,
        numThreads: 1,
        provider: 'cpu',
        debug: false,
      ),
      bufferSizeInSeconds: 30,
    );
    Breadcrumbs.mark('VAD ready');
  }

  Future<void> start() async {
    if (_state != LiveState.idle) return;
    lastError = null;
    _state = LiveState.starting;
    notifyListeners();
    try {
      Breadcrumbs.begin('start session');
      Breadcrumbs.mark('ask mic permission');
      if (!await _recorder.hasPermission()) {
        throw StateError('mic-permission');
      }
      segments.clear();
      _lastSourceLang = null;
      _samplesSeen = 0;
      if (usesDeviceEngine) {
        await _startDevice();
        _pcm = null;
        _clock
          ..reset()
          ..start();
        _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => notifyListeners());
        await WakelockPlus.enable();
        _state = LiveState.recording;
        Breadcrumbs.mark('recording (device recognizer)');
        notifyListeners();
        return;
      }
      await _ensureEngines();
      Breadcrumbs.mark('start microphone stream');
      _firstAudio = true;
      _firstVad = true;
      _pcm = settings.saveAudio ? BytesBuilder(copy: false) : null;
      final stream = await _recorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: 1,
        echoCancel: true,
        noiseSuppress: true,
      ));
      _sub = stream.listen(_onAudio);
      _clock
        ..reset()
        ..start();
      _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => notifyListeners());
      await WakelockPlus.enable();
      _state = LiveState.recording;
      Breadcrumbs.mark('recording');
    } catch (e) {
      Breadcrumbs.mark('start failed: $e');
      Breadcrumbs.finish();
      lastError = e.toString();
      _state = LiveState.idle;
    }
    notifyListeners();
  }

  Future<void> pause() async {
    if (_state != LiveState.recording) return;
    if (usesDeviceEngine) {
      await stopTurn();
    } else {
      await _recorder.pause();
    }
    _clock.stop();
    _state = LiveState.paused;
    notifyListeners();
  }

  Future<void> resume() async {
    if (_state != LiveState.paused) return;
    if (!usesDeviceEngine) await _recorder.resume();
    _clock.start();
    _state = LiveState.recording;
    notifyListeners();
  }

  /// Stops recording, finishes pending translations and saves the session.
  Future<Session?> end({required String Function(DateTime) titleFor}) async {
    if (!isActive) return null;
    _state = LiveState.finishing;
    notifyListeners();
    if (usesDeviceEngine) {
      await _stt.stop();
      listeningLang = null;
      partialText = '';
    } else {
      await _sub?.cancel();
      _sub = null;
      await _recorder.stop();
    }
    _clock.stop();
    _ticker?.cancel();
    final vad = _vad;
    if (vad != null && !usesDeviceEngine) {
      vad.flush();
      _drainVad(vad);
    }
    await _queue;
    await WakelockPlus.disable();

    Session? saved;
    if (segments.isNotEmpty) {
      final now = DateTime.now();
      final id = now.millisecondsSinceEpoch.toString();
      final s = Session(
        id: id,
        title: titleFor(now),
        createdAt: now,
        languageA: settings.languageA,
        languageB: settings.languageB,
        durationMs: _clock.elapsedMilliseconds,
        segments: List.of(segments),
      );
      final pcm = _pcm;
      if (pcm != null && pcm.length > 0) {
        s.audioFile = await repository.writeWav(id, pcm.takeBytes());
      }
      await repository.save(s);
      saved = s;
    }
    _pcm = null;
    speechActive = false;
    pendingCount = 0;
    _state = LiveState.idle;
    Breadcrumbs.finish();
    notifyListeners();
    return saved;
  }

  /// Lets the user fix a wrong male/female label.
  void toggleGender(Segment s) {
    s.gender = s.gender == VoiceGender.male ? VoiceGender.female : VoiceGender.male;
    notifyListeners();
  }

  Future<void> readAloud(Segment s) async {
    _ignoreUntil = DateTime.now().add(const Duration(days: 1));
    try {
      await tts.speak(s.translatedText, s.targetLang, s.gender);
    } finally {
      // Ignore the tail of our own voice so it is not translated back.
      _ignoreUntil = DateTime.now().add(const Duration(milliseconds: 400));
    }
  }

  bool _firstAudio = true;
  bool _firstVad = true;

  void _onAudio(Uint8List bytes) {
    if (_state != LiveState.recording) return;
    if (_firstAudio) {
      _firstAudio = false;
      Breadcrumbs.mark('first audio chunk (${bytes.length} bytes)');
    }
    _pcm?.add(bytes);
    final samples = _pcm16ToFloat32(bytes);
    _samplesSeen += samples.length;

    var peak = 0.0;
    for (final v in samples) {
      final a = v.abs();
      if (a > peak) peak = a;
    }
    levels
      ..removeAt(0)
      ..add((peak * 3).clamp(0.05, 1.0));

    final ignore = _ignoreUntil;
    if (ignore != null && DateTime.now().isBefore(ignore)) return;

    final vad = _vad;
    if (vad == null) return;
    if (_firstVad) Breadcrumbs.mark('first VAD input');
    vad.acceptWaveform(samples);
    if (_firstVad) {
      _firstVad = false;
      Breadcrumbs.mark('VAD ok');
    }
    final detected = vad.isDetected();
    if (detected != speechActive) {
      speechActive = detected;
      notifyListeners();
    }
    _drainVad(vad);
  }

  void _drainVad(so.VoiceActivityDetector vad) {
    while (!vad.isEmpty()) {
      final seg = vad.front();
      vad.pop();
      final startMs = seg.start * 1000 ~/ _sampleRate;
      final endMs = startMs + seg.samples.length * 1000 ~/ _sampleRate;
      pendingCount++;
      notifyListeners();
      _queue = _queue.then((_) => _process(seg.samples, startMs, endMs));
    }
  }

  Future<void> _process(Float32List samples, int startMs, int endMs) async {
    try {
      final worker = _worker;
      if (worker == null) return;
      Breadcrumbs.mark('send ${samples.length} samples to Whisper');
      final r = await worker.transcribe(samples);
      Breadcrumbs.mark('Whisper result lang=${r.lang}');
      if (r.text.isEmpty || _isNoise(r.text)) return;

      final a = settings.languageA, b = settings.languageB;
      String source;
      if (r.lang == a || r.lang == b) {
        source = r.lang;
      } else {
        // Whisper heard a language outside the pair: assume turn-taking.
        source = _lastSourceLang == a ? b : a;
      }
      final target = source == a ? b : a;
      _lastSourceLang = source;

      Breadcrumbs.mark('translate $source>$target');
      final translated = await translator.translate(r.text, source, target);
      Breadcrumbs.mark('translated');
      final s = Segment(
        startMs: startMs,
        endMs: endMs,
        sourceLang: source,
        targetLang: target,
        sourceText: r.text,
        translatedText: translated,
        gender: settings.voiceLabels ? r.gender : VoiceGender.unknown,
        pitchHz: r.pitchHz,
      );
      segments.add(s);
      notifyListeners();
      if (settings.autoReadAloud && _state == LiveState.recording) {
        await readAloud(s);
      }
    } catch (e) {
      lastError = e.toString();
    } finally {
      pendingCount = (pendingCount - 1).clamp(0, 1 << 30);
      notifyListeners();
    }
  }

  /// Whisper sometimes hallucinates captions on noise.
  bool _isNoise(String t) {
    final s = t.toLowerCase();
    return s.length < 2 ||
        RegExp(r'^[\s\.\,\!\?…\-]+$').hasMatch(s) ||
        s.contains('subscribe') && s.contains('channel') ||
        s == '[music]' || s == '(music)' || s == '[blank_audio]';
  }

  static Float32List _pcm16ToFloat32(Uint8List bytes) {
    final out = Float32List(bytes.length ~/ 2);
    final bd = ByteData.sublistView(bytes);
    for (var i = 0; i < out.length; i++) {
      out[i] = bd.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return out;
  }

  static String defaultTitle(DateTime t, String localeName) =>
      DateFormat.yMMMd(localeName).add_Hm().format(t);

  int get samplesSeen => _samplesSeen;

  @override
  void dispose() {
    _ticker?.cancel();
    _sub?.cancel();
    _recorder.dispose();
    _worker?.dispose();
    _vad?.free();
    super.dispose();
  }
}

/// Convenience for UI code.
String langPairLabel(String a, String b) =>
    '${languageByCode(a).shortCode} ⇄ ${languageByCode(b).shortCode}';
