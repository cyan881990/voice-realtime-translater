import 'package:flutter/widgets.dart';

import '../data/session_repository.dart';
import '../services/ads_service.dart';
import '../services/live_session_controller.dart';
import '../services/model_manager.dart';
import '../services/purchase_service.dart';
import '../services/translator_service.dart';
import '../services/tts_service.dart';
import '../services/update_service.dart';
import 'settings_controller.dart';

/// All long-lived services, created once in main().
class AppServices {
  AppServices({
    required this.settings,
    required this.repository,
    required this.models,
    required this.translator,
    required this.tts,
    required this.live,
    required this.ads,
    required this.purchases,
    required this.updates,
  });

  final SettingsController settings;
  final SessionRepository repository;
  final ModelManager models;
  final TranslatorService translator;
  final TtsService tts;
  final LiveSessionController live;
  final AdsService ads;
  final PurchaseService purchases;
  final UpdateService updates;
}

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  static AppServices of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.services;

  @override
  bool updateShouldNotify(AppScope oldWidget) => services != oldWidget.services;
}

extension AppScopeX on BuildContext {
  AppServices get services => AppScope.of(this);
}
