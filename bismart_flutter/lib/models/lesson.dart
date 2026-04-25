class LessonPart {
  final String id;
  final String lessonId;
  final String title;
  final String description;
  final String videoPath;
  final int orderIndex;
  final int questionCount;
  final List<Map<String, dynamic>> questions;

  LessonPart({
    required this.id,
    required this.lessonId,
    required this.title,
    this.description = '',
    this.videoPath = '',
    this.orderIndex = 0,
    this.questionCount = 0,
    this.questions = const [],
  });

  factory LessonPart.fromJson(Map<String, dynamic> json) {
    final raw = (json['questions'] as List?) ?? const [];
    return LessonPart(
      id: json['id'].toString(),
      lessonId: json['lessonId']?.toString() ?? '',
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      videoPath: (json['videoPath'] as String?) ?? '',
      orderIndex: (json['orderIndex'] as num?)?.toInt() ?? 0,
      questionCount: (json['questionCount'] as num?)?.toInt() ?? raw.length,
      questions: raw.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
    );
  }

  bool get hasVideo => videoPath.isNotEmpty;
  bool get hasQuiz => questionCount > 0;
}

class Lesson {
  final String id;
  final String title;
  final String description;
  final String thumbnailUrl;
  final String targetRole; // PG | ADM | TLD | ALL
  final bool isRestricted;
  final List<LessonPart> parts;
  final int partCount;
  final int completedPartCount;
  final double progress; // 0.0 - 1.0

  // Legacy fields kept for backward compat with older callers; not used now.
  final String? videoUrl;
  final String? videoPath;
  final int questionCount;

  Lesson({
    required this.id,
    required this.title,
    this.description = '',
    required this.thumbnailUrl,
    required this.targetRole,
    this.isRestricted = false,
    this.parts = const [],
    this.partCount = 0,
    this.completedPartCount = 0,
    this.progress = 0.0,
    this.videoUrl,
    this.videoPath,
    this.questionCount = 0,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    final partsRaw = (json['parts'] as List?) ?? const [];
    final parts = partsRaw
        .map((e) => LessonPart.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return Lesson(
      id: json['id'].toString(),
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      thumbnailUrl: (json['thumbnailUrl'] as String?) ?? '',
      targetRole: (json['targetRole'] as String?) ?? 'ALL',
      isRestricted: json['isRestricted'] as bool? ?? false,
      parts: parts,
      partCount: (json['partCount'] as num?)?.toInt() ?? parts.length,
      completedPartCount: (json['completedPartCount'] as num?)?.toInt() ?? 0,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      videoUrl: json['videoUrl'] as String?,
      videoPath: json['videoPath'] as String?,
      questionCount: (json['questionCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'thumbnailUrl': thumbnailUrl,
        'targetRole': targetRole,
        'isRestricted': isRestricted,
        'partCount': partCount,
        'completedPartCount': completedPartCount,
        'progress': progress,
      };
}
