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

  // Track in-flight toggleLike to prevent rapid double-taps from racing.
  final Set<String> _likeInFlight = <String>{};

  void toggleLike(String postId) async {
    if (_likeInFlight.contains(postId)) return;
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;
    final post = _posts[index];
    final prevLiked = post.isLiked;
    final prevCount = post.likeCount;
    // Optimistic toggle
    post.isLiked = !prevLiked;
    post.likeCount = (prevCount + (post.isLiked ? 1 : -1)).clamp(0, 1 << 31);
    _likeInFlight.add(postId);
    notifyListeners();
    try {
      final res = await _api.toggleLike(int.parse(postId));
      // Reconcile with server truth
      post.isLiked = (res['liked'] as bool?) ?? post.isLiked;
      post.likeCount = (res['likeCount'] as int?) ?? post.likeCount;
    } catch (_) {
      // Rollback on failure
      post.isLiked = prevLiked;
      post.likeCount = prevCount;
    } finally {
      _likeInFlight.remove(postId);
      notifyListeners();
    }
  }

  Future<void> createPost(
    String content, {
    String? authorName,
    String? authorId,
    String visibility = 'public',
    String? storeCode,
    List<String>? imageDataUrls,
    String? videoUrl,
  }) async {
    final images = imageDataUrls ?? [];
    final result = await _api.createPost({
      'content': content,
      'authorName': authorName ?? 'Bạn',
      'authorId': authorId,
      'visibility': visibility,
      'storeCode': storeCode,
      'imageUrls': images,
      if (videoUrl != null && videoUrl.isNotEmpty) 'videoUrl': videoUrl,
    });
    final post = CommunityPost.fromJson(result);
    _posts.insert(0, post);
    notifyListeners();
  }

  void addComment(String postId) async {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index != -1) {
      _posts[index].commentCount++;
      notifyListeners();
      try { await _api.addComment(int.parse(postId), text: '', authorName: 'Bạn'); } catch (_) {}
    }
  }

  void addCommentText(String postId, String text, {String authorName = 'Bạn'}) async {
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
      try { await _api.addComment(int.parse(postId), text: text, authorName: authorName); } catch (_) {}
    }
  }

  /// Fetch comments for a single post from the server and replace the locally
  /// cached list. Safe to call from a screen's initState — silently ignores
  /// errors so a flaky network won't crash the detail view.
  Future<void> loadComments(String postId) async {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;
    try {
      final raw = await _api.getComments(int.parse(postId));
      final list = <PostComment>[];
      for (final item in raw) {
        if (item is! Map) continue;
        final m = item.cast<String, dynamic>();
        final created = DateTime.tryParse(m['createdAt']?.toString() ?? '') ??
            DateTime.now();
        list.add(PostComment(
          id: (m['id'] ?? '').toString(),
          authorName: (m['authorName'] ?? 'Ẩn danh').toString(),
          text: (m['text'] ?? '').toString(),
          createdAt: created,
        ));
      }
      _posts[index].comments
        ..clear()
        ..addAll(list);
      // Server is the source of truth for the count too.
      _posts[index].commentCount = list.length;
      notifyListeners();
    } catch (_) {
      // Swallow errors so the detail screen still shows whatever cache we have.
    }
  }

  Future<void> deletePost(String postId) async {
    await _api.deletePost(int.parse(postId));
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

    await _api.updatePost(int.parse(postId), {
      'content': content,
      'visibility': visibility,
    });
  }

  Future<void> createLesson(Map<String, dynamic> data) async {
    await _api.createLesson(data);
    final lessonData = await _api.getLessons();
    _lessons = lessonData
        .map((l) => Lesson.fromJson(l as Map<String, dynamic>))
        .toList();
    notifyListeners();
  }

  Future<void> deleteLesson(String lessonId) async {
    await _api.deleteLesson(lessonId);
    _lessons.removeWhere((l) => l.id == lessonId);
    notifyListeners();
  }

  Future<void> addEvent(DateTime date, String title) async {
    final key = DateTime.utc(date.year, date.month, date.day);
    await _api.createEvent({'title': title, 'date': key.toIso8601String()});
    if (_events.containsKey(key)) {
      _events[key]!.add(title);
    } else {
      _events[key] = [title];
    }
    notifyListeners();
  }

  Future<void> removeEvent(DateTime date, String title) async {
    final key = DateTime.utc(date.year, date.month, date.day);
    await _api.deleteEvent({'title': title, 'date': key.toIso8601String()});
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
