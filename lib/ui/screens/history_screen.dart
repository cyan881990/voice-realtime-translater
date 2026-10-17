import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_scope.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/session.dart';
import '../../services/ads_service.dart';
import '../../services/live_session_controller.dart';
import '../widgets/app_logo.dart';
import '../widgets/segment_bubble.dart';
import 'session_detail_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    return Scaffold(
      body: const SafeArea(bottom: false, child: HistoryPanel(embedded: false)),
      bottomNavigationBar: ListenableBuilder(
        listenable: s.settings,
        builder: (context, _) => BannerAdSlot(settings: s.settings),
      ),
    );
  }
}

enum _Filter { all, today, pinned }

/// The searchable history list. Used as a full screen on phones and as the
/// left pane on tablets.
class HistoryPanel extends StatefulWidget {
  const HistoryPanel({super.key, required this.embedded});
  final bool embedded;

  @override
  State<HistoryPanel> createState() => _HistoryPanelState();
}

class _HistoryPanelState extends State<HistoryPanel> {
  final _search = TextEditingController();
  _Filter _filter = _Filter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Session> _visible(List<Session> all) {
    final q = _search.text.trim().toLowerCase();
    final now = DateTime.now();
    return all.where((s) {
      if (_filter == _Filter.pinned && !s.pinned) return false;
      if (_filter == _Filter.today &&
          !(s.createdAt.year == now.year &&
              s.createdAt.month == now.month &&
              s.createdAt.day == now.day)) {
        return false;
      }
      if (q.isEmpty) return true;
      if (s.title.toLowerCase().contains(q)) return true;
      return s.segments.any((g) =>
          g.sourceText.toLowerCase().contains(q) || g.translatedText.toLowerCase().contains(q));
    }).toList();
  }

  String _groupOf(DateTime d, AppLocalizations t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return t.today;
    if (diff == 1) return t.yesterday;
    return t.earlier;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    final t = AppLocalizations.of(context);
    final c = context.colors;
    return ListenableBuilder(
      listenable: Listenable.merge([s.repository, s.settings]),
      builder: (context, _) {
        final list = _visible(s.repository.sessions);
        final rows = <Widget>[];
        String? group;
        for (var i = 0; i < list.length; i++) {
          final g = _groupOf(list[i].createdAt, t);
          if (g != group) {
            group = g;
            rows.add(Padding(
              padding: EdgeInsets.only(top: rows.isEmpty ? 0 : 8, bottom: 8),
              child: Text(g, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.muted)),
            ));
          }
          rows.add(_SessionTile(session: list[i]));
          if (i == 0 && !s.settings.adsRemoved) {
            rows.add(NativeAdCard(settings: s.settings));
          }
        }

        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: EdgeInsets.fromLTRB(widget.embedded ? 20 : 8, 12, 16, 0),
            child: Row(children: [
              if (!widget.embedded)
                IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              Expanded(
                child: Text(t.history,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              ),
              _ImportExportButton(),
              if (!widget.embedded) ...[
                const SizedBox(width: 8),
                const AppLogo(size: 32),
              ],
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: t.searchHint,
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: widget.embedded ? c.surface2 : c.surface1,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: c.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: c.line),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(children: [
              Expanded(
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final f in _Filter.values)
                    ChoiceChip(
                      label: Text(switch (f) {
                        _Filter.all => t.filterAll,
                        _Filter.today => t.filterToday,
                        _Filter.pinned => t.filterPinned,
                      }),
                      selected: _filter == f,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                ]),
              ),
              Text(t.recordingsCount(s.repository.sessions.length),
                  style: TextStyle(fontSize: 12, color: c.muted)),
            ]),
          ),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(t.emptyHistory,
                          textAlign: TextAlign.center, style: TextStyle(color: c.muted)),
                    ),
                  )
                : ListView(padding: const EdgeInsets.fromLTRB(20, 18, 20, 20), children: rows),
          ),
        ]);
      },
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});
  final Session session;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = Duration(milliseconds: session.durationMs);
    final dur =
        '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
    final time = TimeOfDay.fromDateTime(session.createdAt).format(context);
    final males = session.countOf(VoiceGender.male);
    final females = session.countOf(VoiceGender.female);
    final preview = session.segments.isEmpty ? '' : session.segments.last.translatedText;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: c.surface1,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => SessionDetailScreen(sessionId: session.id),
          )),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                if (session.pinned) ...[
                  Icon(Icons.push_pin_rounded, size: 14, color: c.accentText),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(session.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                Text(dur,
                    style: TextStyle(
                        fontSize: 12, color: c.muted, fontFeatures: const [FontFeature.tabularFigures()])),
              ]),
              const SizedBox(height: 4),
              Text('${langPairLabel(session.languageA, session.languageB)} · $time',
                  style: TextStyle(fontSize: 12, color: c.muted)),
              if (preview.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
              ],
              if (males + females > 0) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 6, children: [
                  if (males > 0) GenderChip(gender: VoiceGender.male, compact: true),
                  if (females > 0) GenderChip(gender: VoiceGender.female, compact: true),
                ]),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

enum _IoAction { backup, allJson, import }

class _ImportExportButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return PopupMenuButton<_IoAction>(
      tooltip: t.importExport,
      onSelected: (a) => _run(context, a),
      itemBuilder: (_) => [
        PopupMenuItem(value: _IoAction.backup, child: Text(t.exportBackup)),
        PopupMenuItem(value: _IoAction.allJson, child: Text(t.exportAllJson)),
        const PopupMenuDivider(),
        PopupMenuItem(value: _IoAction.import, child: Text(t.importFile)),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: context.colors.line),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.import_export_rounded, size: 18),
          const SizedBox(width: 6),
          Text(t.importExport, style: const TextStyle(fontSize: 13)),
        ]),
      ),
    );
  }

  Future<void> _run(BuildContext context, _IoAction a) async {
    final s = context.services;
    final t = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    try {
      switch (a) {
        case _IoAction.backup:
          final f = await s.repository.exportBackupZip();
          await shareFile(f, origin);
        case _IoAction.allJson:
          final f = await s.repository.exportAllJson();
          await shareFile(f, origin);
        case _IoAction.import:
          final picked = await FilePicker.pickFile();
          final path = picked?.path;
          if (path == null) return;
          final n = await s.repository.importFile(File(path));
          messenger.showSnackBar(SnackBar(content: Text(t.importDone(n))));
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(t.importFailed)));
    }
  }
}

/// Opens the system share sheet (save to Files, Drive, send by chat…).
Future<void> shareFile(File f, Rect? origin) async {
  await SharePlus.instance.share(ShareParams(
    files: [XFile(f.path)],
    sharePositionOrigin: origin,
  ));
}
