import 'package:flutter/material.dart';
import '../models/sales_report.dart';
import '../services/api_service.dart';

class SalesProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<SalesReport> _reports = [];
  bool _isLoading = false;
  String _filterType = 'today';
  DateTime? _customStart;
  DateTime? _customEnd;
  String? _error;

  List<SalesReport> get reports => _reports;
  bool get isLoading => _isLoading;
  String get filterType => _filterType;
  DateTime? get customStart => _customStart;
  DateTime? get customEnd => _customEnd;
  String? get error => _error;
  void clearError() { _error = null; notifyListeners(); }

  List<SalesReport> get filteredReports {
    final now = DateTime.now();
    return _reports.where((r) {
      switch (_filterType) {
        case 'today':
          return r.date.year == now.year && r.date.month == now.month && r.date.day == now.day;
        case 'week':
          final weekAgo = now.subtract(const Duration(days: 7));
          return r.date.isAfter(weekAgo);
        case 'month':
          return r.date.year == now.year && r.date.month == now.month;
        case 'custom':
          if (_customStart == null || _customEnd == null) return true;
          final s = DateTime(_customStart!.year, _customStart!.month, _customStart!.day);
          final e = DateTime(_customEnd!.year, _customEnd!.month, _customEnd!.day, 23, 59, 59);
          return !r.date.isBefore(s) && !r.date.isAfter(e);
        default:
          return true;
      }
    }).toList();
  }

  int get salesReportCount => filteredReports.length;
  double get totalRevenue =>
      filteredReports.fold(0, (sum, r) => sum + r.revenue);
  int get totalReportCount => _reports.length;

  void setFilter(String filter) {
    _filterType = filter;
    notifyListeners();
    loadReports();
  }

  void setCustomRange(DateTime start, DateTime end) {
    _filterType = 'custom';
    _customStart = start;
    _customEnd = end;
    notifyListeners();
    loadReports();
  }

  Future<void> loadReports() async {
    _isLoading = true;
    notifyListeners();

    try {
      // For custom range, fetch the full dataset and filter on the client.
      final apiFilter = _filterType == 'custom' ? 'all' : _filterType;
      final data = await _api.getReports(filter: apiFilter);
      _reports = data.map((r) => SalesReport.fromJson(r as Map<String, dynamic>)).toList();
    } catch (e) {
      _error = 'Không thể tải báo cáo';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createReport(SalesReport report) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _api.createReport(report.toJson());
      _reports.insert(0, SalesReport.fromJson(result));
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (_) {
      _error = 'Không thể lưu báo cáo lên máy chủ. Vui lòng thử lại.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> deleteReport(String id) async {
    try { await _api.deleteReport(int.parse(id)); } catch (_) {}
    _reports.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  Future<bool> updateReport(SalesReport report) async {
    try {
      final result = await _api.updateReport(int.parse(report.id), report.toJson());
      final updated = SalesReport.fromJson(result);
      final index = _reports.indexWhere((r) => r.id == report.id);
      if (index != -1) {
        _reports[index] = updated;
      }
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  SalesReport? getReportById(String id) {
    try {
      return _reports.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }
}
