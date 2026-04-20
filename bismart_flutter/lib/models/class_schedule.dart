class ClassSchedule {
  final String id;
  final int excelId;
  final String? startDate;
  final String? startTime;
  final String? endDate;
  final String? endTime;
  final String content;
  final String? link;
  final int attendanceCount;
  final List<ClassAttendance> attendances;

  ClassSchedule({
    required this.id,
    required this.excelId,
    this.startDate,
    this.startTime,
    this.endDate,
    this.endTime,
    required this.content,
    this.link,
    this.attendanceCount = 0,
    this.attendances = const [],
  });

  factory ClassSchedule.fromJson(Map<String, dynamic> json) {
    return ClassSchedule(
      id: json['id'] as String,
      excelId: json['excelId'] as int? ?? 0,
      startDate: json['startDate'] as String?,
      startTime: json['startTime'] as String?,
      endDate: json['endDate'] as String?,
      endTime: json['endTime'] as String?,
      content: json['content'] as String,
      link: json['link'] as String?,
      attendanceCount: json['attendanceCount'] as int? ?? 0,
      attendances: (json['attendances'] as List<dynamic>?)
              ?.map((a) => ClassAttendance.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class ClassAttendance {
  final String id;
  final String employeeCode;
  final String fullName;
  final String? storeName;
  final String action;
  final String? time;
  final String? date;

  ClassAttendance({
    required this.id,
    required this.employeeCode,
    required this.fullName,
    this.storeName,
    required this.action,
    this.time,
    this.date,
  });

  factory ClassAttendance.fromJson(Map<String, dynamic> json) {
    return ClassAttendance(
      id: json['id'] as String,
      employeeCode: json['employeeCode'] as String,
      fullName: json['fullName'] as String,
      storeName: json['storeName'] as String?,
      action: json['action'] as String,
      time: json['time'] as String?,
      date: json['date'] as String?,
    );
  }
}
