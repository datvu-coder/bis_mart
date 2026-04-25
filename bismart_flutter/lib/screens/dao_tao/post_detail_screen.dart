import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/community_post.dart';
import '../../providers/auth_provider.dart';
import '../../providers/training_provider.dart';
import '../../services/api_service.dart';

/// Detailed view of a single community post: full media, full text, comments.
class PostDetailScreen extends StatefulWidget {
  final String postId;
  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final TextEditingController _commentCtrl = TextEditingController();
  bool _sending = false;

  CommunityPost? _findPost(TrainingProvider p) {
    for (final post in p.posts) {
      if (post.id == widget.postId) return post;
    }
    return null;
  }

  Future<void> _sendComment(TrainingProvider provider, String name) async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      provider.addCommentText(widget.postId, text, authorName: name);
      _commentCtrl.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TrainingProvider>();
    final user = context.read<AuthProvider>().currentUser;
    final post = _findPost(provider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Bài đăng')),
      body: post == null
          ? const Center(child: Text('Không tìm thấy bài đăng.'))
          : Column(children: [
              Expanded(child: _buildContent(post, provider)),
              _buildComposer(user?.fullName ?? 'Bạn', provider),
            ]),
    );
  }

  Widget _buildContent(CommunityPost post, TrainingProvider provider) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  child: Text(
                    post.authorName.isNotEmpty
                        ? post.authorName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(post.authorName,
                            style: AppTextStyles.bodyText
                                .copyWith(fontWeight: FontWeight.w700)),
                        Text(
                            DateFormatter.relativeDate(post.createdAt),
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.textGrey)),
                      ]),
                ),
                Row(children: [
                  Icon(
                    post.isLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color:
                        post.isLiked ? AppColors.error : AppColors.textGrey,
                  ),
                  const SizedBox(width: 4),
                  Text('${post.likeCount}'),
                ]),
              ]),
              if ((post.content ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(post.content!,
                    style: AppTextStyles.bodyText.copyWith(height: 1.4)),
              ],
              if ((post.videoUrl ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                _PostVideoPlayer(postId: post.id),
              ],
              for (final url in post.imageUrls) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      height: 160,
                      color: AppColors.surfaceVariant,
                      child: const Center(
                          child: Icon(Icons.image_rounded,
                              color: AppColors.textHint, size: 32)),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(children: [
                _action(Icons.favorite_border_rounded, 'Thích',
                    () => provider.toggleLike(post.id)),
                _action(Icons.share_outlined, 'Chia sẻ', null),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text('Bình luận (${post.commentCount})',
            style: AppTextStyles.sectionHeader),
        const SizedBox(height: 8),
        if (post.comments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('Chưa có bình luận nào.',
                  style: AppTextStyles.caption),
            ),
          ),
        for (final c in post.comments) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(c.authorName,
                      style: AppTextStyles.bodyText
                          .copyWith(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(width: 6),
                  Text(DateFormatter.relativeDate(c.createdAt),
                      style: AppTextStyles.caption.copyWith(fontSize: 11)),
                ]),
                const SizedBox(height: 4),
                Text(c.text, style: AppTextStyles.bodyText),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _action(IconData icon, String label, VoidCallback? onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }

  Widget _buildComposer(String name, TrainingProvider provider) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          12, 8, 12, 8 + MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border(
            top: BorderSide(color: AppColors.border.withValues(alpha: 0.5))),
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _commentCtrl,
            decoration: const InputDecoration(
              hintText: 'Viết bình luận…',
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            minLines: 1,
            maxLines: 3,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _sending ? null : () => _sendComment(provider, name),
          icon: _sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.send_rounded, color: AppColors.primary),
        ),
      ]),
    );
  }
}

class _PostVideoPlayer extends StatefulWidget {
  final String postId;
  const _PostVideoPlayer({required this.postId});

  @override
  State<_PostVideoPlayer> createState() => _PostVideoPlayerState();
}

class _PostVideoPlayerState extends State<_PostVideoPlayer> {
  late final String _viewType;
  html.VideoElement? _video;
  bool _loading = true;
  String? _error;
  bool _registered = false;

  @override
  void initState() {
    super.initState();
    _viewType =
        'post-video-${widget.postId}-${DateTime.now().microsecondsSinceEpoch}';
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final url = await ApiService().buildPostVideoUrl(widget.postId);
      final video = html.VideoElement()
        ..src = url
        ..controls = true
        ..autoplay = false
        ..setAttribute('controlslist', 'nodownload')
        ..setAttribute('playsinline', 'true')
        ..setAttribute('preload', 'auto')
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'contain'
        ..style.backgroundColor = '#000';
      video.onContextMenu.listen((e) => e.preventDefault());
      video.onError.listen((_) {
        if (mounted) {
          setState(() {
            _error = 'Không tải được video.';
            _loading = false;
          });
        }
      });
      video.onLoadedMetadata.listen((_) {
        if (mounted) setState(() => _loading = false);
      });
      // ignore: undefined_prefixed_name
      ui_web.platformViewRegistry
          .registerViewFactory(_viewType, (int _) => video);
      _video = video;
      _registered = true;
      if (mounted) setState(() {});
      Future.delayed(const Duration(seconds: 8), () {
        if (mounted && _loading && _error == null) {
          setState(() => _loading = false);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Không tải được video: $e';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    try {
      _video?.pause();
      _video?.removeAttribute('src');
      _video?.load();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.55;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(fit: StackFit.expand, children: [
              Container(color: Colors.black),
              if (_video != null && _registered)
                HtmlElementView(viewType: _viewType),
              if (_loading)
                const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              if (_error != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(_error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white)),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
