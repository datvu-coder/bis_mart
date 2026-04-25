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
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;
  final VoidCallback? onTapMedia; // forward when user taps media area

  const SocialPostCard({
    super.key,
    required this.post,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onEdit,
    this.onDelete,
    this.onTap,
    this.onTapMedia,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
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
                          Icon(
                            post.visibility == 'store'
                                ? Icons.storefront_rounded
                                : Icons.public_rounded,
                            size: 12,
                            color: AppColors.textHint,
                          ),
                          if (post.visibility == 'store') ...[
                            const SizedBox(width: 4),
                            Text(
                              'Cửa hàng',
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.textHint),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz_rounded,
                      color: AppColors.textGrey, size: 22),
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit?.call();
                    }
                    if (value == 'delete') {
                      onDelete?.call();
                    }
                  },
                  itemBuilder: (context) {
                    final items = <PopupMenuEntry<String>>[];
                    if (onEdit != null) {
                      items.add(
                        const PopupMenuItem<String>(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('Sửa bài viết'),
                            ],
                          ),
                        ),
                      );
                    }
                    if (onDelete != null) {
                      items.add(
                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_rounded, size: 18, color: AppColors.error),
                              SizedBox(width: 8),
                              Text('Xóa bài viết', style: TextStyle(color: AppColors.error)),
                            ],
                          ),
                        ),
                      );
                    }
                    if (items.isEmpty) {
                      return const [
                        PopupMenuItem<String>(
                          enabled: false,
                          value: 'none',
                          child: Text('Không có thao tác'),
                        ),
                      ];
                    }
                    return items;
                  },
                ),
              ],
            ),
          ),

          // ── Content ──────────────────────────────────────────────────────
          if (post.content != null && post.content!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Text(post.content!, style: AppTextStyles.bodyText),
            ),

          // ── Media (images + video) ──────────────────────────────
          if (post.imageUrls.isNotEmpty || (post.videoUrl ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _PostMedia(
                post: post,
                onTap: onTapMedia ?? onTap,
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
        ),
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

/// Renders a post's images and/or video preview with a sensible cap on height
/// so big photos don't blow up the feed. Multiple images become a grid; a
/// video becomes a 16:9 thumbnail with a play overlay (real playback is in
/// the post detail screen).
class _PostMedia extends StatelessWidget {
  final CommunityPost post;
  final VoidCallback? onTap;
  const _PostMedia({required this.post, this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasVideo = (post.videoUrl ?? '').isNotEmpty;
    final imgs = post.imageUrls;
    final children = <Widget>[];
    if (hasVideo) {
      children.add(_videoThumb(context));
    }
    if (imgs.isNotEmpty) {
      if (hasVideo) children.add(const SizedBox(height: 4));
      children.add(_imageBlock(context, imgs));
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }

  Widget _videoThumb(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1F2937), Color(0xFF374151)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    size: 36, color: Colors.white),
              ),
            ),
            const Positioned(
              left: 10,
              top: 10,
              child: Row(children: [
                Icon(Icons.videocam_rounded, color: Colors.white, size: 16),
                SizedBox(width: 4),
                Text('Video',
                    style: TextStyle(color: Colors.white, fontSize: 12)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageBlock(BuildContext context, List<String> imgs) {
    final maxH = MediaQuery.of(context).size.height * 0.5;
    if (imgs.length == 1) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: _img(imgs.first, fit: BoxFit.cover),
      );
    }
    if (imgs.length == 2) {
      return SizedBox(
        height: 220,
        child: Row(children: [
          Expanded(child: _img(imgs[0])),
          const SizedBox(width: 2),
          Expanded(child: _img(imgs[1])),
        ]),
      );
    }
    if (imgs.length == 3) {
      return SizedBox(
        height: 260,
        child: Row(children: [
          Expanded(flex: 2, child: _img(imgs[0])),
          const SizedBox(width: 2),
          Expanded(
            child: Column(children: [
              Expanded(child: _img(imgs[1])),
              const SizedBox(height: 2),
              Expanded(child: _img(imgs[2])),
            ]),
          ),
        ]),
      );
    }
    // 4+ : 2x2 grid; if more than 4, overlay "+N" on last cell.
    final extra = imgs.length - 4;
    return SizedBox(
      height: 280,
      child: Column(children: [
        Expanded(
          child: Row(children: [
            Expanded(child: _img(imgs[0])),
            const SizedBox(width: 2),
            Expanded(child: _img(imgs[1])),
          ]),
        ),
        const SizedBox(height: 2),
        Expanded(
          child: Row(children: [
            Expanded(child: _img(imgs[2])),
            const SizedBox(width: 2),
            Expanded(
              child: Stack(fit: StackFit.expand, children: [
                _img(imgs[3]),
                if (extra > 0)
                  Container(
                    color: Colors.black.withValues(alpha: 0.45),
                    alignment: Alignment.center,
                    child: Text('+$extra',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold)),
                  ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _img(String url, {BoxFit fit = BoxFit.cover}) {
    return Image.network(
      url,
      fit: fit,
      width: double.infinity,
      errorBuilder: (_, __, ___) => Container(
        color: AppColors.surfaceVariant,
        child: const Center(
          child:
              Icon(Icons.image_rounded, color: AppColors.textHint, size: 32),
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
