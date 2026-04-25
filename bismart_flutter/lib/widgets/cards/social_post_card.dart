import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/community_post.dart';

/// A polished social post card. The card has a soft shadow + rounded corners
/// and renders any combination of text / images (1, 2, 3 or 4+ in a grid) /
/// video (thumbnail with play overlay; real playback in detail screen).
class SocialPostCard extends StatelessWidget {
  final CommunityPost post;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;
  final VoidCallback? onTapMedia;

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
    final card = Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Material(
          color: AppColors.white,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                if (post.content != null && post.content!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Text(
                      post.content!,
                      style: AppTextStyles.bodyText.copyWith(
                        height: 1.45,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                if (post.imageUrls.isNotEmpty ||
                    (post.videoUrl ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _PostMedia(
                      post: post,
                      onTap: onTapMedia ?? onTap,
                    ),
                  ),
                if (post.likeCount > 0 || post.commentCount > 0)
                  _buildStatsRow(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Divider(
                      height: 1,
                      color: AppColors.border.withValues(alpha: 0.7)),
                ),
                _buildActions(),
              ],
            ),
          ),
        ),
      ),
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: card,
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 6, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Avatar(name: post.authorName, size: 42),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.authorName,
                  style: AppTextStyles.bodyText.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      DateFormatter.relativeDate(post.createdAt),
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textGrey, fontSize: 12),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 3,
                      height: 3,
                      decoration: const BoxDecoration(
                        color: AppColors.textHint,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      post.visibility == 'store'
                          ? Icons.storefront_rounded
                          : Icons.public_rounded,
                      size: 13,
                      color: AppColors.textHint,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      post.visibility == 'store' ? 'Cửa hàng' : 'Công khai',
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.textHint, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (onEdit != null || onDelete != null)
            PopupMenuButton<String>(
              tooltip: 'Tùy chọn',
              icon: const Icon(Icons.more_horiz_rounded,
                  color: AppColors.textGrey, size: 22),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              onSelected: (value) {
                if (value == 'edit') onEdit?.call();
                if (value == 'delete') onDelete?.call();
              },
              itemBuilder: (context) {
                final items = <PopupMenuEntry<String>>[];
                if (onEdit != null) {
                  items.add(const PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_rounded, size: 18),
                      SizedBox(width: 10),
                      Text('Sửa bài viết'),
                    ]),
                  ));
                }
                if (onDelete != null) {
                  items.add(const PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_rounded,
                          size: 18, color: AppColors.error),
                      SizedBox(width: 10),
                      Text('Xóa bài viết',
                          style: TextStyle(color: AppColors.error)),
                    ]),
                  ));
                }
                return items;
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
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
            const SizedBox(width: 6),
            Text('${post.likeCount}',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary, fontSize: 13)),
          ],
          const Spacer(),
          if (post.commentCount > 0)
            Text(
              '${post.commentCount} bình luận',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary, fontSize: 13),
            ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
            fontSize: size * 0.38,
          ),
        ),
      ),
    );
  }
}

class _PostMedia extends StatelessWidget {
  final CommunityPost post;
  final VoidCallback? onTap;
  const _PostMedia({required this.post, this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasVideo = (post.videoUrl ?? '').isNotEmpty;
    final imgs = post.imageUrls;
    final children = <Widget>[];
    if (hasVideo) children.add(_videoThumb(context));
    if (imgs.isNotEmpty) {
      if (hasVideo) children.add(const SizedBox(height: 6));
      children.add(_imageBlock(context, imgs));
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }

  Widget _videoThumb(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF111827),
                  Color(0xFF1F2937),
                  Color(0xFF374151)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  size: 40, color: AppColors.primary),
            ),
          ),
          Positioned(
            left: 12,
            top: 12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.videocam_rounded, color: Colors.white, size: 14),
                SizedBox(width: 4),
                Text('Video',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('Nhấn để xem',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageBlock(BuildContext context, List<String> imgs) {
    final maxH =
        (MediaQuery.of(context).size.height * 0.5).clamp(260.0, 520.0);
    if (imgs.length == 1) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: _img(imgs.first, fit: BoxFit.cover),
      );
    }
    if (imgs.length == 2) {
      return SizedBox(
        height: 260,
        child: Row(children: [
          Expanded(child: _img(imgs[0])),
          const SizedBox(width: 3),
          Expanded(child: _img(imgs[1])),
        ]),
      );
    }
    if (imgs.length == 3) {
      return SizedBox(
        height: 280,
        child: Row(children: [
          Expanded(flex: 2, child: _img(imgs[0])),
          const SizedBox(width: 3),
          Expanded(
            child: Column(children: [
              Expanded(child: _img(imgs[1])),
              const SizedBox(height: 3),
              Expanded(child: _img(imgs[2])),
            ]),
          ),
        ]),
      );
    }
    final extra = imgs.length - 4;
    return SizedBox(
      height: 320,
      child: Column(children: [
        Expanded(
          child: Row(children: [
            Expanded(child: _img(imgs[0])),
            const SizedBox(width: 3),
            Expanded(child: _img(imgs[1])),
          ]),
        ),
        const SizedBox(height: 3),
        Expanded(
          child: Row(children: [
            Expanded(child: _img(imgs[2])),
            const SizedBox(width: 3),
            Expanded(
              child: Stack(fit: StackFit.expand, children: [
                _img(imgs[3]),
                if (extra > 0)
                  Container(
                    color: Colors.black.withValues(alpha: 0.5),
                    alignment: Alignment.center,
                    child: Text('+$extra',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
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
      loadingBuilder: (ctx, child, prog) {
        if (prog == null) return child;
        return Container(
          color: AppColors.surfaceVariant,
          child: const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
      errorBuilder: (_, __, ___) => Container(
        color: AppColors.surfaceVariant,
        child: const Center(
          child: Icon(Icons.broken_image_rounded,
              color: AppColors.textHint, size: 32),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5)),
          ],
        ),
      ),
    );
  }
}
