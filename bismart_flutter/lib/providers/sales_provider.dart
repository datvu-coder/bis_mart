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
  String? _storeFilter; // null = tất cả cửa hàng
  // Phạm vi cửa hàng được phép xem (theo phân quyền). Rỗng = không giới hạn.
  Set<String> _allowedStoreCodes = const <String>{};
  String? _error;

  List<SalesReport> get reports => _reports;
  bool get isLoading => _isLoading;
  String get filterType => _filterType;
  DateTime? get customStart => _customStart;
  DateTime? get customEnd => _customEnd;
  String? get storeFilter => _storeFilter;
  Set<String> get allowedStoreCodes => _allowedStoreCodes;
  String? get error => _error;
  void clearError() { _error = null; notifyListeners(); }

  /// Distinct store codes/names appearing in the loaded reports, intersected
  /// with [allowedStoreCodes] when restriction is active.
  /// Returns list of (storeCode, storeName) tuples ordered by code.
  List<MapEntry<String, String>> get availableStores {
    final map = <String, String>{};
    for (final r in _reports) {
      final code = (r.storeCode ?? '').trim();
      if (code.isEmpty) continue;
      if (_allowedStoreCodes.isNotEmpty &&
          !_allowedStoreCodes.contains(code.toUpperCase())) {
        continue;
      }
      map[code] = (r.storeName ?? '').trim().isEmpty ? code : r.storeName!.trim();
    }
    final entries = map.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries;
  }

  List<SalesReport> get filteredReports {
    final now = DateTime.now();
    return _reports.where((r) {
      // Date scope
      bool inRange;
      switch (_filterType) {
        case 'today':
          inRange = r.date.year == now.year && r.date.month == now.month && r.date.day == now.day;
          break;
        case 'week':
          final weekAgo = now.subtract(const Duration(days: 7));
          inRange = r.date.isAfter(weekAgo);
          break;
        case 'month':
          inRange = r.date.year == now.year && r.date.month == now.month;
          break;
        case 'custom':
          if (_customStart == null || _customEnd == null) {
            inRange = true;
          } else {
            final s = DateTime(_customStart!.year, _customStart!.month, _customStart!.day);
            final e = DateTime(_customEnd!.year, _customEnd!.month, _customEnd!.day, 23, 59, 59);
            inRange = !r.date.isBefore(s) && !r.date.isAfter(e);
          }
          break;
        default:
          inRange = true;
      }
      if (!inRange) return false;

      // Phạm vi quản lý: loại bỏ những cửa hàng không thuộc quyền xem.
      if (_allowedStoreCodes.isNotEmpty) {
        if (!_allowedStoreCodes.contains((r.storeCode ?? '').toUpperCase())) {
          return false;
        }
      }

      // Store scope (lựa chọn của người dùng)
      if (_storeFilter != null && _storeFilter!.isNotEmpty) {
        if ((r.storeCode ?? '').toUpperCase() != _storeFilter!.toUpperCase()) {
          return false;
        }
      }
      return true;
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

  void setStoreFilter(String? storeCode) {
    _storeFilter = (storeCode == null || storeCode.isEmpty) ? null : storeCode;
    notifyListeners();
  }

  /// Giới hạn danh sách cửa hàng được phép xem theo phân quyền của người dùng.
  /// Truyền `null` hoặc collection rỗng để bỏ giới hạn (admin/quản trị).
  void setAllowedStoreCodes(Iterable<String>? codes) {
    final next = (codes == null)
        ? <String>{}
        : codes
            .map((c) => c.trim().toUpperCase())
            .where((c) => c.isNotEmpty)
            .toSet();
    if (next.length == _allowedStoreCodes.length &&
        next.containsAll(_allowedStoreCodes)) {
      return; // không đổi
    }
    _allowedStoreCodes = next;
    // Reset bộ lọc cửa hàng đang chọn nếu nó không còn nằm trong phạm vi.
    if (_storeFilter != null &&
        next.isNotEmpty &&
        !next.contains(_storeFilter!.toUpperCase())) {
      _storeFilter = null;
    }
    notifyListeners();
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
