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

  void addStore(Store store) async {
    try {
      final result = await _api.createStore(store.toJson());
      _stores.add(Store.fromJson(result));
    } catch (_) {
      _stores.add(store);
    }
    notifyListeners();
  }

  void updateStore(Store updated) async {
    try { await _api.updateStore(int.parse(updated.id), updated.toJson()); } catch (_) {}
    final index = _stores.indexWhere((s) => s.id == updated.id);
    if (index != -1) {
      _stores[index] = updated;
      notifyListeners();
    }
  }

  void deleteStore(String id) async {
    try { await _api.deleteStore(int.parse(id)); } catch (_) {}
    _stores.removeWhere((s) => s.id == id);
    notifyListeners();
  }
}
