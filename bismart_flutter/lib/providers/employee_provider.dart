import 'package:flutter/material.dart';
import '../models/employee.dart';
import '../models/attendance.dart';
import '../models/work_shift.dart';
import '../models/work_schedule.dart';
import '../services/api_service.dart';

class EmployeeProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<Employee> _employees = [];
  List<Attendance> _attendances = [];
  List<Attendance> _historyAttendances = [];
  List<WorkShift> _shifts = [];
  List<WorkSchedule> _schedules = [];
  DateTime _scheduleWeekStart = _getMonday(DateTime.now());
  bool _isLoading = false;
  String? _error;

  // Monthly summary
  Map<String, dynamic> _monthlySummary = {};

  List<Employee> get employees => _employees;
  List<Attendance> get attendances => _attendances;
  List<Attendance> get historyAttendances => _historyAttendances;
  List<WorkShift> get shifts => _shifts;
  List<WorkSchedule> get schedules => _schedules;
  DateTime get scheduleWeekStart => _scheduleWeekStart;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic> get monthlySummary => _monthlySummary;
  void clearError() { _error = null; notifyListeners(); }

  static DateTime _getMonday(DateTime d) {
    final diff = d.weekday - 1;
    return DateTime(d.year, d.month, d.day - diff);
  }

  List<Employee> get rankedEmployees {
    final sorted = List<Employee>.from(_employees);
    sorted.sort((a, b) => b.score.compareTo(a.score));
    return sorted;
  }

  Future<void> loadEmployees() async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _api.getEmployees();
      _employees = data.map((e) => Employee.fromJson(e as Map<String, dynamic>)).toList();
      for (var i = 0; i < _employees.length; i++) {
        _employees[i] = _employees[i].copyWith(rank: i + 1);
      }
      final shiftData = await _api.getShifts();
      _shifts = shiftData.map((s) => WorkShift.fromJson(s as Map<String, dynamic>)).toList();
    } catch (e) {
      _error = 'Không thể tải dữ liệu nhân viên';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadAttendances() async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _api.getAttendances();
      _attendances = data.map((a) => Attendance.fromJson(a as Map<String, dynamic>)).toList();
    } catch (e) {
      _error = 'Không thể tải dữ liệu chấm công';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadAttendancesByDate(DateTime date) async {
    try {
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final data = await _api.getAttendances(date: dateStr);
      _historyAttendances = data.map((a) => Attendance.fromJson(a as Map<String, dynamic>)).toList();
    } catch (_) {
      _historyAttendances = [];
    }
    notifyListeners();
  }

  Future<void> checkIn(String employeeId, {double? latitude, double? longitude}) async {
    try {
      await _api.checkIn(int.parse(employeeId), latitude: latitude, longitude: longitude);
      await loadAttendances();
    } catch (e) {
      _error = 'Chấm công thất bại';
      notifyListeners();
    }
  }

  Future<void> checkOut(String employeeId, {double? latitude, double? longitude}) async {
    try {
      await _api.checkOut(int.parse(employeeId), latitude: latitude, longitude: longitude);
      await loadAttendances();
    } catch (e) {
      _error = 'Check-out thất bại';
      notifyListeners();
    }
  }

  Future<void> loadMonthlySummary({String? month, String? employeeId}) async {
    try {
      _monthlySummary = await _api.getMonthlyAttendanceSummary(
        month: month,
        employeeId: employeeId != null ? int.parse(employeeId) : null,
      );
    } catch (_) {
      _monthlySummary = {};
    }
    notifyListeners();
  }

  Future<void> addShift(WorkShift shift) async {
    try {
      await _api.createShift(shift.toJson());
      final shiftData = await _api.getShifts();
      _shifts = shiftData.map((s) => WorkShift.fromJson(s as Map<String, dynamic>)).toList();
    } catch (_) {
      _shifts.add(shift);
    }
    notifyListeners();
  }

  void removeShift(String shiftId) async {
    try { await _api.deleteShift(int.parse(shiftId)); } catch (_) {}
    _shifts.removeWhere((s) => s.id == shiftId);
    notifyListeners();
  }

  Future<void> addEmployee(Employee employee) async {
    try {
      final result = await _api.createEmployee(employee.toJson());
      _employees.add(Employee.fromJson(result));
    } catch (_) {
      _employees.add(employee);
    }
    _recalcRanks();
    notifyListeners();
  }

  Future<void> updateEmployee(Employee updated) async {
    try { await _api.updateEmployee(int.parse(updated.id), updated.toJson()); } catch (_) {}
    final index = _employees.indexWhere((e) => e.id == updated.id);
    if (index != -1) {
      _employees[index] = updated;
      _recalcRanks();
      notifyListeners();
    }
  }

  Future<void> deleteEmployee(String id) async {
    try { await _api.deleteEmployee(int.parse(id)); } catch (_) {}
    _employees.removeWhere((e) => e.id == id);
    _attendances.removeWhere((a) => a.employeeId == id);
    _recalcRanks();
    notifyListeners();
  }

  Employee? getEmployeeById(String id) {
    try {
      return _employees.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> loadSchedules({DateTime? weekStart}) async {
    final monday = weekStart ?? _scheduleWeekStart;
    _scheduleWeekStart = monday;
    final weekStr =
        '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
    try {
      final data = await _api.getEmployeeSchedules(week: weekStr);
      _schedules = data
          .map((s) => WorkSchedule.fromJson(s as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _schedules = [];
    }
    notifyListeners();
  }

  Future<void> addSchedule({
    required String employeeId,
    required String shiftId,
    required DateTime workDate,
    String? note,
  }) async {
    final dateStr =
        '${workDate.year}-${workDate.month.toString().padLeft(2, '0')}-${workDate.day.toString().padLeft(2, '0')}';
    try {
      await _api.createEmployeeSchedule({
        'employeeId': employeeId,
        'shiftId': shiftId,
        'workDate': dateStr,
        'note': note,
      });
      await loadSchedules();
    } catch (_) {
      notifyListeners();
    }
  }

  Future<void> removeSchedule(String id) async {
    try {
      await _api.deleteEmployeeSchedule(int.parse(id));
    } catch (_) {}
    _schedules.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  void _recalcRanks() {
    _employees.sort((a, b) => b.score.compareTo(a.score));
    for (var i = 0; i < _employees.length; i++) {
      _employees[i] = _employees[i].copyWith(rank: i + 1);
    }
  }
}
