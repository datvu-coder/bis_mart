class AiTool {
  final int id;
  final String name;
  final String? link;

  AiTool({required this.id, required this.name, this.link});

  factory AiTool.fromJson(Map<String, dynamic> json) {
    return AiTool(
      id: json['id'] as int,
      name: json['name'] as String,
      link: json['link'] as String?,
    );
  }
}

class AiUsageLog {
  final int id;
  final String employeeCode;
  final String fullName;
  final String? storeName;
  final String aiName;
  final String? usedAt;
  final int points;

  AiUsageLog({
    required this.id,
    required this.employeeCode,
    required this.fullName,
    this.storeName,
    required this.aiName,
    this.usedAt,
    this.points = 0,
  });

  factory AiUsageLog.fromJson(Map<String, dynamic> json) {
    return AiUsageLog(
      id: json['id'] as int,
      employeeCode: json['employeeCode'] as String,
      fullName: json['fullName'] as String,
      storeName: json['storeName'] as String?,
      aiName: json['aiName'] as String,
      usedAt: json['usedAt'] as String?,
      points: json['points'] as int? ?? 0,
    );
  }
}
