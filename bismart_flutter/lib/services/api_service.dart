import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio _dio;

  static const _tokenKey = 'auth_token';

  // Change this to your VPS URL after deployment
  static const String _defaultBaseUrl = 'http://localhost:5000';

  String get baseUrl => _baseUrl;
  String _baseUrl = _defaultBaseUrl;

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        handler.next(error);
      },
    ));
  }

  void setBaseUrl(String url) {
    _baseUrl = url;
    _dio.options.baseUrl = url;
  }

  // Token management
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // ---- AUTH ----
  Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await _dio.post('/api/auth/login', data: {
      'username': username,
      'password': password,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMe() async {
    final response = await _dio.get('/api/auth/me');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final response = await _dio.put('/api/auth/profile', data: data);
    return response.data as Map<String, dynamic>;
  }

  // ---- EMPLOYEES ----
  Future<List<dynamic>> getEmployees() async {
    final response = await _dio.get('/api/employees');
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createEmployee(Map<String, dynamic> data) async {
    final response = await _dio.post('/api/employees', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateEmployee(int id, Map<String, dynamic> data) async {
    final response = await _dio.put('/api/employees/$id', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteEmployee(int id) async {
    await _dio.delete('/api/employees/$id');
  }

  // ---- ATTENDANCE ----
  Future<List<dynamic>> getAttendances({String? date}) async {
    final response = await _dio.get('/api/attendances',
        queryParameters: date != null ? {'date': date} : null);
    return response.data as List<dynamic>;
  }

  Future<void> checkIn(int employeeId) async {
    await _dio.post('/api/attendances/checkin', data: {'employeeId': employeeId});
  }

  Future<void> checkOut(int employeeId) async {
    await _dio.post('/api/attendances/checkout', data: {'employeeId': employeeId});
  }

  // ---- SHIFTS ----
  Future<List<dynamic>> getShifts() async {
    final response = await _dio.get('/api/shifts');
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createShift(Map<String, dynamic> data) async {
    final response = await _dio.post('/api/shifts', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteShift(int id) async {
    await _dio.delete('/api/shifts/$id');
  }

  // ---- STORES ----
  Future<List<dynamic>> getStores() async {
    final response = await _dio.get('/api/stores');
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createStore(Map<String, dynamic> data) async {
    final response = await _dio.post('/api/stores', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateStore(int id, Map<String, dynamic> data) async {
    final response = await _dio.put('/api/stores/$id', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteStore(int id) async {
    await _dio.delete('/api/stores/$id');
  }

  // ---- PRODUCTS ----
  Future<List<dynamic>> getProducts() async {
    final response = await _dio.get('/api/products');
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> data) async {
    final response = await _dio.post('/api/products', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateProduct(int id, Map<String, dynamic> data) async {
    final response = await _dio.put('/api/products/$id', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteProduct(int id) async {
    await _dio.delete('/api/products/$id');
  }

  // ---- REPORTS ----
  Future<List<dynamic>> getReports({String filter = 'all'}) async {
    final response = await _dio.get('/api/reports',
        queryParameters: {'filter': filter});
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createReport(Map<String, dynamic> data) async {
    final response = await _dio.post('/api/reports', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteReport(int id) async {
    await _dio.delete('/api/reports/$id');
  }

  // ---- POSTS ----
  Future<List<dynamic>> getPosts() async {
    final response = await _dio.get('/api/posts');
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createPost(Map<String, dynamic> data) async {
    final response = await _dio.post('/api/posts', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> toggleLike(int postId) async {
    final response = await _dio.post('/api/posts/$postId/like');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> addComment(int postId) async {
    final response = await _dio.post('/api/posts/$postId/comment');
    return response.data as Map<String, dynamic>;
  }

  Future<void> deletePost(int postId) async {
    await _dio.delete('/api/posts/$postId');
  }

  // ---- LESSONS ----
  Future<List<dynamic>> getLessons() async {
    final response = await _dio.get('/api/lessons');
    return response.data as List<dynamic>;
  }

  // ---- EVENTS ----
  Future<Map<String, dynamic>> getEvents() async {
    final response = await _dio.get('/api/events');
    return response.data as Map<String, dynamic>;
  }

  Future<void> createEvent(Map<String, dynamic> data) async {
    await _dio.post('/api/events', data: data);
  }

  Future<void> deleteEvent(Map<String, dynamic> data) async {
    await _dio.delete('/api/events', data: data);
  }

  // ---- DASHBOARD ----
  Future<Map<String, dynamic>> getDashboard({String filter = 'today'}) async {
    final response = await _dio.get('/api/dashboard',
        queryParameters: {'filter': filter});
    return response.data as Map<String, dynamic>;
  }
}
