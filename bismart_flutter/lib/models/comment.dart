class Comment {
  final String id;
  final String? content;
  final String authorName;
  final String? employeeCode;
  final String? imageUrl;
  final String? videoUrl;
  final int points;
  final int likeCount;
  final String? createdAt;

  Comment({
    required this.id,
    this.content,
    required this.authorName,
    this.employeeCode,
    this.imageUrl,
    this.videoUrl,
    this.points = 0,
    this.likeCount = 0,
    this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] as String,
      content: json['content'] as String?,
      authorName: json['authorName'] as String? ?? '',
      employeeCode: json['employeeCode'] as String?,
      imageUrl: json['imageUrl'] as String?,
      videoUrl: json['videoUrl'] as String?,
      points: json['points'] as int? ?? 0,
      likeCount: json['likeCount'] as int? ?? 0,
      createdAt: json['createdAt'] as String?,
    );
  }
}
