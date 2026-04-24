import 'package:flutter/material.dart';
import '../models/dashboard_data.dart';
import '../services/api_service.dart';

class DashboardProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  DashboardData? _data;
  bool _isLoading = false;
  String _filterType = 'today';
  String? _error;

  DashboardData? get data => _data;
  bool get isLoading => _isLoading;
  String get filterType => _filterType;
  String? get error => _error;
  void clearError() { _error = null; notifyListeners(); }

  void setFilter(String filter) {
    _filterType = filter;
    notifyListeners();
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final json = await _api.getDashboard(filter: _filterType);
      _data = DashboardData.fromJson(json);
    } catch (e) {
      _error = 'Không thể tải dashboard';
    }

    _isLoading = false;
    notifyListeners();
  }
}
