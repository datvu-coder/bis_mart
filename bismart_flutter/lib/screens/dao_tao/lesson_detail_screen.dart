import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/lesson.dart';
import '../../providers/auth_provider.dart';
import '../../providers/training_provider.dart';
import '../../services/api_service.dart';
import 'lesson_quiz_screen.dart';
import 'lesson_history_screen.dart';
import 'lesson_video_player.dart';

/// Multi-part lesson screen.
/// - Lists each part with progress badges.
/// - Sequential unlock: part N unlocks only when part N-1 quiz is submitted.
/// - Per-part native HTML5 video (anti-piracy guards) + per-part quiz.
class LessonDetailScreen extends StatefulWidget {
  final Lesson lesson;
  const LessonDetailScreen({super.key, required this.lesson});

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  bool _loading = true;
  String? _error;
  Lesson? _lesson;
  // Map<partId, true> for parts whose quiz has been submitted.
  final Set<String> _completedPartIds = {};
  String? _activePartId;

  bool get _isAdmin {
    final pos =
        (context.read<AuthProvider>().currentUser?.position ?? '').toUpperCase();
    return pos == 'ADM' || pos == 'ADMIN' || pos == 'TMK';
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final api = ApiService();
      final detail = await api.getLessonDetail(widget.lesson.id);
      final lesson = Lesson.fromJson(detail);
      // Pre-fill completed parts from server payload (lesson.completedPartCount
      // gives count, but we need IDs). Re-derive from `parts` via quiz results.
      try {
        final results = await api.getQuizResults(
            lessonId: widget.lesson.id, scope: 'self');
        for (final r in results) {
          if (r is Map && r['partId'] != null) {
            _completedPartIds.add(r['partId'].toString());
          }
        }
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _lesson = lesson;
        _loading = false;
        // Auto-expand first not-yet-completed part.
        _activePartId = lesson.parts
            .firstWhere(
              (p) => !_completedPartIds.contains(p.id),
              orElse: () => lesson.parts.isNotEmpty
                  ? lesson.parts.first
                  : LessonPart(id: '0', lessonId: '', title: ''),
            )
            .id;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Không tải được bài giảng: $e';
      });
    }
  }

  bool _isUnlocked(int index) {
    if (index == 0) return true;
    final prev = _lesson!.parts[index - 1];
    // Unlocked if previous has no quiz OR previous quiz already submitted.
    if (!prev.hasQuiz) return true;
    return _completedPartIds.contains(prev.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.lesson.title,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Lịch sử',
            onPressed: _lesson == null
                ? null
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            LessonHistoryScreen(lesson: _lesson!),
                      ),
                    ),
            icon: const Icon(Icons.history_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red)),
                  ),
                )
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final lesson = _lesson!;
    final completed = lesson.parts
        .where((p) => _completedPartIds.contains(p.id))
        .length;
    final total = lesson.parts.length;
    final progress = total == 0 ? 0.0 : completed / total;
    return RefreshIndicator(
      onRefresh: _bootstrap,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                              _buildHeader(progress, completed, total),
                    const SizedBox(height: 12),
                    if (_isAdmin)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: _addPart,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Thêm phần mới'),
                          ),
                        ),
                      ),
                    for (int i = 0; i < lesson.parts.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildPartTile(lesson.parts[i], i),
                      ),
                    if (lesson.parts.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Column(children: [
                          Icon(Icons.video_library_outlined,
                              size: 48, color: AppColors.textHint),
                          const SizedBox(height: 8),
                          Text('Bài giảng chưa có phần nào.',
                              style: AppTextStyles.bodyText),
                        ]),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(double progress, int completed, int total) {
    final isDone = total > 0 && completed >= total;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(AppRadius.row),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.lesson.title, style: AppTextStyles.sectionHeader),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Đối tượng: ${widget.lesson.targetRole}',
                    style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Text('$total phần', style: AppTextStyles.caption),
            ],
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.white,
                  valueColor: AlwaysStoppedAnimation(
                    isDone ? AppColors.success : AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '$completed/$total • ${(progress * 100).round()}%',
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: isDone ? AppColors.success : AppColors.primary,
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildPartTile(LessonPart part, int index) {
    final unlocked = _isUnlocked(index);
    final completed = _completedPartIds.contains(part.id);
    final active = _activePartId == part.id;
    final canExpand = unlocked;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: completed
              ? AppColors.success.withValues(alpha: 0.4)
              : (active
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : AppColors.border.withValues(alpha: 0.5)),
          width: active ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: canExpand
                ? () => setState(() {
                      _activePartId = active ? null : part.id;
                    })
                : null,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _statusBadge(index, completed, unlocked),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          part.title.isEmpty
                              ? 'Phần ${index + 1}'
                              : part.title,
                          style: AppTextStyles.bodyText
                              .copyWith(fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Wrap(spacing: 8, children: [
                          if (part.hasVideo)
                            _miniBadge(
                                Icons.play_circle_outline_rounded, 'Video'),
                          if (part.hasQuiz)
                            _miniBadge(Icons.quiz_outlined,
                                '${part.questionCount} câu'),
                          if (!unlocked)
                            _miniBadge(Icons.lock_rounded, 'Đã khoá',
                                color: AppColors.textGrey),
                          if (completed)
                            _miniBadge(Icons.check_circle_rounded, 'Hoàn thành',
                                color: AppColors.success),
                        ]),
                      ],
                    ),
                  ),
                  if (_isAdmin)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_rounded, size: 18),
                          tooltip: 'Sửa phần',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _editPart(part),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_rounded,
                              size: 18, color: AppColors.error),
                          tooltip: 'Xoá phần',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _deletePart(part),
                        ),
                      ],
                    )
                  else
                    Icon(
                      active
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: canExpand
                          ? AppColors.textGrey
                          : AppColors.textHint,
                    ),
                ],
              ),
            ),
          ),
          if (active && unlocked)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: _PartContent(
                key: ValueKey('part-${part.id}'),
                lesson: _lesson!,
                part: part,
                alreadyCompleted: completed,
                onQuizSubmitted: () {
                  setState(() {
                    _completedPartIds.add(part.id);
                    final idx =
                        _lesson!.parts.indexWhere((p) => p.id == part.id);
                    if (idx >= 0 && idx + 1 < _lesson!.parts.length) {
                      _activePartId = _lesson!.parts[idx + 1].id;
                    }
                  });
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusBadge(int index, bool completed, bool unlocked) {
    Color bg;
    IconData? icon;
    String text = '${index + 1}';
    if (completed) {
      bg = AppColors.success;
      icon = Icons.check_rounded;
    } else if (!unlocked) {
      bg = AppColors.textHint;
      icon = Icons.lock_rounded;
    } else {
      bg = AppColors.primary;
    }
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: icon != null
          ? Icon(icon, color: Colors.white, size: 18)
          : Text(text,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
    );
  }

  Widget _miniBadge(IconData icon, String text, {Color? color}) {
    final c = color ?? AppColors.primary;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: c),
      const SizedBox(width: 3),
      Text(text,
          style: AppTextStyles.caption.copyWith(
              fontSize: 11, color: c, fontWeight: FontWeight.w500)),
    ]);
  }

  Future<void> _addPart() async {
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => _PartEditorDialog(
        lessonId: widget.lesson.id,
      ),
    );
    if (added == true) await _bootstrap();
  }

  Future<void> _editPart(LessonPart part) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _PartEditorDialog(
        lessonId: widget.lesson.id,
        existing: part,
      ),
    );
    if (ok == true) await _bootstrap();
  }

  Future<void> _deletePart(LessonPart part) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xoá phần?'),
        content: Text(
            'Bạn có chắc chắn muốn xoá "${part.title.isEmpty ? "phần này" : part.title}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Huỷ')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService().deleteLessonPart(widget.lesson.id, part.id);
      await _bootstrap();
      if (!mounted) return;
      context.read<TrainingProvider>().loadTrainingData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Xoá thất bại: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

