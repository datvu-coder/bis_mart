class Lesson {
  final String id;
  final String title;
  final String thumbnailUrl;
  final String targetRole; // PG | ADM | TLD | ALL
  final bool isRestricted;
  final String? videoUrl;

  Lesson({
    required this.id,
    required this.title,
    required this.thumbnailUrl,
    required this.targetRole,
    this.isRestricted = false,
    this.videoUrl,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'] as String,
      title: json['title'] as String,
      thumbnailUrl: (json['thumbnailUrl'] as String?) ?? '',
      targetRole: json['targetRole'] as String,
      isRestricted: json['isRestricted'] as bool? ?? false,
      videoUrl: json['videoUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'thumbnailUrl': thumbnailUrl,
        'targetRole': targetRole,
        'isRestricted': isRestricted,
        'videoUrl': videoUrl,
      };
}
