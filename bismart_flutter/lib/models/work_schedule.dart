class WorkSchedule {
  final String id;
  final String employeeId;
  final String shiftId;
  final DateTime workDate;
  final String? note;
  final String? employeeName;
  final String? shiftName;
  final int? startHour;
  final int? startMinute;
  final int? endHour;
  final int? endMinute;

  WorkSchedule({
    required this.id,
    required this.employeeId,
    required this.shiftId,
    required this.workDate,
    this.note,
    this.employeeName,
    this.shiftName,
    this.startHour,
    this.startMinute,
    this.endHour,
    this.endMinute,
  });

  String get timeRange {
    if (startHour == null) return shiftName ?? '';
    final s = '${startHour.toString().padLeft(2, '0')}:${(startMinute ?? 0).toString().padLeft(2, '0')}';
    final e = '${endHour.toString().padLeft(2, '0')}:${(endMinute ?? 0).toString().padLeft(2, '0')}';
    return '$s-$e';
  }

  factory WorkSchedule.fromJson(Map<String, dynamic> json) {
    return WorkSchedule(
      id: json['id'] as String,
      employeeId: json['employeeId'] as String,
      shiftId: json['shiftId'] as String,
      workDate: DateTime.parse(json['workDate'] as String),
      note: json['note'] as String?,
      employeeName: json['employeeName'] as String?,
      shiftName: json['shiftName'] as String?,
      startHour: json['startHour'] as int?,
      startMinute: json['startMinute'] as int?,
      endHour: json['endHour'] as int?,
      endMinute: json['endMinute'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'employeeId': employeeId,
    'shiftId': shiftId,
    'workDate': '${workDate.year}-${workDate.month.toString().padLeft(2, '0')}-${workDate.day.toString().padLeft(2, '0')}',
    'note': note,
  };
}