// ===========================================================================
// One part: video player (HtmlElementView, anti-piracy) + quiz CTA.
// ===========================================================================
class _PartContent extends StatefulWidget {
  final Lesson lesson;
  final LessonPart part;
  final bool alreadyCompleted;
  final VoidCallback onQuizSubmitted;

  const _PartContent({
    super.key,
    required this.lesson,
    required this.part,
    required this.alreadyCompleted,
    required this.onQuizSubmitted,
  });

  @override
  State<_PartContent> createState() => _PartContentState();
}

class _PartContentState extends State<_PartContent> {
  bool _videoFinished = false;

  Future<void> _openQuiz() async {
    if (widget.part.questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phần này chưa có bài kiểm tra.')),
      );
      return;
    }
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LessonQuizScreen(
          lessonId: widget.lesson.id,
          partId: widget.part.id,
          lessonTitle: widget.part.title.isEmpty
              ? widget.lesson.title
              : widget.part.title,
          questions:
              widget.part.questions.cast<Map<String, dynamic>>(),
        ),
      ),
    );
    if (ok == true) {
      widget.onQuizSubmitted();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.part.description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(widget.part.description,
                style: AppTextStyles.bodyText),
          ),
        if (widget.part.hasVideo)
          LessonVideoPlayer(
            lessonId: widget.lesson.id,
            partId: widget.part.id,
            onFinished: () => setState(() => _videoFinished = true),
          ),
        if (widget.part.hasVideo) const SizedBox(height: 10),
        _buildQuizCta(),
      ],
    );
  }

  Widget _buildQuizCta() {
    final qs = widget.part.questions;
    if (qs.isEmpty) {
      return const SizedBox.shrink();
    }
    final canQuiz = !widget.part.hasVideo || _videoFinished ||
        widget.alreadyCompleted;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Row(children: [
        const Icon(Icons.quiz_rounded, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            canQuiz
                ? '${qs.length} câu hỏi — sẵn sàng làm bài.'
                : 'Xem hết video để mở khoá ${qs.length} câu hỏi.',
            style: AppTextStyles.caption,
          ),
        ),
        ElevatedButton(
          onPressed: canQuiz ? _openQuiz : null,
          child: Text(widget.alreadyCompleted ? 'Làm lại' : 'Vào kiểm tra'),
        ),
      ]),
    );
  }
}

