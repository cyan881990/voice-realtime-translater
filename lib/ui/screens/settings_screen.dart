import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_scope.dart';
import '../../core/config.dart';
import '../../core/languages.dart';
import '../../core/settings_controller.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/app_logo.dart';
import '../widgets/update_sheet.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    final t = AppLocalizations.of(context);
    final c = context.colors;
    final st = s.settings;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.settings),
        actions: const [Padding(padding: EdgeInsets.only(right: 16), child: AppLogo(size: 32))],
      ),
      body: ListenableBuilder(
        listenable: st,
        builder: (context, _) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                if (!st.adsRemoved) _RemoveAdsCard(),
                _Section(title: t.general, children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text(t.appearance, style: const TextStyle(fontSize: 15)),
                      const SizedBox(height: 10),
                      SegmentedButton<ThemeMode>(
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(value: ThemeMode.system, label: Text(t.themeSystem)),
                          ButtonSegment(value: ThemeMode.light, label: Text(t.themeLight)),
                          ButtonSegment(value: ThemeMode.dark, label: Text(t.themeDark)),
                        ],
                        selected: {st.themeMode},
                        onSelectionChanged: (v) => st.themeMode = v.first,
                      ),
                    ]),
                  ),
                  ListTile(
                    title: Text(t.appLanguage),
                    trailing: Text(
                      st.locale.languageCode == 'vi' ? 'Tiếng Việt' : t.appLanguageDefault,
                      style: TextStyle(color: c.muted),
                    ),
                    onTap: () => _pickAppLanguage(context),
                  ),
                  ListTile(
                    title: Text(t.appUpdates),
                    trailing: Text(t.checkNow, style: TextStyle(color: c.accentText)),
                    onTap: () => checkForUpdatesManually(context),
                  ),
                ]),
                _Section(title: t.translation, children: [
                  ListTile(
                    title: Text(t.languagePair),
                    trailing: Text(
                      '${languageByCode(st.languageA).shortCode} ⇄ ${languageByCode(st.languageB).shortCode}',
                      style: TextStyle(color: c.muted),
                    ),
                  ),
                  ListTile(
                    title: Text(t.offlinePacks),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const LanguagePacksScreen()),
                    ),
                  ),
                  SwitchListTile(
                    title: Text(t.voiceLabels),
                    value: st.voiceLabels,
                    onChanged: (v) => st.voiceLabels = v,
                  ),
                  SwitchListTile(
                    title: Text(t.readTranslationAloud),
                    value: st.autoReadAloud,
                    onChanged: (v) => st.autoReadAloud = v,
                  ),
                  SwitchListTile(
                    title: Text(t.saveAudio),
                    value: st.saveAudio,
                    onChanged: (v) => st.saveAudio = v,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Row(children: [
                      Expanded(child: Text(t.silenceBreak, style: const TextStyle(fontSize: 15))),
                      Text(t.seconds(st.silenceSeconds.toStringAsFixed(1)),
                          style: TextStyle(color: c.muted)),
                    ]),
                  ),
                  Slider(
                    value: st.silenceSeconds,
                    min: 0.3,
                    max: 1.5,
                    divisions: 12,
                    label: t.seconds(st.silenceSeconds.toStringAsFixed(1)),
                    onChanged: (v) => st.silenceSeconds = v,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text(t.speechModel, style: const TextStyle(fontSize: 15)),
                      const SizedBox(height: 10),
                      SegmentedButton<SpeechModelSize>(
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(value: SpeechModelSize.tiny, label: Text(t.modelTiny)),
                          ButtonSegment(value: SpeechModelSize.base, label: Text(t.modelBase)),
                        ],
                        selected: {st.modelSize},
                        onSelectionChanged: s.live.isActive
                            ? null
                            : (v) async {
                                st.modelSize = v.first;
                                if (!await s.models.speechReady() && context.mounted) {
                                  await _downloadModel(context);
                                }
                              },
                      ),
                    ]),
                  ),
                ]),
                _Section(title: '', children: [
                  ListTile(
                    title: Text(t.privacyPolicy),
                    trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                    onTap: () => launchUrl(Uri.parse(AppConfig.privacyPolicyUrl),
                        mode: LaunchMode.externalApplication),
                  ),
                  if (!st.adsRemoved)
                    ListTile(
                      title: Text(t.restorePurchases),
                      onTap: () => s.purchases.restore(),
                    ),
                ]),
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snap) => Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${t.appTitle} · ${t.version(snap.data?.version ?? '')}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: c.muted),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickAppLanguage(BuildContext context) async {
    final st = context.services.settings;
    final code = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          title: const Text('English'),
          trailing: st.locale.languageCode == 'en' ? const Icon(Icons.check_rounded) : null,
          onTap: () => Navigator.of(ctx).pop('en'),
        ),
        ListTile(
          title: const Text('Tiếng Việt'),
          trailing: st.locale.languageCode == 'vi' ? const Icon(Icons.check_rounded) : null,
          onTap: () => Navigator.of(ctx).pop('vi'),
        ),
        const SizedBox(height: 12),
      ]),
    );
    if (code != null) st.locale = Locale(code);
  }

  Future<void> _downloadModel(BuildContext context) async {
    final s = context.services;
    final t = AppLocalizations.of(context);
    final progress = ValueNotifier<double?>(null);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: ValueListenableBuilder<double?>(
          valueListenable: progress,
          builder: (_, v, __) => Column(mainAxisSize: MainAxisSize.min, children: [
            Text(t.setupDownloading(t.speechModel)),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: v),
          ]),
        ),
      ),
    );
    try {
      await s.models.ensureAll(
        languageA: s.settings.languageA,
        languageB: s.settings.languageB,
        onProgress: (_, p) => progress.value = p < 0 ? null : p,
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.setupFailed)));
      }
    } finally {
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}

