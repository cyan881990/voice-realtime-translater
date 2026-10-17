import 'dart:io';

import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/languages.dart';
import '../core/settings_controller.dart';

/// Paths of the on-device speech models.
class AsrModelPaths {
  const AsrModelPaths({
    required this.vad,
    required this.encoder,
    required this.decoder,
    required this.tokens,
  });
  final String vad;
  final String encoder;
  final String decoder;
  final String tokens;
}

class _RemoteFile {
  const _RemoteFile(this.name, this.url);
  final String name;
  final String url;
}

/// Downloads the free, open-source speech models (Silero VAD + Whisper via
/// sherpa-onnx) and the ML Kit translation packs, once.
class ModelManager {
  ModelManager(this._settings);

  final SettingsController _settings;
  final _translationModels = OnDeviceTranslatorModelManager();

  static const _vadUrl =
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/silero_vad.onnx';

  String get _whisperName => _settings.modelSize == SpeechModelSize.base ? 'base' : 'tiny';

  List<_RemoteFile> get _files {
    final n = _whisperName;
    final base = 'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-$n/resolve/main';
    return [
      const _RemoteFile('silero_vad.onnx', _vadUrl),
      _RemoteFile('$n-encoder.int8.onnx', '$base/$n-encoder.int8.onnx'),
      _RemoteFile('$n-decoder.int8.onnx', '$base/$n-decoder.int8.onnx'),
      _RemoteFile('$n-tokens.txt', '$base/$n-tokens.txt'),
    ];
  }

  Future<Directory> _dir() async {
    final support = await getApplicationSupportDirectory();
    final d = Directory(p.join(support.path, 'models'));
    await d.create(recursive: true);
    return d;
  }

  Future<AsrModelPaths> paths() async {
    final d = (await _dir()).path;
    final n = _whisperName;
    return AsrModelPaths(
      vad: p.join(d, 'silero_vad.onnx'),
      encoder: p.join(d, '$n-encoder.int8.onnx'),
      decoder: p.join(d, '$n-decoder.int8.onnx'),
      tokens: p.join(d, '$n-tokens.txt'),
    );
  }

  Future<bool> speechReady() async {
    final d = (await _dir()).path;
    for (final f in _files) {
      if (!await File(p.join(d, f.name)).exists()) return false;
    }
    return true;
  }

  Future<bool> translationReady(String a, String b) async {
    for (final code in {a, b}) {
      if (code == 'en') continue; // English is bundled with ML Kit.
      final ok = await _translationModels.isModelDownloaded(languageByCode(code).mlkit.bcpCode);
      if (!ok) return false;
    }
    return true;
  }

  Future<bool> isPackDownloaded(String code) async {
    if (code == 'en') return true;
    return _translationModels.isModelDownloaded(languageByCode(code).mlkit.bcpCode);
  }

  Future<bool> downloadPack(String code) async {
    if (code == 'en') return true;
    return _translationModels.downloadModel(languageByCode(code).mlkit.bcpCode,
        isWifiRequired: false);
  }

  Future<void> deletePack(String code) async {
    if (code == 'en') return;
    await _translationModels.deleteModel(languageByCode(code).mlkit.bcpCode);
  }

  /// Downloads whatever is missing. [onProgress] receives a label and 0..1.
  Future<void> ensureAll({
    required String languageA,
    required String languageB,
    required void Function(String label, double progress) onProgress,
  }) async {
    final d = (await _dir()).path;
    final client = http.Client();
    try {
      for (final f in _files) {
        final target = File(p.join(d, f.name));
        if (await target.exists()) continue;
        final part = File('${target.path}.part');
        final res = await client.send(http.Request('GET', Uri.parse(f.url)));
        if (res.statusCode != 200) {
          throw HttpException('HTTP ${res.statusCode} for ${f.name}');
        }
        final total = res.contentLength ?? 0;
        var received = 0;
        final sink = part.openWrite();
        await for (final chunk in res.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) onProgress(f.name, received / total);
        }
        await sink.close();
        await part.rename(target.path);
      }
    } finally {
      client.close();
    }
    for (final code in {languageA, languageB}) {
      if (await isPackDownloaded(code)) continue;
      onProgress(languageByCode(code).nativeName, -1);
      final ok = await downloadPack(code);
      if (!ok) throw StateError('Translation pack $code failed');
    }
  }
}
