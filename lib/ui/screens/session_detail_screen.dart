import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/session.dart';
import '../../services/ads_service.dart';
import '../../services/live_session_controller.dart';
import '../widgets/app_logo.dart';
import '../widgets/segment_bubble.dart';
import 'history_screen.dart';

enum _Menu { rename, pin, txt, srt, zip, delete }

/// Review a saved conversation: replay audio, fix labels, export, delete.
class SessionDetailScreen extends StatefulWidget {
  const SessionDetailScreen({super.key, required this.sessionId});
  final String sessionId;

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Session? _find() {
    final list = context.services.repository.sessions.where((x) => x.id == widget.sessionId);
    return list.isEmpty ? null : list.first;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    final t = AppLocalizations.of(context);
    final c = context.colors;
    return ListenableBuilder(
      listenable: s.repository,
      builder: (context, _) {
        final session = _find();
        if (session == null) return const Scaffold();
        final audio = s.repository.audioFileOf(session);
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: Text(session.title, overflow: TextOverflow.ellipsis),
            actions: [
              if (audio != null)
                IconButton(
                  tooltip: _playing ? t.stop : t.play,
                  icon: Icon(_playing ? Icons.stop_rounded : Icons.play_arrow_rounded),
                  onPressed: () async {
                    if (_playing) {
                      await _player.stop();
                      setState(() => _playing = false);
                    } else {
                      await _player.play(DeviceFileSource(audio.path));
                      setState(() => _playing = true);
                    }
                  },
                ),
              PopupMenuButton<_Menu>(
                onSelected: (m) => _onMenu(context, session, m),
                itemBuilder: (_) => [
                  PopupMenuItem(value: _Menu.rename, child: Text(t.rename)),
                  PopupMenuItem(value: _Menu.pin, child: Text(session.pinned ? t.unpin : t.pin)),
                  const PopupMenuDivider(),
                  PopupMenuItem(value: _Menu.txt, child: Text(t.exportTxt)),
                  PopupMenuItem(value: _Menu.srt, child: Text(t.exportSrt)),
                  PopupMenuItem(value: _Menu.zip, child: Text(t.exportBackup)),
                  const PopupMenuDivider(),
                  PopupMenuItem(value: _Menu.delete, child: Text(t.delete)),
                ],
              ),
              const Padding(padding: EdgeInsets.only(right: 12), child: AppLogo(size: 28)),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14, left: 4),
                    child: Text(
                      '${langPairLabel(session.languageA, session.languageB)} · '
                      '${MaterialLocalizations.of(context).formatMediumDate(session.createdAt)}',
                      style: TextStyle(color: c.muted, fontSize: 13),
                    ),
                  ),
                  for (final seg in session.segments)
                    SegmentBubble(
                      segment: seg,
                      alignRight: seg.sourceLang == session.languageB,
                      showGender: s.settings.voiceLabels,
                      onToggleGender: () {
                        seg.gender =
                            seg.gender == VoiceGender.male ? VoiceGender.female : VoiceGender.male;
                        s.repository.save(session);
                      },
                      onSpeak: () => s.tts.speak(seg.translatedText, seg.targetLang, seg.gender),
                    ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: BannerAdSlot(settings: s.settings),
        );
      },
    );
  }

  Future<void> _onMenu(BuildContext context, Session session, _Menu m) async {
    final s = context.services;
    final t = AppLocalizations.of(context);
    final nav = Navigator.of(context);
    final size = MediaQuery.sizeOf(context);
    final origin = Rect.fromLTWH(size.width - 64, 48, 1, 1); // iPad share popover anchor
    switch (m) {
      case _Menu.rename:
        final ctrl = TextEditingController(text: session.title);
        final name = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(t.rename),
            content: TextField(
              controller: ctrl,
              autofocus: true,
              decoration: InputDecoration(labelText: t.renameHint),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(t.cancel)),
              FilledButton(onPressed: () => Navigator.of(ctx).pop(ctrl.text), child: Text(t.save)),
            ],
          ),
        );
        if (name != null && name.trim().isNotEmpty) {
          session.title = name.trim();
          await s.repository.save(session);
        }
      case _Menu.pin:
        session.pinned = !session.pinned;
        await s.repository.save(session);
      case _Menu.txt:
        await shareFile(await s.repository.exportText(session), origin);
      case _Menu.srt:
        await shareFile(await s.repository.exportSrt(session), origin);
      case _Menu.zip:
        await shareFile(await s.repository.exportBackupZip([session]), origin);
      case _Menu.delete:
        await s.repository.delete(session);
        nav.pop();
    }
  }
}