// ===========================================================================
// Part editor dialog (admin): create or edit a part with video + questions.
// ===========================================================================
class _PartEditorDialog extends StatefulWidget {
  final String lessonId;
  final LessonPart? existing;
  const _PartEditorDialog({required this.lessonId, this.existing});

  @override
  State<_PartEditorDialog> createState() => _PartEditorDialogState();
}

class _PartEditorDialogState extends State<_PartEditorDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  String? _videoPath;
  double? _uploadProgress;
  bool _saving = false;
  String? _err;
  late List<_QEdit> _questions;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _titleCtrl = TextEditingController(text: ex?.title ?? '');
    _descCtrl = TextEditingController(text: ex?.description ?? '');
    _videoPath = ex?.videoPath;
    _questions = (ex?.questions ?? const [])
        .map<_QEdit>((q) => _QEdit.fromMap(Map<String, dynamic>.from(q)))
        .toList();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    for (final q in _questions) {
      q.dispose();
    }
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final result = await FilePicker.pickFiles(
      type: FileType.video,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;
    setState(() {
      _uploadProgress = 0;
      _err = null;
    });
    try {
      final path = await ApiService().uploadLessonVideo(
        bytes: bytes,
        filename: file.name,
        onProgress: (sent, total) {
          if (total > 0 && mounted) {
            setState(() => _uploadProgress = sent / total);
          }
        },
      );
      if (!mounted) return;
      setState(() {
        _videoPath = path;
        _uploadProgress = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploadProgress = null;
        _err = 'Tải video thất bại: $e';
      });
    }
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _err = 'Vui lòng nhập tên phần.');
      return;
    }
    setState(() {
      _saving = true;
      _err = null;
    });
    try {
      final api = ApiService();
      final payload = {
        'title': title,
        'description': _descCtrl.text.trim(),
        'videoPath': _videoPath ?? '',
        'questions': _questions.map((q) => q.toMap()).toList(),
      };
      if (widget.existing == null) {
        await api.createLessonPart(widget.lessonId, payload);
      } else {
        await api.updateLessonPart(
            widget.lessonId, widget.existing!.id, payload);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _err = 'Lưu thất bại: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.existing == null ? 'Thêm phần mới' : 'Sửa phần',
                style: AppTextStyles.sectionHeader,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Tên phần *',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _descCtrl,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Mô tả',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _videoSection(),
                      const SizedBox(height: 14),
                      _questionsSection(),
                      if (_err != null) ...[
                        const SizedBox(height: 8),
                        Text(_err!,
                            style: const TextStyle(color: Colors.red)),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.pop(context, false),
                      child: const Text('Huỷ')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Lưu'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _videoSection() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Video', style: AppTextStyles.bodyTextMedium),
          const SizedBox(height: 6),
          if (_videoPath != null && _videoPath!.isNotEmpty)
            Row(children: [
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 18),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(_videoPath!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption)),
              IconButton(
                tooltip: 'Xoá video',
                onPressed: () => setState(() => _videoPath = null),
                icon: const Icon(Icons.close_rounded),
              ),
            ]),
          if (_uploadProgress != null) ...[
            const SizedBox(height: 6),
            LinearProgressIndicator(value: _uploadProgress),
            const SizedBox(height: 4),
            Text('Đang tải lên ${(_uploadProgress! * 100).toStringAsFixed(0)}%',
                style: AppTextStyles.caption),
          ],
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: _uploadProgress != null ? null : _pickVideo,
            icon: const Icon(Icons.upload_file_rounded, size: 18),
            label: Text(_videoPath == null || _videoPath!.isEmpty
                ? 'Chọn video'
                : 'Đổi video'),
          ),
        ],
      ),
    );
  }

  Widget _questionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('Câu hỏi (${_questions.length})',
              style: AppTextStyles.bodyTextMedium),
          const Spacer(),
          TextButton.icon(
            onPressed: () => setState(() => _questions.add(_QEdit.empty())),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Thêm'),
          ),
        ]),
        for (int i = 0; i < _questions.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildQuestionEditor(i, _questions[i]),
          ),
      ],
    );
  }

  Widget _buildQuestionEditor(int i, _QEdit q) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Câu ${i + 1}',
                style: AppTextStyles.bodyTextMedium
                    .copyWith(color: AppColors.primary)),
            const Spacer(),
            IconButton(
              onPressed: () => setState(() => _questions.removeAt(i).dispose()),
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Colors.red),
            ),
          ]),
          TextField(
            controller: q.questionCtrl,
            decoration: const InputDecoration(
              labelText: 'Nội dung câu hỏi',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            minLines: 1,
            maxLines: 3,
          ),
          const SizedBox(height: 8),
          for (int j = 0; j < q.optionCtrls.length; j++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Radio<int>(
                  value: j,
                  groupValue: q.correctIndex,
                  onChanged: (v) =>
                      setState(() => q.correctIndex = v ?? j),
                ),
                Expanded(
                  child: TextField(
                    controller: q.optionCtrls[j],
                    decoration: InputDecoration(
                      labelText: 'Đáp án ${String.fromCharCode(65 + j)}',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                if (q.optionCtrls.length > 2)
                  IconButton(
                    onPressed: () => setState(() {
                      q.optionCtrls.removeAt(j).dispose();
                      if (q.correctIndex >= q.optionCtrls.length) {
                        q.correctIndex = 0;
                      }
                    }),
                    icon: const Icon(Icons.remove_circle_outline_rounded,
                        size: 18),
                  ),
              ]),
            ),
          if (q.optionCtrls.length < 6)
            TextButton.icon(
              onPressed: () => setState(
                  () => q.optionCtrls.add(TextEditingController())),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Thêm đáp án'),
            ),
        ],
      ),
    );
  }
}

