import 'package:flutter/material.dart';

class WorkShift {
  final String id;
  final String name;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String? shiftCode;
  final String? storeName;

  WorkShift({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    this.shiftCode,
    this.storeName,
  });

  String get timeRange =>
      '${_formatTime(startTime)} - ${_formatTime(endTime)}';

  static String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  factory WorkShift.fromJson(Map<String, dynamic> json) {
    return WorkShift(
      id: json['id'] as String,
      name: json['name'] as String,
      startTime: TimeOfDay(
        hour: json['startHour'] as int,
        minute: json['startMinute'] as int,
      ),
      endTime: TimeOfDay(
        hour: json['endHour'] as int,
        minute: json['endMinute'] as int,
      ),
      shiftCode: json['shiftCode'] as String?,
      storeName: json['storeName'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'startHour': startTime.hour,
        'startMinute': startTime.minute,
        'endHour': endTime.hour,
        'endMinute': endTime.minute,
      };

  static List<WorkShift> defaultShifts() {
    return [
      WorkShift(
        id: '1',
        name: 'Ca gãy sáng',
        startTime: const TimeOfDay(hour: 7, minute: 30),
        endTime: const TimeOfDay(hour: 11, minute: 30),
      ),
      WorkShift(
        id: '2',
        name: 'Ca gãy chiều',
        startTime: const TimeOfDay(hour: 17, minute: 0),
        endTime: const TimeOfDay(hour: 21, minute: 0),
      ),
      WorkShift(
        id: '3',
        name: 'Ca ngày',
        startTime: const TimeOfDay(hour: 11, minute: 0),
        endTime: const TimeOfDay(hour: 19, minute: 0),
      ),
      WorkShift(
        id: '4',
        name: 'Ca sáng',
        startTime: const TimeOfDay(hour: 8, minute: 30),
        endTime: const TimeOfDay(hour: 12, minute: 30),
      ),
      WorkShift(
        id: '5',
        name: 'Ca chiều',
        startTime: const TimeOfDay(hour: 15, minute: 0),
        endTime: const TimeOfDay(hour: 19, minute: 0),
      ),
    ];
  }
}
