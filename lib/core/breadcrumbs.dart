import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Writes the current step to a file synchronously, so if a native library
/// crashes the process, the next launch can tell which step it was.
class Breadcrumbs {
  Breadcrumbs._();

  static String? _path;
  static String? get path => _path;

  static Future<void> init() async {
    final dir = await getApplicationSupportDirectory();
    _path = p.join(dir.path, 'breadcrumbs.txt');
  }

  /// Use from background isolates, which get the path as a message.
  static void markAt(String? path, String step) {
    if (path == null) return;
    try {
      File(path).writeAsStringSync('${DateTime.now().toIso8601String()} $step\n',
          mode: FileMode.append, flush: true);
    } catch (_) {}
  }

  static void mark(String step) => markAt(_path, step);

  static void begin(String what) {
    final path = _path;
    if (path == null) return;
    try {
      File(path).writeAsStringSync('${DateTime.now().toIso8601String()} BEGIN $what\n', flush: true);
    } catch (_) {}
  }

  static void finish() => mark('OK');

  /// Returns a report if the last session did not finish cleanly.
  static Future<String?> previousCrashReport() async {
    final path = _path;
    if (path == null) return null;
    final f = File(path);
    final parts = <String>[];
    if (await f.exists()) {
      final lines = (await f.readAsString()).trim().split('\n');
      if (lines.isNotEmpty && lines.last.isNotEmpty && !lines.last.endsWith(' OK')) {
        parts.add('The app closed during this step:\n${lines.last}\n\nRecent steps:\n'
            '${lines.skip(lines.length > 15 ? lines.length - 15 : 0).join('\n')}');
      }
      await f.delete();
    }
    final exit = File(p.join(p.dirname(path), 'last_exit.txt'));
    if (await exit.exists()) {
      final text = (await exit.readAsString()).trim();
      if (parts.isNotEmpty && text.isNotEmpty) parts.add('System exit info:\n$text');
      await exit.delete();
    }
    return parts.isEmpty ? null : parts.join('\n\n');
  }
}
