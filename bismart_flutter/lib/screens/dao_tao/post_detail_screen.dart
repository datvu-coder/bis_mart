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

/// Detailed view of a single community post.
///
/// Web-focused but mobile-friendly: max-width 720 on desktop, full width on
/// mobile. Renders header, full content, video player (if any), image gallery
/// (PageView when more than one image), like/comment counts, full comment
/// list with avatars, and an inline comment composer.
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
      FocusScope.of(context).unfocus();
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
      appBar: AppBar(
        title: const Text('Bài đăng'),
        elevation: 0,
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
      ),
      body: post == null
          ? const Center(child: Text('Không tìm thấy bài đăng.'))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(children: [
                  Expanded(child: _buildBody(post, provider)),
                  _buildComposer(user?.fullName ?? 'Bạn', provider),
                ]),
              ),
            ),
    );
  }

  Widget _buildBody(CommunityPost post, TrainingProvider provider) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      children: [
        _postCard(post, provider),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Bình luận (${post.commentCount})',
            style: AppTextStyles.bodyText.copyWith(
                fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
        const SizedBox(height: 10),
        if (post.comments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Column(children: [
                Icon(Icons.mode_comment_outlined,
                    size: 36, color: AppColors.textHint),
                const SizedBox(height: 8),
                Text('Chưa có bình luận nào.',
                    style: AppTextStyles.caption),
                const SizedBox(height: 2),
                Text('Hãy là người đầu tiên bình luận.',
                    style: AppTextStyles.caption),
              ]),
            ),
          )
        else
          for (final c in post.comments) _commentRow(c),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _postCard(CommunityPost post, TrainingProvider provider) {
    return Container(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 8, 4),
              child: Row(children: [
                _avatar(post.authorName, 44),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(post.authorName,
                            style: AppTextStyles.bodyText.copyWith(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 2),
                        Row(children: [
                          Text(
                              DateFormatter.relativeDate(post.createdAt),
                              style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textGrey)),
                          const SizedBox(width: 6),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: const BoxDecoration(
                                color: AppColors.textHint,
                                shape: BoxShape.circle),
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
                            post.visibility == 'store'
                                ? 'Cửa hàng'
                                : 'Công khai',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.textHint),
                          ),
                        ]),
                      ]),
                ),
              ]),
            ),
            if ((post.content ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: SelectableText(
                  post.content!,
                  style: AppTextStyles.bodyText.copyWith(height: 1.5),
                ),
              ),
            if ((post.videoUrl ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
                child: _PostVideoPlayer(postId: post.id),
              ),
            if (post.imageUrls.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _ImageGallery(urls: post.imageUrls),
              ),
            if (post.likeCount > 0 || post.commentCount > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(children: [
                  if (post.likeCount > 0) ...[
                    Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                          color: AppColors.error, shape: BoxShape.circle),
                      child: const Icon(Icons.favorite_rounded,
                          size: 11, color: Colors.white),
                    ),
                    const SizedBox(width: 6),
                    Text('${post.likeCount}',
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ],
                  const Spacer(),
                  if (post.commentCount > 0)
                    Text('${post.commentCount} bình luận',
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary, fontSize: 13)),
                ]),
              ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Divider(
                  height: 1,
                  color: AppColors.border.withValues(alpha: 0.7)),
            ),
            Row(children: [
              Expanded(
                  child: _action(
                      post.isLiked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      'Thích',
                      post.isLiked ? AppColors.error : AppColors.textGrey,
                      () => provider.toggleLike(post.id))),
              Expanded(
                  child: _action(
                      Icons.chat_bubble_outline_rounded,
                      'Bình luận',
                      AppColors.textGrey,
                      () => FocusScope.of(context).requestFocus(FocusNode()))),
              Expanded(
                  child: _action(Icons.share_outlined, 'Chia sẻ',
                      AppColors.textGrey, null)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _action(
      IconData icon, String label, Color color, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5)),
        ]),
      ),
    );
  }

  Widget _commentRow(PostComment c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _avatar(c.authorName, 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.authorName,
                          style: AppTextStyles.bodyText.copyWith(
                              fontWeight: FontWeight.w700, fontSize: 13.5)),
                      const SizedBox(height: 2),
                      SelectableText(c.text,
                          style:
                              AppTextStyles.bodyText.copyWith(height: 1.4)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 0, 0),
                  child: Text(DateFormatter.relativeDate(c.createdAt),
                      style: AppTextStyles.caption.copyWith(fontSize: 11)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(String name, double size) {
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

  Widget _buildComposer(String name, TrainingProvider provider) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          12, 8, 12, 8 + MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(
            top: BorderSide(color: AppColors.border.withValues(alpha: 0.6))),
      ),
      child: SafeArea(
        top: false,
        child: Row(children: [
          _avatar(name, 36),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _commentCtrl,
              decoration: InputDecoration(
                hintText: 'Viết bình luận…',
                filled: true,
                fillColor: AppColors.surfaceVariant,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
              ),
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendComment(provider, name),
            ),
          ),
          const SizedBox(width: 6),
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Image gallery (single → tall image; many → swipeable PageView with dots)
// ─────────────────────────────────────────────────────────────────────────
class _ImageGallery extends StatefulWidget {
  final List<String> urls;
  const _ImageGallery({required this.urls});

  @override
  State<_ImageGallery> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<_ImageGallery> {
  int _index = 0;
  late final PageController _ctrl = PageController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _open(int initial) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => _ImageLightbox(urls: widget.urls, initial: initial),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxH =
        (MediaQuery.of(context).size.height * 0.6).clamp(300.0, 600.0);
    if (widget.urls.length == 1) {
      return GestureDetector(
        onTap: () => _open(0),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: Image.network(
            widget.urls.first,
            fit: BoxFit.contain,
            width: double.infinity,
          ),
        ),
      );
    }
    return Column(children: [
      SizedBox(
        height: maxH * 0.85,
        child: PageView.builder(
          controller: _ctrl,
          onPageChanged: (i) => setState(() => _index = i),
          itemCount: widget.urls.length,
          itemBuilder: (_, i) => GestureDetector(
            onTap: () => _open(i),
            child: Container(
              color: Colors.black,
              child: Image.network(
                widget.urls[i],
                fit: BoxFit.contain,
                width: double.infinity,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image_rounded,
                      color: Colors.white54, size: 36),
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(widget.urls.length, (i) {
          final active = i == _index;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: active ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: active ? AppColors.primary : AppColors.border,
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      ),
      const SizedBox(height: 6),
      Text('${_index + 1} / ${widget.urls.length}',
          style: AppTextStyles.caption),
      const SizedBox(height: 4),
    ]);
  }
}

class _ImageLightbox extends StatefulWidget {
  final List<String> urls;
  final int initial;
  const _ImageLightbox({required this.urls, required this.initial});

  @override
  State<_ImageLightbox> createState() => _ImageLightboxState();
}

class _ImageLightboxState extends State<_ImageLightbox> {
  late final PageController _ctrl =
      PageController(initialPage: widget.initial);
  late int _index = widget.initial;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(children: [
        PageView.builder(
          controller: _ctrl,
          itemCount: widget.urls.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (_, i) => InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Center(
              child: Image.network(widget.urls[i], fit: BoxFit.contain),
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: SafeArea(
            child: IconButton(
              icon: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 28),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
        if (widget.urls.length > 1)
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_index + 1} / ${widget.urls.length}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Native HTML5 video player (range-streamed, JWT-auth via ?t=).
// ─────────────────────────────────────────────────────────────────────────
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
        ..setAttribute('preload', 'metadata')
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
    final maxH =
        (MediaQuery.of(context).size.height * 0.55).clamp(280.0, 540.0);
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: AspectRatio(
          aspectRatio: 16 / 9,
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
    );
  }
}
