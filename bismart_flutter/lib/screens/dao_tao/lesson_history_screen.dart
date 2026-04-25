import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/lesson.dart';
import '../../services/api_service.dart';

/// Lịch sử người tham gia học và làm bài test cho 1 bài giảng.
/// - Admin: thấy tất cả người dùng.
/// - User thường: thấy chỉ bản thân (server-side filter).
class LessonHistoryScreen extends StatefulWidget {
  final Lesson lesson;
  const LessonHistoryScreen({super.key, required this.lesson});

  @override
  State<LessonHistoryScreen> createState() => _LessonHistoryScreenState();
}

class _LessonHistoryScreenState extends State<LessonHistoryScreen> {
  bool _loading = true;
  String? _error;
  int _totalParts = 0;
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService().getLessonHistory(widget.lesson.id);
      if (!mounted) return;
      setState(() {
        _totalParts = (data['totalParts'] as num?)?.toInt() ?? 0;
        _users = ((data['users'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Không tải được lịch sử: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Lịch sử học tập'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(children: [
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red)),
                    ),
                  ])
                : _buildList(),
      ),
    );
  }

  Widget _buildList() {
    if (_users.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Icon(Icons.history_edu_rounded,
              size: 56, color: AppColors.textHint),
          const SizedBox(height: 12),
          Text('Chưa có ai tham gia bài giảng này.',
              textAlign: TextAlign.center, style: AppTextStyles.bodyText),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: _users.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        if (i == 0) return _header();
        return _userTile(_users[i - 1]);
      },
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.lesson.title, style: AppTextStyles.sectionHeader),
          const SizedBox(height: 4),
          Text('${_users.length} học viên • $_totalParts phần',
              style: AppTextStyles.caption),
        ],
      ),
    );
  }

  Widget _userTile(Map<String, dynamic> u) {
    final fullName = (u['fullName'] as String?) ?? '';
    final empCode = (u['employeeCode'] as String?) ?? '';
    final store = (u['storeName'] as String?) ?? '';
    final completed = (u['completedParts'] as num?)?.toInt() ?? 0;
    final total = (u['totalParts'] as num?)?.toInt() ?? _totalParts;
    final progress = total > 0 ? completed / total : 0.0;
    final isDone = total > 0 && completed >= total;
    final last = (u['lastSubmittedAt'] as String?) ?? '';
    final subs = ((u['submissions'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childrenPadding:
            const EdgeInsets.fromLTRB(12, 0, 12, 12),
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryLight,
          child: Text(
            fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
            style: const TextStyle(
                color: AppColors.primary, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(fullName.isEmpty ? empCode : fullName,
            style: AppTextStyles.bodyText
                .copyWith(fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$empCode${store.isNotEmpty ? ' • $store' : ''}',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                        backgroundColor: AppColors.surfaceVariant,
                        valueColor: AlwaysStoppedAnimation(
                          isDone ? AppColors.success : AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$completed/$total',
                    style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDone ? AppColors.success : AppColors.primary),
                  ),
                ],
              ),
              if (last.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Lần cuối: $last',
                      style: AppTextStyles.caption
                          .copyWith(fontSize: 11)),
                ),
            ],
          ),
        ),
        children: [
          for (final s in subs) _submissionRow(s),
        ],
      ),
    );
  }

  Widget _submissionRow(Map<String, dynamic> s) {
    final partId = (s['partId'] as String?) ?? '';
    final score = (s['score'] as String?) ?? '';
    final at = (s['submittedAt'] as String?) ?? '';
    String partTitle = 'Phần';
    if (partId.isNotEmpty) {
      try {
        final pid = int.parse(partId);
        final p = widget.lesson.parts.firstWhere(
          (e) => int.tryParse(e.id) == pid,
          orElse: () => widget.lesson.parts.isNotEmpty
              ? widget.lesson.parts.first
              : LessonPart(id: '0', lessonId: '', title: 'Phần $partId'),
        );
        partTitle = p.title.isEmpty ? 'Phần ${p.orderIndex}' : p.title;
      } catch (_) {}
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(Icons.task_alt_rounded,
              size: 16, color: AppColors.success),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              partTitle,
              style:
                  AppTextStyles.caption.copyWith(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (at.isNotEmpty)
            Text(at,
                style:
                    AppTextStyles.caption.copyWith(fontSize: 11)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              score,
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
