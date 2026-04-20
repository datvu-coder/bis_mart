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

  void addProduct(Product product) async {
    try {
      final result = await _api.createProduct(product.toJson());
      _products.add(Product.fromJson(result));
    } catch (_) {
      _products.add(product);
    }
    notifyListeners();
  }

  void updateProduct(Product updated) async {
    try { await _api.updateProduct(int.parse(updated.id), updated.toJson()); } catch (_) {}
    final index = _products.indexWhere((p) => p.id == updated.id);
    if (index != -1) {
      _products[index] = updated;
      notifyListeners();
    }
  }

  void deleteProduct(String id) async {
    try { await _api.deleteProduct(int.parse(id)); } catch (_) {}
    _products.removeWhere((p) => p.id == id);
    notifyListeners();
  }
}
