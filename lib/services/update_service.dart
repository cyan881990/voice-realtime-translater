import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config.dart';

enum UpdateChannel { playInApp, appStore, link }

class UpdateInfo {
  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.notes,
    required this.channel,
    this.url,
    this.mandatory = false,
  });
  final String currentVersion;
  final String latestVersion;
  final String notes;
  final UpdateChannel channel;
  final String? url;
  final bool mandatory;
}

/// Detects new versions and installs them:
/// * Android from Google Play: Play in-app updates (flexible, background download).
/// * iOS: App Store lookup, then opens the store page.
/// * Test builds / fallback: `update.json` hosted with the privacy policy.
class UpdateService {
  Future<UpdateInfo?> check({required String localeCode}) async {
    final info = await PackageInfo.fromPlatform();
    final current = info.version;

    if (Platform.isAndroid) {
      try {
        final play = await InAppUpdate.checkForUpdate();
        if (play.updateAvailability == UpdateAvailability.updateAvailable) {
          return UpdateInfo(
            currentVersion: current,
            latestVersion: play.availableVersionCode?.toString() ?? '',
            notes: '',
            channel: UpdateChannel.playInApp,
          );
        }
      } catch (_) {
        // Not installed from Google Play (e.g. a test APK): use the manifest.
      }
    }

    if (Platform.isIOS) {
      try {
        final res = await http
            .get(Uri.parse('https://itunes.apple.com/lookup?bundleId=${AppConfig.bundleId}'))
            .timeout(const Duration(seconds: 8));
        final j = jsonDecode(res.body) as Map<String, dynamic>;
        final results = (j['results'] as List?) ?? const [];
        if (results.isNotEmpty) {
          final r = results.first as Map<String, dynamic>;
          final latest = r['version'] as String? ?? current;
          if (isNewer(latest, current)) {
            return UpdateInfo(
              currentVersion: current,
              latestVersion: latest,
              notes: r['releaseNotes'] as String? ?? '',
              channel: UpdateChannel.appStore,
              url: r['trackViewUrl'] as String?,
            );
          }
          return null;
        }
      } catch (_) {}
    }

    try {
      final res = await http
          .get(Uri.parse(AppConfig.updateManifestUrl))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final latest = j['latestVersion'] as String? ?? current;
      if (!isNewer(latest, current)) return null;
      final notesMap = (j['notes'] as Map?)?.cast<String, dynamic>() ?? const {};
      final url = Platform.isIOS ? j['iosUrl'] as String? : j['androidUrl'] as String?;
      final minVersion = j['minVersion'] as String?;
      return UpdateInfo(
        currentVersion: current,
        latestVersion: latest,
        notes: (notesMap[localeCode] ?? notesMap['en'] ?? '') as String,
        channel: UpdateChannel.link,
        url: url,
        mandatory: minVersion != null && isNewer(minVersion, current),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> install(UpdateInfo u) async {
    switch (u.channel) {
      case UpdateChannel.playInApp:
        final r = await InAppUpdate.startFlexibleUpdate();
        if (r == AppUpdateResult.success) {
          await InAppUpdate.completeFlexibleUpdate();
        }
      case UpdateChannel.appStore:
      case UpdateChannel.link:
        final url = u.url;
        if (url != null) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        }
    }
  }

  /// Semantic version comparison: 1.10.0 > 1.9.3.
  static bool isNewer(String a, String b) {
    List<int> parse(String v) =>
        v.split('+').first.split('.').map((x) => int.tryParse(x) ?? 0).toList();
    final x = parse(a), y = parse(b);
    for (var i = 0; i < 3; i++) {
      final xi = i < x.length ? x[i] : 0;
      final yi = i < y.length ? y[i] : 0;
      if (xi != yi) return xi > yi;
    }
    return false;
  }
}
