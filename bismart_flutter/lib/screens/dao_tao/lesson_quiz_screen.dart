import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../services/api_service.dart';

class LessonQuizScreen extends StatefulWidget {
  final String lessonId;
  final String lessonTitle;
  final List<Map<String, dynamic>> questions;
  const LessonQuizScreen({
    super.key,
    required this.lessonId,
    required this.lessonTitle,
    required this.questions,
  });

  @override
  State<LessonQuizScreen> createState() => _LessonQuizScreenState();
}

class _LessonQuizScreenState extends State<LessonQuizScreen> {
  static const _letters = ['A', 'B', 'C', 'D'];
  final Map<String, String> _answers = {}; // questionId -> A/B/C/D
  bool _submitting = false;
  Map<String, dynamic>? _result;

  Future<void> _submit() async {
    if (_answers.length < widget.questions.length) {
      final pending = widget.questions.length - _answers.length;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Còn câu chưa trả lời'),
          content: Text('Bạn còn $pending câu chưa chọn đáp án. Vẫn nộp bài?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Quay lại')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Nộp bài')),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _submitting = true);
    try {
      final res = await ApiService().submitQuiz(
        lessonId: widget.lessonId,
        answers: _answers,
      );
      if (!mounted) return;
      setState(() => _result = res);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nộp bài thất bại: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Kiểm tra: ${widget.lessonTitle}',
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: _result != null ? _buildResult() : _buildQuestions(),
    );
  }

  Widget _buildQuestions() {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: widget.questions.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (ctx, i) {
            if (i == widget.questions.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline_rounded, size: 20),
                    label: Text(_submitting ? 'Đang nộp...' : 'Nộp bài'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              );
            }
            return _buildQuestionCard(i, widget.questions[i]);
          },
        ),
      ),
    );
  }

  Widget _buildQuestionCard(int index, Map<String, dynamic> q) {
    final qid = q['id'].toString();
    final options = (q['options'] as List?) ?? [];
    final selected = _answers[qid];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26, height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${index + 1}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  (q['question'] as String?) ?? '',
                  style: AppTextStyles.bodyTextMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (int oi = 0; oi < options.length; oi++)
            if (options[oi] != null && options[oi].toString().trim().isNotEmpty)
              _buildOption(qid, _letters[oi], options[oi].toString(),
                  selected == _letters[oi]),
        ],
      ),
    );
  }

  Widget _buildOption(String qid, String letter, String text, bool active) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() => _answers[qid] = letter),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.primaryLight : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active
                  ? AppColors.primary
                  : AppColors.border.withValues(alpha: 0.4),
              width: active ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 26, height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : AppColors.cardBg,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                      color: active ? AppColors.primary : AppColors.border),
                ),
                child: Text(letter,
                    style: TextStyle(
                        color: active ? Colors.white : AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(text, style: AppTextStyles.bodyText),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResult() {
    final r = _result!;
    final earned = (r['earned'] as num?)?.toInt() ?? 0;
    final total = (r['total'] as num?)?.toInt() ?? 0;
    final correct = (r['correctCount'] as num?)?.toInt() ?? 0;
    final qcount = (r['questionCount'] as num?)?.toInt() ?? 0;
    final percent = (r['scorePercent'] as num?)?.toDouble() ?? 0.0;
    final passed = percent >= 50;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: passed
                        ? AppColors.successLight
                        : AppColors.warningLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    passed ? Icons.celebration_rounded : Icons.school_rounded,
                    size: 36,
                    color: passed ? AppColors.success : AppColors.warning,
                  ),
                ),
                const SizedBox(height: 16),
                Text(passed ? 'Hoàn thành xuất sắc!' : 'Đã nộp bài',
                    style: AppTextStyles.appTitle),
                const SizedBox(height: 8),
                Text('Điểm: $earned / $total ($correct/$qcount câu đúng)',
                    style: AppTextStyles.bodyText),
                const SizedBox(height: 4),
                Text('${percent.toStringAsFixed(1)}%',
                    style: AppTextStyles.appTitle.copyWith(
                        color: passed ? AppColors.success : AppColors.warning)),
                const SizedBox(height: 4),
                Text('Kết quả đã được lưu cho ${r['fullName'] ?? 'bạn'}',
                    style: AppTextStyles.caption,
                    textAlign: TextAlign.center),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Đóng'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
