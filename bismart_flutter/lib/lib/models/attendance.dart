class Attendance {
  final String id;
  final DateTime date;
  final String employeeId;
  final bool isCheckedIn;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;

  Attendance({
    required this.id,
    required this.date,
    required this.employeeId,
    this.isCheckedIn = false,
    this.checkInTime,
    this.checkOutTime,
  });

  factory Attendance.fromJson(Map<String, dynamic> json) {
    return Attendance(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      employeeId: json['employeeId'] as String,
      isCheckedIn: json['isCheckedIn'] as bool? ?? false,
      checkInTime: json['checkInTime'] != null
          ? DateTime.parse(json['checkInTime'] as String)
          : null,
      checkOutTime: json['checkOutTime'] != null
          ? DateTime.parse(json['checkOutTime'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'employeeId': employeeId,
        'isCheckedIn': isCheckedIn,
        'checkInTime': checkInTime?.toIso8601String(),
        'checkOutTime': checkOutTime?.toIso8601String(),
      };
}
