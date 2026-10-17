import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/session.dart';

/// One utterance: speaker label, original text and translation.
/// Language 1 speakers sit on the left, language 2 speakers on the right.
class SegmentBubble extends StatelessWidget {
  const SegmentBubble({
    super.key,
    required this.segment,
    required this.alignRight,
    this.onToggleGender,
    this.onSpeak,
    this.showGender = true,
  });

  final Segment segment;
  final bool alignRight;
  final VoidCallback? onToggleGender;
  final VoidCallback? onSpeak;
  final bool showGender;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppLocalizations.of(context);
    final radius = alignRight
        ? const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(6),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18))
        : const BorderRadius.only(
            topLeft: Radius.circular(6),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18));
    return Align(
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: 0.88,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 12),
          decoration: BoxDecoration(
            color: alignRight ? c.surface2 : c.surface1,
            borderRadius: radius,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                if (showGender && segment.gender != VoiceGender.unknown)
                  GenderChip(gender: segment.gender, onTap: onToggleGender),
                if (showGender && segment.gender != VoiceGender.unknown) const SizedBox(width: 6),
                Text('${segment.sourceLang.toUpperCase()} → ${segment.targetLang.toUpperCase()}',
                    style: TextStyle(fontSize: 11, color: c.muted)),
                const Spacer(),
                Text(_clock(segment.startMs),
                    style: TextStyle(fontSize: 11, color: c.muted, fontFeatures: const [FontFeature.tabularFigures()])),
                if (onSpeak != null)
                  IconButton(
                    tooltip: t.readAloud,
                    visualDensity: VisualDensity.compact,
                    iconSize: 18,
                    onPressed: onSpeak,
                    icon: const Icon(Icons.volume_up_rounded),
                  ),
              ]),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: SelectableText(segment.sourceText,
                    style: TextStyle(fontSize: 13, height: 1.45, color: c.muted)),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: SelectableText(segment.translatedText,
                    style: const TextStyle(fontSize: 16, height: 1.45, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _clock(int ms) {
    final d = Duration(milliseconds: ms);
    return '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }
}

class GenderChip extends StatelessWidget {
  const GenderChip({super.key, required this.gender, this.onTap, this.compact = false, this.count});
  final VoiceGender gender;
  final VoidCallback? onTap;
  final bool compact;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final male = gender == VoiceGender.male;
    final label = male ? t.maleVoice : t.femaleVoice;
    final text = count != null && count! > 1 ? '$label ×$count' : label;
    return Semantics(
      button: onTap != null,
      label: text,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          padding: EdgeInsets.fromLTRB(compact ? 8 : 6, 2, 8, 2),
          decoration: BoxDecoration(
            color: male ? Brand.male : Brand.female,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (!compact) const Icon(Icons.person_rounded, size: 12, color: Brand.ink),
            if (!compact) const SizedBox(width: 3),
            Text(text,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Brand.ink)),
          ]),
        ),
      ),
    );
  }
}
