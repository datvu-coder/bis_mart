import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio _dio;

  static const _tokenKey = 'auth_token';

  static const String _defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.bismart.id.vn',
  );

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
    final normalizedUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (normalizedUrl.isEmpty) return;
    _baseUrl = normalizedUrl;
    _dio.options.baseUrl = normalizedUrl;
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

  Future<Map<String, dynamic>> checkIn(int employeeId, {double? latitude, double? longitude}) async {
    final data = <String, dynamic>{'employeeId': employeeId};
    if (latitude != null) data['latitude'] = latitude;
    if (longitude != null) data['longitude'] = longitude;
    final response = await _dio.post('/api/attendances/checkin', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> checkOut(int employeeId, {double? latitude, double? longitude}) async {
    final data = <String, dynamic>{'employeeId': employeeId};
    if (latitude != null) data['latitude'] = latitude;
    if (longitude != null) data['longitude'] = longitude;
    final response = await _dio.post('/api/attendances/checkout', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMonthlyAttendanceSummary({String? month, int? employeeId}) async {
    final params = <String, dynamic>{};
    if (month != null) params['month'] = month;
    if (employeeId != null) params['employeeId'] = employeeId;
    final response = await _dio.get('/api/attendances/monthly-summary', queryParameters: params);
    return response.data as Map<String, dynamic>;
  }

  // ---- SHIFTS ----
  Future<List<dynamic>> getShifts({String? storeId}) async {
    final response = await _dio.get('/api/shifts',
        queryParameters: storeId != null ? {'storeId': storeId} : null);
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createShift(Map<String, dynamic> data) async {
    final response = await _dio.post('/api/shifts', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteShift(int id) async {
    await _dio.delete('/api/shifts/$id');
  }

  // ---- EMPLOYEE SCHEDULES ----
  Future<List<dynamic>> getEmployeeSchedules({String? week}) async {
    final response = await _dio.get(
      '/api/employee-schedules',
      queryParameters: week != null ? {'week': week} : null,
    );
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createEmployeeSchedule(Map<String, dynamic> data) async {
    final response = await _dio.post('/api/employee-schedules', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteEmployeeSchedule(int id) async {
    await _dio.delete('/api/employee-schedules/$id');
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

  Future<Map<String, dynamic>> updateReport(int id, Map<String, dynamic> data) async {
    final response = await _dio.put('/api/reports/$id', data: data);
    return response.data as Map<String, dynamic>;
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

  Future<Map<String, dynamic>> addComment(int postId, {String text = '', String authorName = 'Bạn'}) async {
    final response = await _dio.post('/api/posts/$postId/comment', data: {'text': text, 'authorName': authorName});
    return response.data as Map<String, dynamic>;
  }

  Future<void> deletePost(int postId) async {
    await _dio.delete('/api/posts/$postId');
  }

  Future<Map<String, dynamic>> updatePost(int postId, Map<String, dynamic> data) async {
    final response = await _dio.put('/api/posts/$postId', data: data);
    return response.data as Map<String, dynamic>;
  }

  // ---- LESSONS ----
  Future<List<dynamic>> getLessons() async {
    final response = await _dio.get('/api/lessons');
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getLessonDetail(String lessonId) async {
    final response = await _dio.get('/api/lessons/$lessonId');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createLesson(Map<String, dynamic> data) async {
    final response = await _dio.post('/api/lessons', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteLesson(String lessonId) async {
    await _dio.delete('/api/lessons/$lessonId');
  }

  Future<Map<String, dynamic>> submitQuiz({
    required String lessonId,
    required Map<String, String> answers,
  }) async {
    final response = await _dio.post('/api/quiz/submit',
        data: {'lessonId': lessonId, 'answers': answers});
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getQuizResults({String? lessonId, String scope = 'self'}) async {
    final response = await _dio.get('/api/quiz/results',
        queryParameters: {
          if (lessonId != null) 'lessonId': lessonId,
          'scope': scope,
        });
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

  // ---- PERMISSIONS ----
  Future<List<dynamic>> getPermissions() async {
    final response = await _dio.get('/api/permissions');
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getPermissionByPosition(String position) async {
    final response = await _dio.get('/api/permissions/$position');
    return response.data as Map<String, dynamic>;
  }

  // ---- COURSES (LMS) ----
  Future<List<dynamic>> getCourses() async {
    final response = await _dio.get('/api/courses');
    return response.data as List<dynamic>;
  }

  Future<List<dynamic>> getCourseEnrollments(String courseId) async {
    final response = await _dio.get('/api/courses/$courseId/enrollments');
    return response.data as List<dynamic>;
  }

  Future<List<dynamic>> getCourseCompletions(String courseId) async {
    final response = await _dio.get('/api/courses/$courseId/completions');
    return response.data as List<dynamic>;
  }

  // ---- QUIZ ----
  Future<List<dynamic>> getQuizQuestions(String contentId) async {
    final response = await _dio.get('/api/quiz/$contentId');
    return response.data as List<dynamic>;
  }

  // ---- CLASS SCHEDULES ----
  Future<List<dynamic>> getClassSchedules() async {
    final response = await _dio.get('/api/class-schedules');
    return response.data as List<dynamic>;
  }

  // ---- AI TOOLS ----
  Future<List<dynamic>> getAiTools() async {
    final response = await _dio.get('/api/ai-tools');
    return response.data as List<dynamic>;
  }

  Future<List<dynamic>> getAiUsage({String? employeeCode}) async {
    final params = <String, dynamic>{};
    if (employeeCode != null) params['employeeCode'] = employeeCode;
    final response = await _dio.get('/api/ai-usage', queryParameters: params);
    return response.data as List<dynamic>;
  }

  // ---- COMMENTS ----
  Future<List<dynamic>> getComments(int postId) async {
    final response = await _dio.get('/api/posts/$postId/comments');
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createPermission(Map<String, dynamic> data) async {
    final response = await _dio.post('/api/permissions', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updatePermission(String position, Map<String, dynamic> data) async {
    final response = await _dio.put('/api/permissions/$position', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> deletePermission(String position) async {
    await _dio.delete('/api/permissions/$position');
  }

  // ---- STORE MANAGERS (phân công cửa hàng) ----
  Future<List<dynamic>> getStoreManagers() async {
    final response = await _dio.get('/api/store-managers');
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createStoreManager(Map<String, dynamic> data) async {
    final response = await _dio.post('/api/store-managers', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateStoreManager(int id, Map<String, dynamic> data) async {
    final response = await _dio.put('/api/store-managers/$id', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteStoreManager(int id) async {
    await _dio.delete('/api/store-managers/$id');
  }

  // ---- EFFECTIVE PERMISSIONS ----
  Future<Map<String, dynamic>> getMyEffectivePermissions() async {
    final response = await _dio.get('/api/me/permissions');
    return response.data as Map<String, dynamic>;
  }
}
