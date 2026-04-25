class Lesson {
  final String id;
  final String title;
  final String description;
  final String thumbnailUrl;
  final String targetRole; // PG | ADM | TLD | ALL
  final bool isRestricted;
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
    this.videoUrl,
    this.videoPath,
    this.questionCount = 0,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'].toString(),
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      thumbnailUrl: (json['thumbnailUrl'] as String?) ?? '',
      targetRole: (json['targetRole'] as String?) ?? 'ALL',
      isRestricted: json['isRestricted'] as bool? ?? false,
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
        'videoUrl': videoUrl,
        'videoPath': videoPath,
        'questionCount': questionCount,
      };
}
