import 'package:flutter/material.dart';
import '../models/employee.dart';
import '../models/attendance.dart';
import '../models/work_shift.dart';
import '../models/work_schedule.dart';
import '../models/leave_request.dart';
import '../services/api_service.dart';

class EmployeeProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<Employee> _employees = [];
  List<Attendance> _attendances = [];
  List<Attendance> _historyAttendances = [];
  List<WorkShift> _shifts = [];
  List<WorkSchedule> _schedules = [];
  List<WorkSchedule> _todaySchedules = [];
  List<LeaveRequest> _leaveRequests = [];
  DateTime _scheduleWeekStart = _getMonday(DateTime.now());
  String? _selectedShiftStoreId;
  bool _isLoading = false;
  String? _error;

  // Monthly summary
  Map<String, dynamic> _monthlySummary = {};

  // Per-employee monthly hours report
  Map<String, dynamic> _hoursReport = {};

  List<Employee> get employees => _employees;
  List<Attendance> get attendances => _attendances;
  List<Attendance> get historyAttendances => _historyAttendances;
  List<WorkShift> get shifts => _shifts;
  List<WorkSchedule> get schedules => _schedules;
  List<WorkSchedule> get todaySchedules => _todaySchedules;
  List<LeaveRequest> get leaveRequests => _leaveRequests;
  DateTime get scheduleWeekStart => _scheduleWeekStart;
  String? get selectedShiftStoreId => _selectedShiftStoreId;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic> get monthlySummary => _monthlySummary;
  Map<String, dynamic> get hoursReport => _hoursReport;
  List<Map<String, dynamic>> get hoursReportRows {
    final raw = _hoursReport['rows'];
    if (raw is List) {
      return raw.cast<Map<String, dynamic>>();
    }
    return const [];
  }
  void clearError() { _error = null; notifyListeners(); }

  static DateTime _getMonday(DateTime d) {
    final diff = d.weekday - 1;
    return DateTime(d.year, d.month, d.day - diff);
  }

  /// Blends each employee's manually-set `score` with a bonus/penalty
  /// derived from this month's actual attendance quality (late/early-leave
  /// minutes penalize, overtime minutes reward) — so the leaderboard isn't
  /// purely a hand-entered number disconnected from the attendance data
  /// the app already collects. Employees with no hours-report row this
  /// month (out of scope of the currently-loaded report, or no attendance
  /// yet) simply get no adjustment, never a crash.
  List<Employee> get rankedEmployees {
    final bonusByEmployeeId = <String, int>{};
    for (final row in hoursReportRows) {
      final empId = row['employeeId']?.toString();
      if (empId == null) continue;
      final lateMin = (row['lateMinutes'] as num?)?.toInt() ?? 0;
      final earlyMin = (row['earlyLeaveMinutes'] as num?)?.toInt() ?? 0;
      final otMin = (row['overtimeMinutes'] as num?)?.toInt() ?? 0;
      bonusByEmployeeId[empId] = ((otMin * 0.1) - (lateMin * 0.3) - (earlyMin * 0.3)).round();
    }
    final sorted = _employees.map((e) {
      final bonus = bonusByEmployeeId[e.id] ?? 0;
      return bonus == 0 ? e : e.copyWith(score: e.score + bonus);
    }).toList();
    sorted.sort((a, b) => b.score.compareTo(a.score));
    for (var i = 0; i < sorted.length; i++) {
      sorted[i] = sorted[i].copyWith(rank: i + 1);
    }
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
      final shiftData = await _api.getShifts(storeId: _selectedShiftStoreId);
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

  Future<bool> updateAttendance(
    String id, {
    DateTime? checkInTime,
    DateTime? checkOutTime,
    bool clearCheckIn = false,
    bool clearCheckOut = false,
    DateTime? historyDate,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (clearCheckIn) {
        body['checkInTime'] = null;
      } else if (checkInTime != null) {
        body['checkInTime'] =
            '${checkInTime.hour.toString().padLeft(2, '0')}:${checkInTime.minute.toString().padLeft(2, '0')}:00';
      }
      if (clearCheckOut) {
        body['checkOutTime'] = null;
      } else if (checkOutTime != null) {
        body['checkOutTime'] =
            '${checkOutTime.hour.toString().padLeft(2, '0')}:${checkOutTime.minute.toString().padLeft(2, '0')}:00';
      }
      await _api.updateAttendance(int.parse(id), body);
      await loadAttendances();
      if (historyDate != null) {
        await loadAttendancesByDate(historyDate);
      }
      return true;
    } catch (e) {
      _error = 'Cập nhật chấm công thất bại';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteAttendance(String id, {DateTime? historyDate}) async {
    try {
      await _api.deleteAttendance(int.parse(id));
      await loadAttendances();
      if (historyDate != null) {
        await loadAttendancesByDate(historyDate);
      }
      return true;
    } catch (e) {
      _error = 'Xoá chấm công thất bại';
      notifyListeners();
      return false;
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

  Future<void> loadHoursReport({String? month, String? storeCode}) async {
    try {
      _hoursReport = await _api.getAttendanceHoursReport(
        month: month,
        storeCode: storeCode,
      );
    } catch (_) {
      _hoursReport = {};
    }
    notifyListeners();
  }

  Future<void> addShift(WorkShift shift) async {
    await _api.createShift(shift.toJson());
    final shiftData = await _api.getShifts(storeId: _selectedShiftStoreId);
    _shifts = shiftData.map((s) => WorkShift.fromJson(s as Map<String, dynamic>)).toList();
    notifyListeners();
  }

  Future<void> loadShifts({String? storeId}) async {
    _selectedShiftStoreId = storeId;
    try {
      final shiftData = await _api.getShifts(storeId: storeId);
      _shifts = shiftData.map((s) => WorkShift.fromJson(s as Map<String, dynamic>)).toList();
    } catch (_) {}
    notifyListeners();
  }

  Future<void> removeShift(String shiftId) async {
    await _api.deleteShift(int.parse(shiftId));
    _shifts.removeWhere((s) => s.id == shiftId);
    notifyListeners();
  }

  Future<void> addEmployee(Employee employee) async {
    final result = await _api.createEmployee(employee.toJson());
    _employees.add(Employee.fromJson(result));
    _recalcRanks();
    notifyListeners();
  }

  Future<void> updateEmployee(Employee updated) async {
    await _api.updateEmployee(int.parse(updated.id), updated.toJson());
    final index = _employees.indexWhere((e) => e.id == updated.id);
    if (index != -1) {
      _employees[index] = updated;
      _recalcRanks();
      notifyListeners();
    }
  }

  Future<void> deleteEmployee(String id) async {
    await _api.deleteEmployee(int.parse(id));
    _employees.removeWhere((e) => e.id == id);
    _attendances.removeWhere((a) => a.employeeId == id);
    _recalcRanks();
    notifyListeners();
  }

  Future<void> assignEmployeeToStore(String employeeId, String? storeCode) async {
    await _api.updateEmployee(int.parse(employeeId), {'storeCode': storeCode});
    final index = _employees.indexWhere((e) => e.id == employeeId);
    if (index != -1) {
      _employees[index] = _employees[index].copyWith(storeCode: storeCode);
      notifyListeners();
    }
  }

  Employee? getEmployeeById(String id) {
    try {
      return _employees.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  String? _scheduleStoreCode;
  String? get scheduleStoreCode => _scheduleStoreCode;

  Future<void> loadSchedules({DateTime? weekStart, String? storeCode}) async {
    final monday = weekStart ?? _scheduleWeekStart;
    _scheduleWeekStart = monday;
    if (storeCode != null) _scheduleStoreCode = storeCode;
    final weekStr =
        '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
    try {
      final data = await _api.getEmployeeSchedules(
        week: weekStr,
        storeCode: _scheduleStoreCode,
      );
      _schedules = data
          .map((s) => WorkSchedule.fromJson(s as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _schedules = [];
    }
    notifyListeners();
  }

  /// [repeatWeeks] > 1 also creates the same employee/shift assignment on
  /// the same weekday for the following weeks (e.g. a recurring Monday
  /// shift), so a manager doesn't have to repeat the assignment by hand.
  Future<void> addSchedule({
    required String employeeId,
    required String shiftId,
    required DateTime workDate,
    String? note,
    int repeatWeeks = 1,
  }) async {
    for (var i = 0; i < repeatWeeks; i++) {
      final date = workDate.add(Duration(days: 7 * i));
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      await _api.createEmployeeSchedule({
        'employeeId': employeeId,
        'shiftId': shiftId,
        'workDate': dateStr,
        'note': note,
      });
    }
    await loadSchedules();
  }

  Future<void> removeSchedule(String id) async {
    await _api.deleteEmployeeSchedule(int.parse(id));
    _schedules.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  /// Independent of [scheduleWeekStart] (which the Lịch làm việc week-grid
  /// screen can navigate away from) so "who's scheduled today" on the
  /// Chấm công tab always reflects today regardless of what week the
  /// schedule screen happens to be showing.
  Future<void> loadTodaySchedule({String? storeCode}) async {
    final now = DateTime.now();
    final monday = _getMonday(now);
    final weekStr =
        '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
    try {
      final data = await _api.getEmployeeSchedules(week: weekStr, storeCode: storeCode);
      final all = data.map((s) => WorkSchedule.fromJson(s as Map<String, dynamic>)).toList();
      _todaySchedules = all
          .where((s) =>
              s.workDate.year == now.year &&
              s.workDate.month == now.month &&
              s.workDate.day == now.day)
          .toList();
    } catch (_) {
      _todaySchedules = [];
    }
    notifyListeners();
  }

  Future<void> loadLeaveRequests({String? storeCode, String? status}) async {
    try {
      final data = await _api.getLeaveRequests(storeCode: storeCode, status: status);
      _leaveRequests = data.map((r) => LeaveRequest.fromJson(r as Map<String, dynamic>)).toList();
    } catch (_) {
      _leaveRequests = [];
    }
    notifyListeners();
  }

  Future<bool> submitLeaveRequest({
    required DateTime startDate,
    required DateTime endDate,
    required String leaveType,
    String? reason,
  }) async {
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    try {
      final result = await _api.createLeaveRequest({
        'startDate': fmt(startDate),
        'endDate': fmt(endDate),
        'leaveType': leaveType,
        'reason': reason,
      });
      _leaveRequests.insert(0, LeaveRequest.fromJson(result));
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Gửi đơn nghỉ phép thất bại';
      notifyListeners();
      return false;
    }
  }

  Future<bool> _setLeaveStatus(String id, String status) async {
    try {
      final result = await _api.updateLeaveRequestStatus(int.parse(id), status);
      final updated = LeaveRequest.fromJson(result);
      final index = _leaveRequests.indexWhere((r) => r.id == id);
      if (index != -1) _leaveRequests[index] = updated;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Cập nhật đơn nghỉ phép thất bại';
      notifyListeners();
      return false;
    }
  }

  Future<bool> approveLeaveRequest(String id) => _setLeaveStatus(id, 'approved');
  Future<bool> rejectLeaveRequest(String id) => _setLeaveStatus(id, 'rejected');

  Future<bool> cancelLeaveRequest(String id) async {
    try {
      await _api.deleteLeaveRequest(int.parse(id));
      _leaveRequests.removeWhere((r) => r.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Huỷ đơn nghỉ phép thất bại';
      notifyListeners();
      return false;
    }
  }

  void _recalcRanks() {
    _employees.sort((a, b) => b.score.compareTo(a.score));
    for (var i = 0; i < _employees.length; i++) {
      _employees[i] = _employees[i].copyWith(rank: i + 1);
    }
  }
}
