class Attendance {
  final String id;
  final DateTime date;
  final String employeeId;
  final bool isCheckedIn;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final String? employeeName;
  final String? shiftName;
  final String? shiftTimeRange;
  final String? coordinates;
  final double? distanceIn;
  final String? checkInDiff;
  final String? checkInStatus;
  final double? distanceOut;
  final String? checkOutDiff;
  final String? checkOutStatus;

  Attendance({
    required this.id,
    required this.date,
    required this.employeeId,
    this.isCheckedIn = false,
    this.checkInTime,
    this.checkOutTime,
    this.employeeName,
    this.shiftName,
    this.shiftTimeRange,
    this.coordinates,
    this.distanceIn,
    this.checkInDiff,
    this.checkInStatus,
    this.distanceOut,
    this.checkOutDiff,
    this.checkOutStatus,
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
      employeeName: json['employeeName'] as String?,
      shiftName: json['shiftName'] as String?,
      shiftTimeRange: json['shiftTimeRange'] as String?,
      coordinates: json['coordinates'] as String?,
      distanceIn: (json['distanceIn'] as num?)?.toDouble(),
      checkInDiff: json['checkInDiff'] as String?,
      checkInStatus: json['checkInStatus'] as String?,
      distanceOut: (json['distanceOut'] as num?)?.toDouble(),
      checkOutDiff: json['checkOutDiff'] as String?,
      checkOutStatus: json['checkOutStatus'] as String?,
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
