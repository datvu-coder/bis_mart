import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/api_service.dart';

class ProductProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<Product> _products = [];
  bool _isLoading = false;
  String _selectedGroup = 'Tất cả';
  String _searchQuery = '';
  String? _error;

  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  String? get error => _error;
  void clearError() { _error = null; notifyListeners(); }
  String get selectedGroup => _selectedGroup;
  String get searchQuery => _searchQuery;

  List<Product> get filteredProducts {
    return _products.where((p) {
      final matchGroup =
          _selectedGroup == 'Tất cả' || p.productGroup == _selectedGroup;
      final matchSearch = _searchQuery.isEmpty ||
          p.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchGroup && matchSearch;
    }).toList();
  }

  int get productCount => _products.length;

  void setGroup(String group) {
    _selectedGroup = group;
    notifyListeners();
  }

  void setSearch(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> loadProducts() async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _api.getProducts();
      _products = data.map((p) => Product.fromJson(p as Map<String, dynamic>)).toList();
    } catch (e) {
      _error = 'Không thể tải dữ liệu sản phẩm';
    }

    _isLoading = false;
    notifyListeners();
  }

  Product? getProductById(String id) {
    try {
      return _products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  List<Product> getProductsByGroup(String group) {
    return _products.where((p) => p.productGroup == group).toList();
  }

  Future<bool> addProduct(Product product) async {
    try {
      final result = await _api.createProduct(product.toJson());
      _products.add(Product.fromJson(result));
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _describeError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProduct(Product updated) async {
    try {
      await _api.updateProduct(int.parse(updated.id), updated.toJson());
    } catch (e) {
      _error = _describeError(e);
      notifyListeners();
      return false;
    }
    final index = _products.indexWhere((p) => p.id == updated.id);
    if (index != -1) {
      _products[index] = updated;
      notifyListeners();
    }
    return true;
  }

  Future<bool> deleteProduct(String id) async {
    try {
      await _api.deleteProduct(int.parse(id));
    } catch (e) {
      _error = _describeError(e);
      notifyListeners();
      return false;
    }
    _products.removeWhere((p) => p.id == id);
    notifyListeners();
    return true;
  }

  Future<bool> adjustStock(String id, double delta) async {
    try {
      final result = await _api.adjustProductStock(int.parse(id), delta);
      final updated = Product.fromJson(result);
      final index = _products.indexWhere((p) => p.id == id);
      if (index != -1) {
        _products[index] = updated;
        notifyListeners();
      }
      _error = null;
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
