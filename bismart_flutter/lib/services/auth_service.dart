import 'package:shared_preferences/shared_preferences.dart';
import '../models/employee.dart';
import 'api_service.dart';

class AuthService {
  static const _tokenKey = 'auth_token';

  final ApiService _api = ApiService();

  AuthService();

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> logout() async {
    await _api.clearToken();
    await clearToken();
  }

  Future<Employee> login(String username, String password) async {
    final result = await _api.login(username, password);
    final token = result['token'] as String;
    await saveToken(token);
    await _api.saveToken(token);
    final userData = result['user'] as Map<String, dynamic>;
    return Employee.fromJson(userData);
  }

  Future<Employee?> getCurrentUser() async {
    final result = await _api.getMe();
    final userData = result['user'];
    if (userData == null) return null;
    return Employee.fromJson(userData as Map<String, dynamic>);
  }
}
