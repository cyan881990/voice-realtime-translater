import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/app_scope.dart';
import 'core/breadcrumbs.dart';
import 'core/diagnostics.dart';
import 'core/settings_controller.dart';
import 'data/session_repository.dart';
import 'services/ads_service.dart';
import 'services/live_session_controller.dart';
import 'services/model_manager.dart';
import 'services/purchase_service.dart';
import 'services/translator_service.dart';
import 'services/tts_service.dart';
import 'services/update_service.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    Diagnostics.install();
    try {
      await Breadcrumbs.init();
      final settings = await SettingsController.load();
      final repository = await SessionRepository.open();
      final models = ModelManager(settings);
      final translator = TranslatorService();
      final tts = TtsService();
      final services = AppServices(
        settings: settings,
        repository: repository,
        models: models,
        translator: translator,
        tts: tts,
        live: LiveSessionController(
          settings: settings,
          models: models,
          repository: repository,
          translator: translator,
          tts: tts,
        ),
        ads: AdsService(settings),
        purchases: PurchaseService(settings),
        updates: UpdateService(),
      );
      runApp(AppScope(services: services, child: const VoiceTranslaterApp()));
    } catch (e, st) {
      runApp(StartupErrorApp(error: '$e\n\n$st'));
    }
  }, (error, stack) => Diagnostics.record(error, stack, where: 'zone'));
}
