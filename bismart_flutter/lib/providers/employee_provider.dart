import 'package:flutter/material.dart';
import '../models/employee.dart';
import '../models/attendance.dart';
import '../models/work_shift.dart';
import '../services/api_service.dart';

class EmployeeProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<Employee> _employees = [];
  List<Attendance> _attendances = [];
  List<WorkShift> _shifts = [];
  bool _isLoading = false;

  List<Employee> get employees => _employees;
  List<Attendance> get attendances => _attendances;
  List<WorkShift> get shifts => _shifts;
  bool get isLoading => _isLoading;

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
        final e = _employees[i];
        _employees[i] = Employee(
          id: e.id, fullName: e.fullName, employeeCode: e.employeeCode,
          position: e.position, workLocation: e.workLocation,
          score: e.score, rank: i + 1, email: e.email,
        );
      }
      final shiftData = await _api.getShifts();
      _shifts = shiftData.map((s) => WorkShift.fromJson(s as Map<String, dynamic>)).toList();
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadAttendances() async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _api.getAttendances();
      _attendances = data.map((a) => Attendance.fromJson(a as Map<String, dynamic>)).toList();
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }

  Future<void> checkIn(String employeeId) async {
    try {
      await _api.checkIn(int.parse(employeeId));
      await loadAttendances();
    } catch (_) {}
  }

  Future<void> checkOut(String employeeId) async {
    try {
      await _api.checkOut(int.parse(employeeId));
      await loadAttendances();
    } catch (_) {}
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

  void _recalcRanks() {
    _employees.sort((a, b) => b.score.compareTo(a.score));
    for (var i = 0; i < _employees.length; i++) {
      final e = _employees[i];
      _employees[i] = Employee(
        id: e.id,
        fullName: e.fullName,
        employeeCode: e.employeeCode,
        position: e.position,
        workLocation: e.workLocation,
        score: e.score,
        rank: i + 1,
        email: e.email,
      );
    }
  }
}
