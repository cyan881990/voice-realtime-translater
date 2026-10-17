import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_scope.dart';
import 'core/diagnostics.dart';
import 'core/theme.dart';
import 'l10n/app_localizations.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/setup_screen.dart';
import 'ui/widgets/update_sheet.dart';

class VoiceTranslaterApp extends StatelessWidget {
  const VoiceTranslaterApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.services.settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        title: 'Voice Realtime Translater',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: settings.themeMode,
        locale: settings.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => DiagnosticsOverlay(child: child ?? const SizedBox.shrink()),
        home: const StartupGate(),
      ),
    );
  }
}

/// Shows the one-time model download, then the main screen.
class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  bool? _ready;

  @override
  void initState() {
    super.initState();
    _check();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startBackgroundServices());
  }

  Future<void> _check() async {
    final s = context.services;
    var ok = false;
    try {
      ok = await s.models.speechReady() &&
          await s.models.translationReady(s.settings.languageA, s.settings.languageB);
    } catch (e, st) {
      Diagnostics.record(e, st, where: 'startup-check');
    }
    if (mounted) setState(() => _ready = ok);
  }

  Future<void> _startBackgroundServices() async {
    final s = context.services;
    s.ads.init().catchError((Object e, StackTrace st) => Diagnostics.record(e, st, where: 'ads'));
    s.purchases.init().catchError((Object e, StackTrace st) => Diagnostics.record(e, st, where: 'purchases'));
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final info = await s.updates.check(localeCode: s.settings.locale.languageCode);
    if (!mounted || info == null) return;
    if (!info.mandatory && s.settings.dismissedUpdateVersion == info.latestVersion) return;
    // Never interrupt an active recording with the update prompt.
    if (s.live.isActive) return;
    await showUpdateSheet(context, info);
  }

  @override
  Widget build(BuildContext context) {
    final ready = _ready;
    if (ready == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!ready) {
      return SetupScreen(onDone: () => setState(() => _ready = true));
    }
    return const HomeScreen();
  }
}
