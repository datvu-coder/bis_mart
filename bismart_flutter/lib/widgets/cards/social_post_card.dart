import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/community_post.dart';

/// Facebook-style social post card giữ tông màu chủ đạo của app.
class SocialPostCard extends StatelessWidget {
  final CommunityPost post;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;

  const SocialPostCard({
    super.key,
    required this.post,
    this.onLike,
    this.onComment,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      decoration: const BoxDecoration(
        color: AppColors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Author header ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Avatar(name: post.authorName, size: 42),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorName,
                        style: AppTextStyles.bodyText
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            DateFormatter.relativeDate(post.createdAt),
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.textGrey),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.public_rounded,
                              size: 12, color: AppColors.textHint),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.more_horiz_rounded,
                    color: AppColors.textGrey, size: 22),
              ],
            ),
          ),

          // ── Content ──────────────────────────────────────────────────────
          if (post.content != null && post.content!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Text(post.content!, style: AppTextStyles.bodyText),
            ),

          // ── Image ────────────────────────────────────────────────────────
          if (post.imageUrls.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: ClipRRect(
                child: Image.network(
                  post.imageUrls.first,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 180,
                    color: AppColors.surfaceVariant,
                    child: const Center(
                      child: Icon(Icons.image_rounded,
                          size: 40, color: AppColors.textHint),
                    ),
                  ),
                ),
              ),
            ),

          // ── Stats row ─────────────────────────────────────────────────────
          if (post.likeCount > 0 || post.commentCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Row(
                children: [
                  if (post.likeCount > 0) ...[
                    Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.favorite_rounded,
                          size: 11, color: Colors.white),
                    ),
                    const SizedBox(width: 5),
                    Text('${post.likeCount}',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary)),
                  ],
                  const Spacer(),
                  if (post.commentCount > 0)
                    Text(
                      '${post.commentCount} bình luận',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),

          // ── Divider ───────────────────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Divider(height: 1, color: AppColors.border),
          ),

          // ── Actions ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: _PostAction(
                    icon: post.isLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    label: 'Thích',
                    color: post.isLiked ? AppColors.error : AppColors.textGrey,
                    onTap: onLike,
                  ),
                ),
                Expanded(
                  child: _PostAction(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Bình luận',
                    color: AppColors.textGrey,
                    onTap: onComment,
                  ),
                ),
                Expanded(
                  child: _PostAction(
                    icon: Icons.share_outlined,
                    label: 'Chia sẻ',
                    color: AppColors.textGrey,
                    onTap: onShare,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final double size;

  const _Avatar({required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.gradientStart, AppColors.gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.36,
          ),
        ),
      ),
    );
  }
}

class _PostAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _PostAction({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 390;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            if (!compact) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
