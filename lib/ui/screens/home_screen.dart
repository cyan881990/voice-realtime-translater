import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/app_scope.dart';
import '../../core/languages.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/session.dart';
import '../../services/ads_service.dart';
import '../../services/live_session_controller.dart';
import '../widgets/app_logo.dart';
import '../widgets/segment_bubble.dart';
import 'history_screen.dart';
import 'session_detail_screen.dart';
import 'settings_screen.dart';

/// Breakpoint above which the app shows history and the live view side by side
/// (tablets, foldables, landscape).
const double kWideLayout = 840;

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth >= kWideLayout;
      return Scaffold(
        appBar: wide ? _WideAppBar() : null,
        body: SafeArea(
          bottom: false,
          child: wide
              ? Row(children: [
                  SizedBox(
                    width: 360,
                    child: Material(
                      color: context.colors.surface1,
                      child: const HistoryPanel(embedded: true),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  const Expanded(child: LivePanel(showHeader: false)),
                ])
              : const LivePanel(showHeader: true),
        ),
        bottomNavigationBar: ListenableBuilder(
          listenable: s.settings,
          builder: (context, _) => BannerAdSlot(settings: s.settings),
        ),
      );
    });
  }
}

class _WideAppBar extends StatelessWidget implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(68);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return AppBar(
      toolbarHeight: 68,
      titleSpacing: 20,
      title: Row(children: [
        const AppLogo(size: 40),
        const SizedBox(width: 12),
        Text(t.appTitle),
      ]),
      actions: [
        IconButton(
          tooltip: t.settings,
          icon: const Icon(Icons.tune_rounded),
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
        ),
        const SizedBox(width: 12),
      ],
    );
  }
}

class LivePanel extends StatelessWidget {
  const LivePanel({super.key, required this.showHeader});
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListenableBuilder(
          listenable: Listenable.merge([s.live, s.settings]),
          builder: (context, _) => Column(children: [
            if (showHeader) const _CompactHeader(),
            const _PairCard(),
            const _Chips(),
            const Expanded(child: _Conversation()),
            const _Controls(),
          ]),
        ),
      ),
    );
  }
}

class _CompactHeader extends StatelessWidget {
  const _CompactHeader();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
      child: Row(children: [
        const AppLogo(size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.appTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.accentText)),
            Text(t.homeTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          ]),
        ),
        _RoundIcon(
          icon: Icons.history_rounded,
          tooltip: t.history,
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => const HistoryScreen())),
        ),
        const SizedBox(width: 8),
        _RoundIcon(
          icon: Icons.tune_rounded,
          tooltip: t.settings,
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
        ),
      ]),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton.filledTonal(
        tooltip: tooltip,
        style: IconButton.styleFrom(
          backgroundColor: context.colors.surface1,
          minimumSize: const Size(44, 44),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 22),
      );
}

class _PairCard extends StatelessWidget {
  const _PairCard();

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    final t = AppLocalizations.of(context);
    final c = context.colors;
    final a = languageByCode(s.settings.languageA);
    final b = languageByCode(s.settings.languageB);
    final lastLang = s.live.segments.isEmpty ? null : s.live.segments.last.sourceLang;
    final locked = s.live.isActive;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: c.surface1, borderRadius: BorderRadius.circular(18)),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: Text(t.autoDetect,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.muted)),
          ),
          Flexible(
            child: Text(t.speakEither,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: c.muted)),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: _LangButton(
              lang: a,
              active: lastLang == a.code && locked,
              onTap: locked ? null : () => _pick(context, isA: true),
            ),
          ),
          IconButton(
            tooltip: '${a.nativeName} ⇄ ${b.nativeName}',
            onPressed: locked
                ? null
                : () {
                    final oldA = s.settings.languageA;
                    s.settings.languageA = s.settings.languageB;
                    s.settings.languageB = oldA;
                  },
            icon: Icon(Icons.swap_horiz_rounded, color: c.muted),
          ),
          Expanded(
            child: _LangButton(
              lang: b,
              active: lastLang == b.code && locked,
              onTap: locked ? null : () => _pick(context, isA: false),
            ),
          ),
        ]),
      ]),
    );
  }

  Future<void> _pick(BuildContext context, {required bool isA}) async {
    final s = context.services;
    final other = isA ? s.settings.languageB : s.settings.languageA;
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          for (final l in kSpeechLanguages.where((l) => l.code != other))
            ListTile(
              title: Text(l.nativeName),
              trailing: Text(l.shortCode),
              onTap: () => Navigator.of(context).pop(l.code),
            ),
        ],
      ),
    );
    if (picked == null || !context.mounted) return;
    if (!await s.models.isPackDownloaded(picked)) {
      if (!context.mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      final ok = await s.models.downloadPack(picked);
      if (!context.mounted) return;
      Navigator.of(context).pop();
      if (!ok) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).setupFailed)));
        return;
      }
    }
    if (isA) {
      s.settings.languageA = picked;
    } else {
      s.settings.languageB = picked;
    }
  }
}

class _LangButton extends StatelessWidget {
  const _LangButton({required this.lang, required this.active, this.onTap});
  final SpeechLanguage lang;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: active ? Brand.amber : c.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (active) ...[
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: Brand.amber, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(lang.nativeName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Chips extends StatelessWidget {
  const _Chips();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final c = context.colors;
    final s = context.services;
    Widget chip(Widget child) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: c.surface1, borderRadius: BorderRadius.circular(99)),
          child: DefaultTextStyle.merge(style: TextStyle(fontSize: 12, color: c.muted), child: child),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          chip(Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(color: Color(0xFF2BB39A), shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(t.offlineFree),
          ])),
          if (s.settings.voiceLabels) chip(Text(t.voiceDetection)),
        ]),
      ),
    );
  }
}

