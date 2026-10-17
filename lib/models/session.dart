enum VoiceGender { male, female, unknown }

/// One translated utterance.
class Segment {
  Segment({
    required this.startMs,
    required this.endMs,
    required this.sourceLang,
    required this.targetLang,
    required this.sourceText,
    required this.translatedText,
    this.gender = VoiceGender.unknown,
    this.pitchHz,
  });

  final int startMs;
  final int endMs;
  final String sourceLang;
  final String targetLang;
  String sourceText;
  String translatedText;
  VoiceGender gender;
  final double? pitchHz;

  Map<String, dynamic> toJson() => {
        'startMs': startMs,
        'endMs': endMs,
        'sourceLang': sourceLang,
        'targetLang': targetLang,
        'sourceText': sourceText,
        'translatedText': translatedText,
        'gender': gender.name,
        if (pitchHz != null) 'pitchHz': double.parse(pitchHz!.toStringAsFixed(1)),
      };

  factory Segment.fromJson(Map<String, dynamic> j) => Segment(
        startMs: (j['startMs'] as num).toInt(),
        endMs: (j['endMs'] as num).toInt(),
        sourceLang: j['sourceLang'] as String,
        targetLang: j['targetLang'] as String,
        sourceText: j['sourceText'] as String? ?? '',
        translatedText: j['translatedText'] as String? ?? '',
        gender: VoiceGender.values.firstWhere(
          (g) => g.name == j['gender'],
          orElse: () => VoiceGender.unknown,
        ),
        pitchHz: (j['pitchHz'] as num?)?.toDouble(),
      );
}

/// A recorded and translated conversation.
class Session {
  Session({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.languageA,
    required this.languageB,
    required this.durationMs,
    List<Segment>? segments,
    this.pinned = false,
    this.audioFile,
  }) : segments = segments ?? [];

  final String id;
  String title;
  final DateTime createdAt;
  final String languageA;
  final String languageB;
  int durationMs;
  final List<Segment> segments;
  bool pinned;

  /// File name (inside the sessions folder) of the 16 kHz mono WAV, if saved.
  String? audioFile;

  Set<VoiceGender> get voices => segments.map((s) => s.gender).toSet();

  int countOf(VoiceGender g) => segments.where((s) => s.gender == g).length;

  Map<String, dynamic> toJson() => {
        'format': 'voice-realtime-translater/session',
        'version': 1,
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'languageA': languageA,
        'languageB': languageB,
        'durationMs': durationMs,
        'pinned': pinned,
        if (audioFile != null) 'audioFile': audioFile,
        'segments': segments.map((s) => s.toJson()).toList(),
      };

  factory Session.fromJson(Map<String, dynamic> j) => Session(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        createdAt: DateTime.parse(j['createdAt'] as String),
        languageA: j['languageA'] as String? ?? 'en',
        languageB: j['languageB'] as String? ?? 'vi',
        durationMs: (j['durationMs'] as num?)?.toInt() ?? 0,
        pinned: j['pinned'] as bool? ?? false,
        audioFile: j['audioFile'] as String?,
        segments: ((j['segments'] as List?) ?? [])
            .map((e) => Segment.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}
