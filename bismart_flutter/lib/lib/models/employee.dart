class Employee {
  final String id;
  final String fullName;
  final String employeeCode;
  final String position; // ADM | PG | TLD | MNG | CS
  final String workLocation;
  final int score;
  final int rank;
  final String? email;

  Employee({
    required this.id,
    required this.fullName,
    required this.employeeCode,
    required this.position,
    required this.workLocation,
    this.score = 0,
    this.rank = 0,
    this.email,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      employeeCode: json['employeeCode'] as String,
      position: json['position'] as String,
      workLocation: json['workLocation'] as String,
      score: json['score'] as int? ?? 0,
      rank: json['rank'] as int? ?? 0,
      email: json['email'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'employeeCode': employeeCode,
        'position': position,
        'workLocation': workLocation,
        'score': score,
        'rank': rank,
        'email': email,
      };

  String get positionLabel {
    switch (position) {
      case 'MNG':
        return 'Manager';
      case 'ADM':
        return 'Admin / Chủ Shop';
      case 'PG':
        return 'Promoter Girl';
      case 'TLD':
        return 'Trưởng Lĩnh Vực';
      case 'CS':
        return 'Chủ Shop chuỗi';
      default:
        return position;
    }
  }
}
