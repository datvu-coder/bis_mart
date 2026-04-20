class CourseTitle {
  final String id;
  final int excelId;
  final String title;
  final String? accessLevel;
  final String? imageUrl;
  final String? description;
  final double? rating;
  final String? targetGroup;
  final List<CourseContent> contents;

  CourseTitle({
    required this.id,
    required this.excelId,
    required this.title,
    this.accessLevel,
    this.imageUrl,
    this.description,
    this.rating,
    this.targetGroup,
    this.contents = const [],
  });

  factory CourseTitle.fromJson(Map<String, dynamic> json) {
    return CourseTitle(
      id: json['id'] as String,
      excelId: json['excelId'] as int? ?? 0,
      title: json['title'] as String,
      accessLevel: json['accessLevel'] as String?,
      imageUrl: json['imageUrl'] as String?,
      description: json['description'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      targetGroup: json['targetGroup'] as String?,
      contents: (json['contents'] as List<dynamic>?)
              ?.map((c) => CourseContent.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class CourseContent {
  final String id;
  final int excelId;
  final String title;
  final String? detailHtml;
  final int points;
  final String? attachmentType;
  final String? imageUrl;
  final String? videoUrl;
  final String? status;

  CourseContent({
    required this.id,
    required this.excelId,
    required this.title,
    this.detailHtml,
    this.points = 0,
    this.attachmentType,
    this.imageUrl,
    this.videoUrl,
    this.status,
  });

  factory CourseContent.fromJson(Map<String, dynamic> json) {
    return CourseContent(
      id: json['id'] as String,
      excelId: json['excelId'] as int? ?? 0,
      title: json['title'] as String,
      detailHtml: json['detailHtml'] as String?,
      points: json['points'] as int? ?? 0,
      attachmentType: json['attachmentType'] as String?,
      imageUrl: json['imageUrl'] as String?,
      videoUrl: json['videoUrl'] as String?,
      status: json['status'] as String?,
    );
  }
}

class CourseEnrollment {
  final String id;
  final String employeeCode;
  final String fullName;
  final String? enrolledAt;

  CourseEnrollment({
    required this.id,
    required this.employeeCode,
    required this.fullName,
    this.enrolledAt,
  });

  factory CourseEnrollment.fromJson(Map<String, dynamic> json) {
    return CourseEnrollment(
      id: json['id'] as String,
      employeeCode: json['employeeCode'] as String,
      fullName: json['fullName'] as String,
      enrolledAt: json['enrolledAt'] as String?,
    );
  }
}

class CourseCompletion {
  final String id;
  final int contentId;
  final String employeeCode;
  final String fullName;
  final String? completedAt;
  final int points;
  final String? contentName;

  CourseCompletion({
    required this.id,
    required this.contentId,
    required this.employeeCode,
    required this.fullName,
    this.completedAt,
    this.points = 0,
    this.contentName,
  });

  factory CourseCompletion.fromJson(Map<String, dynamic> json) {
    return CourseCompletion(
      id: json['id'] as String,
      contentId: json['contentId'] as int? ?? 0,
      employeeCode: json['employeeCode'] as String,
      fullName: json['fullName'] as String,
      completedAt: json['completedAt'] as String?,
      points: json['points'] as int? ?? 0,
      contentName: json['contentName'] as String?,
    );
  }
}
