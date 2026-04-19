import 'package:flutter/material.dart';
import '../models/community_post.dart';
import '../models/lesson.dart';
import '../services/api_service.dart';

class TrainingProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<CommunityPost> _posts = [];
  List<Lesson> _lessons = [];
  Map<DateTime, List<String>> _events = {};
  bool _isLoading = false;

  List<CommunityPost> get posts => _posts;
  List<Lesson> get lessons => _lessons;
  Map<DateTime, List<String>> get events => _events;
  bool get isLoading => _isLoading;

  Future<void> loadTrainingData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final postData = await _api.getPosts();
      _posts = postData.map((p) => CommunityPost.fromJson(p as Map<String, dynamic>)).toList();

      final lessonData = await _api.getLessons();
      _lessons = lessonData.map((l) => Lesson.fromJson(l as Map<String, dynamic>)).toList();

      final eventData = await _api.getEvents();
      _events = {};
      eventData.forEach((dateStr, titles) {
        final date = DateTime.tryParse(dateStr);
        if (date != null) {
          final key = DateTime.utc(date.year, date.month, date.day);
          _events[key] = (titles as List<dynamic>).map((t) => t as String).toList();
        }
      });
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }

  void toggleLike(String postId) async {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index != -1) {
      final post = _posts[index];
      post.isLiked = !post.isLiked;
      post.likeCount += post.isLiked ? 1 : -1;
      notifyListeners();
      try { await _api.toggleLike(int.parse(postId)); } catch (_) {}
    }
  }

  Future<void> createPost(String content, {String? authorName}) async {
    try {
      final result = await _api.createPost({'content': content, 'authorName': authorName ?? 'Bạn'});
      _posts.insert(0, CommunityPost.fromJson(result));
    } catch (_) {
      _posts.insert(
        0,
        CommunityPost(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          authorName: authorName ?? 'Bạn',
          createdAt: DateTime.now(),
          content: content,
          likeCount: 0,
          commentCount: 0,
        ),
      );
    }
    notifyListeners();
  }

  void addComment(String postId) async {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index != -1) {
      _posts[index].commentCount++;
      notifyListeners();
      try { await _api.addComment(int.parse(postId)); } catch (_) {}
    }
  }

  void deletePost(String postId) async {
    try { await _api.deletePost(int.parse(postId)); } catch (_) {}
    _posts.removeWhere((p) => p.id == postId);
    notifyListeners();
  }

  void addEvent(DateTime date, String title) async {
    final key = DateTime.utc(date.year, date.month, date.day);
    try {
      await _api.createEvent({'title': title, 'date': key.toIso8601String()});
    } catch (_) {}
    if (_events.containsKey(key)) {
      _events[key]!.add(title);
    } else {
      _events[key] = [title];
    }
    notifyListeners();
  }

  void removeEvent(DateTime date, String title) async {
    final key = DateTime.utc(date.year, date.month, date.day);
    // Find event id from API if possible, then delete
    try { /* API event deletion needs event id - for now just local */ } catch (_) {}
    _events[key]?.remove(title);
    if (_events[key]?.isEmpty ?? false) {
      _events.remove(key);
    }
    notifyListeners();
  }

  List<String> getEventsForDay(DateTime day) {
    final key = DateTime.utc(day.year, day.month, day.day);
    return _events[key] ?? [];
  }
}
