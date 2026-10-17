import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/session.dart';

/// Stores sessions as JSON (+ optional WAV) files and handles import/export.
class SessionRepository extends ChangeNotifier {
  SessionRepository._(this._dir);

  final Directory _dir;
  final List<Session> _sessions = [];

  List<Session> get sessions => List.unmodifiable(_sessions);
  Directory get directory => _dir;

  static Future<SessionRepository> open() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'sessions'));
    await dir.create(recursive: true);
    final repo = SessionRepository._(dir);
    await repo._loadAll();
    return repo;
  }

  Future<void> _loadAll() async {
    _sessions.clear();
    await for (final f in _dir.list()) {
      if (f is File && f.path.endsWith('.json')) {
        try {
          final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
          _sessions.add(Session.fromJson(j));
        } catch (e) {
          debugPrint('Skipping unreadable session ${f.path}: $e');
        }
      }
    }
    _sort();
  }

  void _sort() => _sessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));

  File _jsonFile(String id) => File(p.join(_dir.path, '$id.json'));

  File? audioFileOf(Session s) =>
      s.audioFile == null ? null : File(p.join(_dir.path, s.audioFile!));

  Future<void> save(Session s) async {
    await _jsonFile(s.id).writeAsString(jsonEncode(s.toJson()));
    final i = _sessions.indexWhere((x) => x.id == s.id);
    if (i >= 0) {
      _sessions[i] = s;
    } else {
      _sessions.add(s);
    }
    _sort();
    notifyListeners();
  }

  Future<void> delete(Session s) async {
    final json = _jsonFile(s.id);
    if (await json.exists()) await json.delete();
    final audio = audioFileOf(s);
    if (audio != null && await audio.exists()) await audio.delete();
    _sessions.removeWhere((x) => x.id == s.id);
    notifyListeners();
  }

  /// Writes 16 kHz mono PCM16 samples as a WAV file next to the session JSON.
  Future<String> writeWav(String id, Uint8List pcm16, {int sampleRate = 16000}) async {
    final name = '$id.wav';
    final header = ByteData(44);
    final dataLen = pcm16.length;
    void str(int o, String s) {
      for (var i = 0; i < 4; i++) {
        header.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    str(0, 'RIFF');
    header.setUint32(4, 36 + dataLen, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little); // PCM
    header.setUint16(22, 1, Endian.little); // mono
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * 2, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    str(36, 'data');
    header.setUint32(40, dataLen, Endian.little);
    final out = File(p.join(_dir.path, name)).openWrite();
    out.add(header.buffer.asUint8List());
    out.add(pcm16);
    await out.close();
    return name;
  }

  // ---------------------------------------------------------------- export

  Future<File> _tempFile(String name) async {
    final tmp = await getTemporaryDirectory();
    return File(p.join(tmp.path, name));
  }

  String _stamp() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}${two(n.month)}${two(n.day)}-${two(n.hour)}${two(n.minute)}';
  }

  /// Full backup: every session JSON plus its audio, zipped.
  Future<File> exportBackupZip([List<Session>? only]) async {
    final list = only ?? _sessions;
    final archive = Archive();
    final manifest = utf8.encode(jsonEncode({
      'format': 'voice-realtime-translater/backup',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'count': list.length,
    }));
    archive.addFile(ArchiveFile('manifest.json', manifest.length, manifest));
    for (final s in list) {
      final data = utf8.encode(jsonEncode(s.toJson()));
      archive.addFile(ArchiveFile('sessions/${s.id}.json', data.length, data));
      final audio = audioFileOf(s);
      if (audio != null && await audio.exists()) {
        final bytes = await audio.readAsBytes();
        archive.addFile(ArchiveFile('sessions/${s.audioFile}', bytes.length, bytes));
      }
    }
    final List<int>? zipped = ZipEncoder().encode(archive);
    final file = await _tempFile('voice-translater-backup-${_stamp()}.zip');
    await file.writeAsBytes(zipped ?? const <int>[]);
    return file;
  }

  /// All transcripts as one JSON document (no audio).
  Future<File> exportAllJson() async {
    final file = await _tempFile('voice-translater-transcripts-${_stamp()}.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert({
      'format': 'voice-realtime-translater/backup',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'sessions': _sessions.map((s) => s.toJson()).toList(),
    }));
    return file;
  }

  Future<File> exportText(Session s) async {
    final b = StringBuffer()
      ..writeln(s.title)
      ..writeln('${s.createdAt.toLocal()} · ${s.languageA.toUpperCase()} ⇄ ${s.languageB.toUpperCase()}')
      ..writeln();
    for (final seg in s.segments) {
      final who = switch (seg.gender) {
        VoiceGender.male => 'Male',
        VoiceGender.female => 'Female',
        VoiceGender.unknown => 'Speaker',
      };
      b
        ..writeln('[${_clock(seg.startMs)}] $who · ${seg.sourceLang.toUpperCase()} → ${seg.targetLang.toUpperCase()}')
        ..writeln(seg.sourceText)
        ..writeln(seg.translatedText)
        ..writeln();
    }
    final file = await _tempFile('${_safe(s.title)}.txt');
    await file.writeAsString(b.toString());
    return file;
  }

  Future<File> exportSrt(Session s) async {
    final b = StringBuffer();
    var i = 1;
    for (final seg in s.segments) {
      b
        ..writeln(i++)
        ..writeln('${_srtTime(seg.startMs)} --> ${_srtTime(seg.endMs)}')
        ..writeln(seg.translatedText)
        ..writeln(seg.sourceText)
        ..writeln();
    }
    final file = await _tempFile('${_safe(s.title)}.srt');
    await file.writeAsString(b.toString());
    return file;
  }

  // ---------------------------------------------------------------- import

  /// Imports a .zip backup or a .json (single session or backup).
  /// Returns how many new sessions were added; existing ids are skipped.
  Future<int> importFile(File file) async {
    final bytes = await file.readAsBytes();
    final isZip = bytes.length > 4 && bytes[0] == 0x50 && bytes[1] == 0x4B;
    return isZip ? _importZip(bytes) : _importJson(utf8.decode(bytes));
  }

  Future<int> _importJson(String text) async {
    final j = jsonDecode(text);
    final raw = <Map<String, dynamic>>[];
    if (j is Map && j['sessions'] is List) {
      for (final e in j['sessions'] as List) {
        raw.add(Map<String, dynamic>.from(e as Map));
      }
    } else if (j is Map && j['segments'] is List) {
      raw.add(Map<String, dynamic>.from(j));
    } else {
      throw const FormatException('Not a Voice Realtime Translater file');
    }
    var added = 0;
    for (final m in raw) {
      final s = Session.fromJson(m)..audioFile = null;
      if (_sessions.any((x) => x.id == s.id)) continue;
      await save(s);
      added++;
    }
    return added;
  }

  Future<int> _importZip(Uint8List bytes) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    final audio = <String, List<int>>{};
    final jsons = <Map<String, dynamic>>[];
    for (final f in archive.files) {
      if (!f.isFile) continue;
      final name = p.basename(f.name);
      final content = f.content as List<int>;
      if (name.endsWith('.wav')) {
        audio[name] = content;
      } else if (name.endsWith('.json') && name != 'manifest.json') {
        jsons.add(jsonDecode(utf8.decode(content)) as Map<String, dynamic>);
      }
    }
    if (jsons.isEmpty) throw const FormatException('Empty backup');
    var added = 0;
    for (final m in jsons) {
      final s = Session.fromJson(m);
      if (_sessions.any((x) => x.id == s.id)) continue;
      final wavName = s.audioFile;
      if (wavName != null && audio.containsKey(wavName)) {
        await File(p.join(_dir.path, wavName)).writeAsBytes(audio[wavName]!);
      } else {
        s.audioFile = null;
      }
      await save(s);
      added++;
    }
    return added;
  }

  // ---------------------------------------------------------------- helpers

  static String _clock(int ms) {
    final d = Duration(milliseconds: ms);
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  static String _srtTime(int ms) {
    final d = Duration(milliseconds: ms);
    String two(int v) => v.toString().padLeft(2, '0');
    final milli = (ms % 1000).toString().padLeft(3, '0');
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)},$milli';
  }

  static String _safe(String s) {
    final cleaned = s.replaceAll(RegExp(r'[^\p{L}\p{N} _-]', unicode: true), '').trim();
    return cleaned.isEmpty ? 'transcript' : cleaned;
  }
}
