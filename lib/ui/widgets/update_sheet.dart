import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../services/update_service.dart';
import 'app_logo.dart';

Future<void> showUpdateSheet(BuildContext context, UpdateInfo info) {
  return showModalBottomSheet<void>(
    context: context,
    isDismissible: !info.mandatory,
    enableDrag: !info.mandatory,
    showDragHandle: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (context) => _UpdateSheet(info: info),
  );
}

class _UpdateSheet extends StatelessWidget {
  const _UpdateSheet({required this.info});
  final UpdateInfo info;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final c = context.colors;
    final s = context.services;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const AppLogo(size: 56),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.updateAvailable,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                if (info.latestVersion.isNotEmpty)
                  Text(t.updateVersion(info.latestVersion, info.currentVersion),
                      style: TextStyle(color: c.muted, fontSize: 13)),
              ]),
            ),
          ]),
          if (info.notes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.surface2,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.whatsNew, style: TextStyle(color: c.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(info.notes, style: const TextStyle(fontSize: 14, height: 1.5)),
              ]),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: () async {
              Navigator.of(context).pop();
              await s.updates.install(info);
            },
            child: Text(t.updateNow, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          if (!info.mandatory)
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: () {
                s.settings.dismissedUpdateVersion = info.latestVersion;
                Navigator.of(context).pop();
              },
              child: Text(t.later),
            ),
          const SizedBox(height: 4),
          Text(t.updateHint,
              textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 12, height: 1.5)),
        ],
      ),
    );
  }
}

/// Small helper so screens can trigger a manual check.
Future<void> checkForUpdatesManually(BuildContext context) async {
  final s = context.services;
  final t = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final info = await s.updates.check(localeCode: s.settings.locale.languageCode);
  if (!context.mounted) return;
  if (info == null) {
    messenger.showSnackBar(SnackBar(content: Text(t.upToDate)));
  } else {
    await showUpdateSheet(context, info);
  }
}
