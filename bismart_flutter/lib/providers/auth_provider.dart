import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../models/employee.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final ApiService _api = ApiService();

  Employee? _currentUser;
  bool _isLoading = false;
  String? _error;

  AuthProvider({AuthService? authService})
      : _authService = authService ?? AuthService();

  Employee? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentUser != null;
  String? get error => _error;

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentUser = await _authService.login(email, password);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendlyLoginError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  String _friendlyLoginError(Object e) {
    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Kết nối đến máy chủ quá lâu. Vui lòng kiểm tra mạng và thử lại.';
        case DioExceptionType.connectionError:
          return 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra kết nối mạng.';
        case DioExceptionType.badResponse:
          final status = e.response?.statusCode;
          final data = e.response?.data;
          final serverMessage = (data is Map) ? data['error'] as String? : null;
          if (status == 401 || status == 400) {
            return 'Mã nhân viên hoặc mật khẩu không đúng.';
          }
          if (status != null && status >= 500) {
            return 'Hệ thống đang gặp sự cố. Vui lòng thử lại sau ít phút.';
          }
          return serverMessage ?? 'Đã có lỗi xảy ra. Vui lòng thử lại.';
        default:
          return 'Không thể kết nối đến máy chủ. Vui lòng thử lại.';
      }
    }
    return 'Đã có lỗi xảy ra. Vui lòng thử lại.';
  }

  Future<void> logout() async {
    await _authService.logout();
    _currentUser = null;
    notifyListeners();
  }

  Future<void> checkAuthStatus() async {
    final isLoggedIn = await _authService.isLoggedIn();
    if (isLoggedIn) {
      try {
        _currentUser = await _authService.getCurrentUser();
      } catch (_) {
        await _authService.logout();
        _currentUser = null;
      }
    }
    notifyListeners();
  }

  Future<void> updateProfile({String? fullName, String? email, String? position, String? workLocation}) async {
    if (_currentUser == null) return;
    try {
      final data = <String, dynamic>{};
      if (fullName != null) data['fullName'] = fullName;
      if (email != null) data['email'] = email;
      if (workLocation != null) data['workLocation'] = workLocation;
      final result = await _api.updateProfile(data);
      final userData = result['user'] as Map<String, dynamic>;
      _currentUser = Employee.fromJson(userData);
      notifyListeners();
    } catch (_) {
      // fallback: update locally
      _currentUser = _currentUser!.copyWith(
        fullName: fullName,
        email: email,
        position: position,
        workLocation: workLocation,
      );
      notifyListeners();
    }
  }
}
