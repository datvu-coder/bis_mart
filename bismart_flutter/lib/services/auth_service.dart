import '../models/employee.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _api = ApiService();

  AuthService();

  Future<String?> getToken() async {
    return _api.getToken();
  }

  Future<bool> isLoggedIn() async {
    return _api.hasToken();
  }

  Future<void> logout() async {
    await _api.clearToken();
  }

  Future<Employee> login(String username, String password) async {
    final result = await _api.login(username, password);
    final token = result['token'] as String;
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
