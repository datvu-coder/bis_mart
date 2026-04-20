import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';

class RankListTile extends StatelessWidget {
  final int rank;
  final String name;
  final int? score;
  final VoidCallback? onTap;

  const RankListTile({
    super.key,
    required this.rank,
    required this.name,
    this.score,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isTop = rank <= 3;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isTop ? AppColors.primaryLight : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: isTop ? AppColors.primary : AppColors.textGrey,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isTop ? FontWeight.w600 : FontWeight.w400,
                      color: isTop ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  if (score != null)
                    Text(
                      '$score điểm',
                      style: AppTextStyles.caption,
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textHint, size: 18),
          ],
        ),
      ),
    );
  }
}
