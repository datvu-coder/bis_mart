import 'package:flutter/material.dart';
import '../models/sales_report.dart';
import '../services/api_service.dart';

class SalesProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<SalesReport> _reports = [];
  bool _isLoading = false;
  String _filterType = 'today';

  List<SalesReport> get reports => _reports;
  bool get isLoading => _isLoading;
  String get filterType => _filterType;

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

  Future<void> loadReports() async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _api.getReports(filter: _filterType);
      _reports = data.map((r) => SalesReport.fromJson(r as Map<String, dynamic>)).toList();
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createReport(SalesReport report) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _api.createReport(report.toJson());
      _reports.insert(0, SalesReport.fromJson(result));
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (_) {
      _reports.insert(0, report);
      _isLoading = false;
      notifyListeners();
      return true;
    }
  }

  void deleteReport(String id) async {
    try { await _api.deleteReport(int.parse(id)); } catch (_) {}
    _reports.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  SalesReport? getReportById(String id) {
    try {
      return _reports.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }
}
