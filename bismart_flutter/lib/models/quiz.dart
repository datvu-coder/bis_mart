class QuizQuestion {
  final int id;
  final String type;
  final String question;
  final List<String?> options;
  final String? correctAnswer;
  final int points;

  QuizQuestion({
    required this.id,
    required this.type,
    required this.question,
    this.options = const [],
    this.correctAnswer,
    this.points = 0,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      id: json['id'] as int,
      type: json['type'] as String? ?? 'multiple_choice',
      question: json['question'] as String,
      options: (json['options'] as List<dynamic>?)
              ?.map((o) => o as String?)
              .toList() ??
          [],
      correctAnswer: json['correctAnswer'] as String?,
      points: json['points'] as int? ?? 0,
    );
  }
}

class QuizResult {
  final int id;
  final String? submittedAt;
  final String employeeCode;
  final String fullName;
  final String? storeName;
  final double score;
  final String? answersJson;

  QuizResult({
    required this.id,
    required this.employeeCode,
    required this.fullName,
    this.submittedAt,
    this.storeName,
    this.score = 0,
    this.answersJson,
  });

  factory QuizResult.fromJson(Map<String, dynamic> json) {
    return QuizResult(
      id: json['id'] as int,
      submittedAt: json['submittedAt'] as String?,
      employeeCode: json['employeeCode'] as String,
      fullName: json['fullName'] as String,
      storeName: json['storeName'] as String?,
      score: (json['score'] as num?)?.toDouble() ?? 0,
      answersJson: json['answersJson'] as String?,
    );
  }
}
