import 'package:flutter/material.dart';
import '../models/course.dart';
import '../models/quiz.dart';
import '../models/class_schedule.dart';
import '../models/ai_tool.dart';
import '../models/permission.dart';
import '../services/api_service.dart';

class LmsProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<CourseTitle> _courses = [];
  List<QuizQuestion> _quizQuestions = [];
  List<QuizResult> _quizResults = [];
  List<ClassSchedule> _classSchedules = [];
  List<AiTool> _aiTools = [];
  List<AiUsageLog> _aiUsageLogs = [];
  List<Permission> _permissions = [];
  Permission? _currentPermission;
  bool _isLoading = false;
  String? _error;

  List<CourseTitle> get courses => _courses;
  List<QuizQuestion> get quizQuestions => _quizQuestions;
  List<QuizResult> get quizResults => _quizResults;
  List<ClassSchedule> get classSchedules => _classSchedules;
  List<AiTool> get aiTools => _aiTools;
  List<AiUsageLog> get aiUsageLogs => _aiUsageLogs;
  List<Permission> get permissions => _permissions;
  Permission? get currentPermission => _currentPermission;
  bool get isLoading => _isLoading;
  String? get error => _error;
  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> loadPermissions() async {
    try {
      final data = await _api.getPermissions();
      _permissions = data
          .map((p) => Permission.fromJson(p as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (e) {
      _error = 'Không thể tải phân quyền';
      notifyListeners();
    }
  }

  Future<void> loadPermissionForPosition(String position) async {
    try {
      final data = await _api.getPermissionByPosition(position);
      _currentPermission = Permission.fromJson(data);
      notifyListeners();
    } catch (_) {
      _currentPermission = null;
    }
  }

  Future<void> loadCourses() async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _api.getCourses();
      _courses = data
          .map((c) => CourseTitle.fromJson(c as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = 'Không thể tải khóa học';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadQuizQuestions(String contentId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _api.getQuizQuestions(contentId);
      _quizQuestions = data
          .map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = 'Không thể tải câu hỏi';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadQuizResults({String? contentId, String? employeeCode}) async {
    try {
      final lessonId = (contentId ?? '').replaceFirst('lesson_', '');
      final data = await _api.getQuizResults(
          lessonId: lessonId.isEmpty ? null : lessonId);
      _quizResults = data
          .map((r) => QuizResult.fromJson(r as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadClassSchedules() async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _api.getClassSchedules();
      _classSchedules = data
          .map((s) => ClassSchedule.fromJson(s as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = 'Không thể tải lịch học';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadAiTools() async {
    try {
      final data = await _api.getAiTools();
      _aiTools = data
          .map((t) => AiTool.fromJson(t as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadAiUsage({String? employeeCode}) async {
    try {
      final data = await _api.getAiUsage(employeeCode: employeeCode);
      _aiUsageLogs = data
          .map((l) => AiUsageLog.fromJson(l as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (_) {}
  }
}
