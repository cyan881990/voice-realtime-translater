import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/settings_controller.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/app_logo.dart';

/// One-time download of the speech model and translation packs.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  bool _busy = false;
  String? _label;
  double? _progress;
  bool _failed = false;

  Future<void> _run() async {
    final s = context.services;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await s.models.ensureAll(
        languageA: s.settings.languageA,
        languageB: s.settings.languageB,
        onProgress: (label, p) {
          if (mounted) {
            setState(() {
              _label = label;
              _progress = p < 0 ? null : p;
            });
          }
        },
      );
      widget.onDone();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final c = context.colors;
    final settings = context.services.settings;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(24),
              shrinkWrap: true,
              children: [
                const Center(child: AppLogo(size: 96)),
                const SizedBox(height: 20),
                Text(t.appTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 24),
                Text(t.setupTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(t.setupBody, style: TextStyle(color: c.muted, height: 1.5)),
                const SizedBox(height: 20),
                ListenableBuilder(
                  listenable: settings,
                  builder: (context, _) => SegmentedButton<SpeechModelSize>(
                    segments: [
                      ButtonSegment(value: SpeechModelSize.tiny, label: Text(t.modelTiny)),
                      ButtonSegment(value: SpeechModelSize.base, label: Text(t.modelBase)),
                    ],
                    selected: {settings.modelSize},
                    onSelectionChanged: _busy ? null : (v) => settings.modelSize = v.first,
                    showSelectedIcon: false,
                  ),
                ),
                const SizedBox(height: 8),
                Text(t.setupWifi, style: TextStyle(color: c.muted, fontSize: 12)),
                const SizedBox(height: 24),
                if (_busy) ...[
                  Text(t.setupDownloading(_label ?? ''), style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: _progress, minHeight: 6, borderRadius: BorderRadius.circular(3)),
                ] else ...[
                  if (_failed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(t.setupFailed, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ),
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: _run,
                    child: Text(_failed ? t.retry : t.setupStart,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
