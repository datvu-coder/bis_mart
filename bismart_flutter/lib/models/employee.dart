class Employee {
  final String id;
  final String fullName;
  final String employeeCode;
  final String position; // ADM | PG | TLD | MNG | CS
  final String workLocation;
  final int score;
  final int rank;
  final String? email;
  final String? phone;
  final String? dateOfBirth;
  final String? cccd;
  final String? address;
  final String? status;
  final String? department;
  final String? province;
  final String? area;
  final String? createdDate;
  final String? probationDate;
  final String? officialDate;
  final String? resignDate;
  final String? resignReason;
  final String? avatarUrl;
  final String? storeCode;
  final String? rankLevel;

  Employee({
    required this.id,
    required this.fullName,
    required this.employeeCode,
    required this.position,
    required this.workLocation,
    this.score = 0,
    this.rank = 0,
    this.email,
    this.phone,
    this.dateOfBirth,
    this.cccd,
    this.address,
    this.status,
    this.department,
    this.province,
    this.area,
    this.createdDate,
    this.probationDate,
    this.officialDate,
    this.resignDate,
    this.resignReason,
    this.avatarUrl,
    this.storeCode,
    this.rankLevel,
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
      phone: json['phone'] as String?,
      dateOfBirth: json['dateOfBirth'] as String?,
      cccd: json['cccd'] as String?,
      address: json['address'] as String?,
      status: json['status'] as String?,
      department: json['department'] as String?,
      province: json['province'] as String?,
      area: json['area'] as String?,
      createdDate: json['createdDate'] as String?,
      probationDate: json['probationDate'] as String?,
      officialDate: json['officialDate'] as String?,
      resignDate: json['resignDate'] as String?,
      resignReason: json['resignReason'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      storeCode: json['storeCode'] as String?,
      rankLevel: json['rankLevel'] as String?,
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
        'phone': phone,
        'dateOfBirth': dateOfBirth,
        'cccd': cccd,
        'address': address,
        'status': status,
        'department': department,
        'province': province,
        'area': area,
        'storeCode': storeCode,
        'rankLevel': rankLevel,
      };

  Employee copyWith({
    String? id, String? fullName, String? employeeCode, String? position,
    String? workLocation, int? score, int? rank, String? email, String? phone,
    String? dateOfBirth, String? cccd, String? address, String? status,
    String? department, String? province, String? area, String? storeCode,
    String? rankLevel,
  }) {
    return Employee(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      employeeCode: employeeCode ?? this.employeeCode,
      position: position ?? this.position,
      workLocation: workLocation ?? this.workLocation,
      score: score ?? this.score,
      rank: rank ?? this.rank,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      cccd: cccd ?? this.cccd,
      address: address ?? this.address,
      status: status ?? this.status,
      department: department ?? this.department,
      province: province ?? this.province,
      area: area ?? this.area,
      createdDate: createdDate,
      probationDate: probationDate,
      officialDate: officialDate,
      resignDate: resignDate,
      resignReason: resignReason,
      avatarUrl: avatarUrl,
      storeCode: storeCode ?? this.storeCode,
      rankLevel: rankLevel ?? this.rankLevel,
    );
  }

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
