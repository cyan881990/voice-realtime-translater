import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Collects uncaught errors so testers can see and copy them on screen
/// instead of the app silently closing or freezing.
class Diagnostics {
  Diagnostics._();

  static final ValueNotifier<List<String>> errors = ValueNotifier(const []);

  static void record(Object error, StackTrace? stack, {String where = ''}) {
    final text = [
      if (where.isNotEmpty) '[$where]',
      error.toString(),
      if (stack != null) stack.toString().split('\n').take(12).join('\n'),
    ].join('\n');
    debugPrint(text);
    errors.value = [...errors.value, text].take(20).toList();
  }

  static void install() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      record(details.exception, details.stack, where: details.library ?? 'flutter');
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      record(error, stack, where: 'platform');
      return true;
    };
    ErrorWidget.builder = (details) => Material(
          color: const Color(0xFF3A0D0D),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              details.exceptionAsString(),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        );
  }
}

/// Small floating button that appears when an error was recorded.
class DiagnosticsOverlay extends StatelessWidget {
  const DiagnosticsOverlay({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      child,
      ValueListenableBuilder<List<String>>(
        valueListenable: Diagnostics.errors,
        builder: (context, list, _) {
          if (list.isEmpty) return const SizedBox.shrink();
          return Positioned(
            right: 12,
            top: MediaQuery.paddingOf(context).top + 8,
            child: FloatingActionButton.small(
              heroTag: 'diag',
              backgroundColor: const Color(0xFFE5484D),
              foregroundColor: Colors.white,
              tooltip: 'Error details',
              onPressed: () => showErrorDetails(context, list.join('\n\n---\n\n')),
              child: const Icon(Icons.bug_report_rounded),
            ),
          );
        },
      ),
    ]);
  }
}

Future<void> showErrorDetails(BuildContext context, String text) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Error details'),
      content: SingleChildScrollView(
        child: SelectableText(text, style: const TextStyle(fontSize: 12)),
      ),
      actions: [
        TextButton(
          onPressed: () => Clipboard.setData(ClipboardData(text: text)),
          child: const Text('Copy'),
        ),
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
      ],
    ),
  );
}

/// Shown when startup itself fails.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0E141B),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Voice Realtime Translater could not start',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text('Please send a screenshot of this screen to the developer.',
                  style: TextStyle(color: Color(0xFF9AA8B6))),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(error,
                      style: const TextStyle(color: Color(0xFFFFB4B4), fontSize: 12)),
                ),
              ),
              FilledButton(
                onPressed: () => Clipboard.setData(ClipboardData(text: error)),
                child: const Text('Copy error'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