class _Conversation extends StatelessWidget {
  const _Conversation();

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    final live = s.live;
    final t = AppLocalizations.of(context);
    final c = context.colors;
    final segs = live.segments;
    final showPending = live.isActive && (live.speechActive || live.pendingCount > 0);
    if (segs.isEmpty && !showPending) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(t.tapToStart,
              textAlign: TextAlign.center, style: TextStyle(color: c.muted, height: 1.5)),
        ),
      );
    }
    final items = segs.reversed.toList();
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      itemCount: items.length + (showPending ? 1 : 0),
      itemBuilder: (context, i) {
        if (showPending && i == 0) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: c.surface1,
                border: Border.all(color: Brand.amber),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(
                    width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 10),
                Text(live.speechActive ? t.listening : t.processing,
                    style: TextStyle(color: c.accentText, fontSize: 13)),
              ]),
            ),
          );
        }
        final seg = items[i - (showPending ? 1 : 0)];
        return SegmentBubble(
          segment: seg,
          alignRight: seg.sourceLang == s.settings.languageB,
          showGender: s.settings.voiceLabels,
          onToggleGender: () => live.toggleGender(seg),
          onSpeak: () => live.readAloud(seg),
        );
      },
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls();

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    final live = s.live;
    final t = AppLocalizations.of(context);
    final c = context.colors;
    final recording = live.state == LiveState.recording;
    final paused = live.state == LiveState.paused;
    final busy = live.state == LiveState.starting || live.state == LiveState.finishing;
    final e = live.elapsed;
    final clock =
        '${e.inMinutes.toString().padLeft(2, '0')}:${(e.inSeconds % 60).toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
      decoration: BoxDecoration(
        color: c.surface1,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (live.isActive) ...[
            Row(children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: recording ? Brand.recording : c.muted,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(clock,
                  style: const TextStyle(fontSize: 15, fontFeatures: [FontFeature.tabularFigures()])),
              const Spacer(),
              Flexible(
                child: Text(t.recordingNoAds,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: c.muted)),
              ),
            ]),
            const SizedBox(height: 10),
            SizedBox(
              height: 32,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final l in live.levels)
                    Container(
                      width: 3,
                      height: 4 + 28 * (recording ? l : 0.05),
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        color: Brand.amber,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            mainAxisAlignment:
                live.isActive ? MainAxisAlignment.spaceBetween : MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (live.isActive)
                _SmallAction(
                  icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  label: paused ? t.resume : t.pause,
                  onTap: busy ? null : () => paused ? live.resume() : live.pause(),
                ),
              _MainButton(
                active: live.isActive,
                busy: busy,
                label: live.isActive ? t.end : t.start,
                onTap: busy ? null : () => live.isActive ? _end(context) : _start(context),
              ),
              if (live.isActive)
                _SmallAction(
                  icon: Icons.volume_up_rounded,
                  label: t.readAloud,
                  highlighted: true,
                  onTap: live.segments.isEmpty ? null : () => live.readAloud(live.segments.last),
                ),
            ],
          ),
        ]),
      ),
    );
  }

  Future<void> _start(BuildContext context) async {
    final s = context.services;
    final t = AppLocalizations.of(context);
    await s.live.start();
    if (!context.mounted) return;
    final err = s.live.lastError;
    if (err != null && err.contains('mic-permission')) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(t.micPermission),
        action: SnackBarAction(label: t.openSettings, onPressed: openAppSettings),
      ));
    } else if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  /// End → wait for the last translations → save → (only now) interstitial ad.
  Future<void> _end(BuildContext context) async {
    final s = context.services;
    final t = AppLocalizations.of(context);
    final localeName = Localizations.localeOf(context).toLanguageTag();
    final duration = s.live.elapsed;
    final Session? saved = await s.live.end(
      titleFor: (d) => t.untitledSession(LiveSessionController.defaultTitle(d, localeName)),
    );
    if (saved == null) return;
    await s.ads.showAfterSession(duration);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.sessionSaved)));
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => SessionDetailScreen(sessionId: saved.id)),
    );
  }
}

class _MainButton extends StatelessWidget {
  const _MainButton({required this.active, required this.busy, required this.label, this.onTap});
  final bool active;
  final bool busy;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: Brand.amber,
              shape: BoxShape.circle,
              border: Border.all(color: c.surface2, width: 5),
            ),
            child: Center(
              child: busy
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 3, color: Brand.onAmber))
                  : active
                      ? Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: Brand.onAmber,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        )
                      : const Icon(Icons.mic_rounded, size: 34, color: Brand.onAmber),
            ),
          ),
          const SizedBox(height: 6),
          ExcludeSemantics(
            child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({required this.icon, required this.label, this.onTap, this.highlighted = false});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: 84,
      child: Column(children: [
        IconButton.filledTonal(
          tooltip: label,
          style: IconButton.styleFrom(
            backgroundColor: c.surface2,
            foregroundColor: highlighted ? c.accentText : null,
            minimumSize: const Size(52, 52),
          ),
          onPressed: onTap,
          icon: Icon(icon),
        ),
        const SizedBox(height: 2),
        Text(label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12)),
      ]),
    );
  }
}
