class PostComment {
  final String id;
  final String authorName;
  final String text;
  final DateTime createdAt;

  PostComment({
    required this.id,
    required this.authorName,
    required this.text,
    required this.createdAt,
  });

  factory PostComment.fromJson(Map<String, dynamic> json) => PostComment(
        id: json['id']?.toString() ?? '',
        authorName: json['authorName'] as String? ?? 'Ẩn danh',
        text: json['text'] as String? ?? '',
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
      );
}

class CommunityPost {
  final String id;
  final String authorName;
  final DateTime createdAt;
  final String? content;
  final List<String> imageUrls;
  int likeCount;
  int commentCount;
  bool isLiked;
  List<PostComment> comments;

  CommunityPost({
    required this.id,
    required this.authorName,
    required this.createdAt,
    this.content,
    this.imageUrls = const [],
    this.likeCount = 0,
    this.commentCount = 0,
    this.isLiked = false,
    List<PostComment>? comments,
  }) : comments = comments ?? [];

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    return CommunityPost(
      id: json['id'] as String,
      authorName: json['authorName'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      content: json['content'] as String?,
      imageUrls: (json['imageUrls'] as List<dynamic>?)
              ?.map((u) => u as String)
              .toList() ??
          [],
      likeCount: json['likeCount'] as int? ?? 0,
      commentCount: json['commentCount'] as int? ?? 0,
      isLiked: json['isLiked'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'authorName': authorName,
        'createdAt': createdAt.toIso8601String(),
        'content': content,
        'imageUrls': imageUrls,
        'likeCount': likeCount,
        'commentCount': commentCount,
      };
}
