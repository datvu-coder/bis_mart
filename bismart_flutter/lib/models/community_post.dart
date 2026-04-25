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
  final String? authorId;
  final String authorName;
  final DateTime createdAt;
  final String? content;
  final List<String> imageUrls;
  final String? videoUrl;
  final String visibility; // public | store
  final String? storeCode;
  int likeCount;
  int commentCount;
  bool isLiked;
  List<PostComment> comments;

  CommunityPost({
    required this.id,
    this.authorId,
    required this.authorName,
    required this.createdAt,
    this.content,
    this.imageUrls = const [],
    this.videoUrl,
    this.visibility = 'public',
    this.storeCode,
    this.likeCount = 0,
    this.commentCount = 0,
    this.isLiked = false,
    List<PostComment>? comments,
  }) : comments = comments ?? [];

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    return CommunityPost(
      id: json['id'].toString(),
      authorId: json['authorId']?.toString(),
      authorName: (json['authorName'] as String?) ?? 'Ẩn danh',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      content: json['content'] as String?,
      imageUrls: (json['imageUrls'] as List<dynamic>?)
              ?.map((u) => u as String)
              .toList() ??
          [],
      videoUrl: json['videoUrl'] as String?,
      visibility: (json['visibility'] as String?) == 'store' ? 'store' : 'public',
      storeCode: json['storeCode'] as String?,
      likeCount: json['likeCount'] as int? ?? 0,
      commentCount: json['commentCount'] as int? ?? 0,
      isLiked: json['isLiked'] as bool? ?? false,
      comments: (json['comments'] as List<dynamic>?)
              ?.map((c) => PostComment.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'authorId': authorId,
        'authorName': authorName,
        'createdAt': createdAt.toIso8601String(),
        'content': content,
        'imageUrls': imageUrls,
        'visibility': visibility,
        'storeCode': storeCode,
        'likeCount': likeCount,
        'commentCount': commentCount,
      };
}
