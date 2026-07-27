import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/lesson.dart';

/// Compact, mobile-first lesson card with progress bar.
/// - Whole card is tappable (Tham gia học).
/// - "Lịch sử" button opens history screen.
/// - Optional admin actions (edit/delete) via [onEdit] / [onDelete].
class LessonCard extends StatelessWidget {
  final Lesson lesson;
  final VoidCallback? onJoin;
  final VoidCallback? onHistory;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const LessonCard({
    super.key,
    required this.lesson,
    this.onJoin,
    this.onHistory,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final progress = lesson.progress.clamp(0.0, 1.0);
    final percentText = '${(progress * 100).round()}%';
    final isDone = lesson.partCount > 0 &&
        lesson.completedPartCount >= lesson.partCount;
    return Material(
      color: AppColors.cardBg,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: onJoin,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
                color: AppColors.border.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildThumb(),
              const SizedBox(width: 12),
              Expanded(child: _buildBody(percentText, isDone, progress)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumb() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 84,
        height: 84,
        decoration: const BoxDecoration(
          color: AppColors.surfaceVariant,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (lesson.thumbnailUrl.isNotEmpty)
              Image.network(
                lesson.thumbnailUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.school_rounded,
                      size: 32, color: AppColors.primary),
                ),
              )
            else
              const Center(
                child: Icon(Icons.play_circle_fill_rounded,
                    size: 36, color: AppColors.primary),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(String percentText, bool isDone, double progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                lesson.title,
                style: AppTextStyles.bodyText.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 14.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onEdit != null)
              IconButton(
                icon: const Icon(Icons.edit_rounded, size: 18),
                tooltip: 'Sửa',
                visualDensity: VisualDensity.compact,
                onPressed: onEdit,
              ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_rounded, size: 18, color: AppColors.error),
                tooltip: 'Xoá',
                visualDensity: VisualDensity.compact,
                onPressed: onDelete,
              ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _chip(Icons.list_alt_rounded, '${lesson.partCount} phần'),
            _chip(Icons.group_outlined, lesson.targetRole),
            if (isDone)
              _chip(Icons.verified_rounded, 'Hoàn thành',
                  color: AppColors.success),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: AppColors.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation(
                    isDone ? AppColors.success : AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${lesson.completedPartCount}/${lesson.partCount} • $percentText',
              style: AppTextStyles.caption.copyWith(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isDone ? AppColors.success : AppColors.primary,
              ),
            ),
          ],
        ),
        if (onJoin != null || onHistory != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                if (onJoin != null)
                  Expanded(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: const Size(0, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        foregroundColor: AppColors.primary,
                      ),
                      onPressed: onJoin,
                      icon: const Icon(Icons.play_circle_outline_rounded, size: 16),
                      label: const Text('Tham gia',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ),
                  ),
                if (onHistory != null)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: onHistory,
                    icon: const Icon(Icons.history_rounded, size: 16),
                    label: const Text('Lịch sử',
                        style: TextStyle(fontSize: 12.5)),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _chip(IconData icon, String text, {Color? color}) {
    final c = color ?? AppColors.textGrey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: c),
          const SizedBox(width: 3),
          Text(text,
              style: AppTextStyles.caption.copyWith(
                  fontSize: 11, color: c, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