class _RemoveAdsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.services;
    final t = AppLocalizations.of(context);
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 16, top: 8),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(20)),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.removeAds, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(t.removeAdsSub, style: TextStyle(fontSize: 12, color: c.muted)),
          ]),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: () => s.purchases.buyRemoveAds(),
          child: Text(s.purchases.price ?? t.removeAds.split(' ').first,
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 4),
            child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.muted)),
          ),
        Material(
          color: c.surface1,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 16),
              children[i],
            ],
          ]),
        ),
      ]),
    );
  }
}

/// Download or remove ML Kit translation packs.
class LanguagePacksScreen extends StatefulWidget {
  const LanguagePacksScreen({super.key});

  @override
  State<LanguagePacksScreen> createState() => _LanguagePacksScreenState();
}

class _LanguagePacksScreenState extends State<LanguagePacksScreen> {
  final Map<String, bool> _state = {};
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final m = context.services.models;
    for (final l in kSpeechLanguages) {
      _state[l.code] = await m.isPackDownloaded(l.code);
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final c = context.colors;
    final m = context.services.models;
    final count = _state.values.where((v) => v).length;
    return Scaffold(
      appBar: AppBar(title: Text(t.offlinePacks)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 4),
                child: Text(t.packsDownloaded(count), style: TextStyle(color: c.muted)),
              ),
              Material(
                color: c.surface1,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: Column(children: [
                  for (final l in kSpeechLanguages)
                    ListTile(
                      title: Text(l.nativeName),
                      subtitle: Text(l.shortCode),
                      trailing: _busy.contains(l.code)
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : (_state[l.code] ?? false)
                              ? Text(t.downloaded,
                                  style: TextStyle(
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? Brand.teal
                                          : const Color(0xFF0F7A68)))
                              : TextButton.icon(
                                  onPressed: () async {
                                    setState(() => _busy.add(l.code));
                                    await m.downloadPack(l.code);
                                    _busy.remove(l.code);
                                    await _refresh();
                                  },
                                  icon: const Icon(Icons.download_rounded, size: 18),
                                  label: Text('${t.download} ~30 MB'),
                                ),
                    ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