class _QEdit {
  final TextEditingController questionCtrl;
  final List<TextEditingController> optionCtrls;
  int correctIndex;
  String? id;

  _QEdit({
    required this.questionCtrl,
    required this.optionCtrls,
    required this.correctIndex,
    this.id,
  });

  factory _QEdit.empty() => _QEdit(
        questionCtrl: TextEditingController(),
        optionCtrls: [TextEditingController(), TextEditingController()],
        correctIndex: 0,
      );

  factory _QEdit.fromMap(Map<String, dynamic> m) {
    final opts = (m['options'] as List?) ?? const [];
    return _QEdit(
      id: m['id']?.toString(),
      questionCtrl: TextEditingController(text: (m['question'] ?? '').toString()),
      optionCtrls: opts.isEmpty
          ? [TextEditingController(), TextEditingController()]
          : opts
              .map((e) => TextEditingController(text: e.toString()))
              .toList(),
      correctIndex: (m['correctIndex'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    const letters = ['A', 'B', 'C', 'D', 'E', 'F'];
    final idx = correctIndex.clamp(0, optionCtrls.length - 1);
    return {
      if (id != null) 'id': id,
      'type': 'TN',
      'question': questionCtrl.text.trim(),
      'options': optionCtrls.map((c) => c.text.trim()).toList(),
      'correctIndex': idx,
      'correctAnswer': letters[idx],
      'points': 1,
    };
  }

  void dispose() {
    questionCtrl.dispose();
    for (final c in optionCtrls) {
      c.dispose();
    }
  }
}
