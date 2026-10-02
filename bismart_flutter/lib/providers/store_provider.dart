import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../models/store.dart';
import '../services/api_service.dart';

class StoreProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<Store> _stores = [];
  bool _isLoading = false;
  String _selectedGroup = 'Tất cả';
  String _searchQuery = '';
  String? _error;

  List<Store> get stores => _stores;
  bool get isLoading => _isLoading;
  String? get error => _error;
  void clearError() { _error = null; notifyListeners(); }
  String get selectedGroup => _selectedGroup;
  String get searchQuery => _searchQuery;

  List<Store> get filteredStores {
    return _stores.where((s) {
      final matchGroup =
          _selectedGroup == 'Tất cả' || s.group == _selectedGroup;
      final matchSearch = _searchQuery.isEmpty ||
          s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.storeCode.contains(_searchQuery);
      return matchGroup && matchSearch;
    }).toList();
  }

  int get storeCount => _stores.length;

  void setGroup(String group) {
    _selectedGroup = group;
    notifyListeners();
  }

  void setSearch(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> loadStores() async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _api.getStores();
      _stores = data.map((s) => Store.fromJson(s as Map<String, dynamic>)).toList();
    } catch (e) {
      _error = 'Không thể tải dữ liệu cửa hàng';
    }

    _isLoading = false;
    notifyListeners();
  }

  Store? getStoreById(String id) {
    try {
      return _stores.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  Store? getStoreByCode(String code) {
    try {
      return _stores.firstWhere(
          (s) => s.storeCode.toLowerCase() == code.toLowerCase());
    } catch (_) {
      return null;
    }
  }

  // A failed create/update/delete used to be swallowed silently and the
  // local list patched anyway (a fabricated store on a failed create, a
  // "saved" edit or a "deleted" store the server never touched) — the UI
  // showed success while the real backend state hadn't changed. These now
  // only mutate local state once the server call actually succeeds, and
  // report the failure via [error] otherwise, matching
  // EmployeeProvider's add/update/delete pattern.

  Future<bool> addStore(Store store) async {
    try {
      final result = await _api.createStore(store.toJson());
      _stores.add(Store.fromJson(result));
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _describeError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateStore(Store updated) async {
    try {
      await _api.updateStore(int.parse(updated.id), updated.toJson());
      final index = _stores.indexWhere((s) => s.id == updated.id);
      if (index != -1) _stores[index] = updated;
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _describeError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteStore(String id) async {
    try {
      await _api.deleteStore(int.parse(id));
      _stores.removeWhere((s) => s.id == id);
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _describeError(e);
      notifyListeners();
      return false;
    }
  }

  String _describeError(Object e) {
    if (e is DioException) {
      final status = e.response?.statusCode;
      final data = e.response?.data;
      final serverMessage = data is Map ? data['error']?.toString() : null;
      if (status == 401 || status == 403) {
        return 'Bạn không có quyền thực hiện thao tác này.';
      }
      if (serverMessage != null && serverMessage.isNotEmpty) {
        return serverMessage;
      }
      if (status != null) {
        return 'Lỗi máy chủ (mã $status).';
      }
      return 'Không thể kết nối đến máy chủ. Kiểm tra lại mạng.';
    }
    return e.toString();
  }
}
