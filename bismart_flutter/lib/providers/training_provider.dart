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
  String? _error;

  List<CommunityPost> get posts => _posts;
  List<Lesson> get lessons => _lessons;
  Map<DateTime, List<String>> get events => _events;
  bool get isLoading => _isLoading;
  String? get error => _error;
  void clearError() { _error = null; notifyListeners(); }

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
    } catch (e) {
      _error = 'Không thể tải dữ liệu đào tạo';
    }

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

  Future<void> createPost(
    String content, {
    String? authorName,
    String? authorId,
    String visibility = 'public',
    String? storeCode,
    List<String>? imageDataUrls,
  }) async {
    final images = imageDataUrls ?? [];
    try {
      final result = await _api.createPost({
        'content': content,
        'authorName': authorName ?? 'Bạn',
        'authorId': authorId,
        'visibility': visibility,
        'storeCode': storeCode,
      });
      final post = CommunityPost.fromJson(result);
      // Attach local preview images if API doesn't return them
      if (images.isNotEmpty && post.imageUrls.isEmpty) {
        _posts.insert(0, CommunityPost(
          id: post.id,
          authorId: post.authorId,
          authorName: post.authorName,
          createdAt: post.createdAt,
          content: post.content,
          imageUrls: images,
          visibility: post.visibility,
          storeCode: post.storeCode,
        ));
      } else {
        _posts.insert(0, post);
      }
    } catch (_) {
      _posts.insert(
        0,
        CommunityPost(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          authorId: authorId,
          authorName: authorName ?? 'Bạn',
          createdAt: DateTime.now(),
          content: content,
          imageUrls: images,
          visibility: visibility,
          storeCode: storeCode,
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

  void addCommentText(String postId, String text, {String authorName = 'Bạn'}) {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index != -1) {
      _posts[index].comments.add(
        PostComment(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          authorName: authorName,
          text: text,
          createdAt: DateTime.now(),
        ),
      );
      _posts[index].commentCount++;
      notifyListeners();
      try { _api.addComment(int.parse(postId)); } catch (_) {}
    }
  }

  void deletePost(String postId) async {
    try { await _api.deletePost(int.parse(postId)); } catch (_) {}
    _posts.removeWhere((p) => p.id == postId);
    notifyListeners();
  }

  Future<void> updatePost(
    String postId, {
    required String content,
    required String visibility,
  }) async {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    final old = _posts[index];
    final updated = CommunityPost(
      id: old.id,
      authorId: old.authorId,
      authorName: old.authorName,
      createdAt: old.createdAt,
      content: content,
      imageUrls: old.imageUrls,
      visibility: visibility,
      storeCode: old.storeCode,
      likeCount: old.likeCount,
      commentCount: old.commentCount,
      isLiked: old.isLiked,
      comments: old.comments,
    );

    _posts[index] = updated;
    notifyListeners();

    try {
      await _api.updatePost(int.parse(postId), {
        'content': content,
        'visibility': visibility,
      });
    } catch (_) {}
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
    try {
      await _api.deleteEvent({'title': title, 'date': key.toIso8601String()});
    } catch (_) {}
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
