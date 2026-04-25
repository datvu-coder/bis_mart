import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/lesson.dart';
import '../../services/api_service.dart';
import 'lesson_quiz_screen.dart';

/// Anti-piracy video lesson:
/// - Custom controls (play/pause + read-only progress, no scrubbing)
/// - Forward seek blocked; rewind allowed
/// - Right-click + selection blocked on web
/// - Best-effort screenshot mitigation: blur on focus loss; ban PrintScreen
/// - Disables PiP / download on the underlying <video>
class LessonDetailScreen extends StatefulWidget {
  final Lesson lesson;
  const LessonDetailScreen({super.key, required this.lesson});

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _initializing = true;
  String? _error;
  bool _videoFinished = false;
  bool _isPlaying = false;
  Duration _maxWatched = Duration.zero;
  bool _windowBlurred = false;
  StreamSubscription<html.Event>? _blurSub;
  StreamSubscription<html.Event>? _focusSub;
  StreamSubscription<html.Event>? _ctxSub;
  StreamSubscription<html.KeyboardEvent>? _keySub;

  Map<String, dynamic>? _detail;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _attachWebGuards();
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _blurSub?.cancel();
    _focusSub?.cancel();
    _ctxSub?.cancel();
    _keySub?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  void _attachWebGuards() {
    if (!kIsWeb) return;
    _ctxSub = html.document.onContextMenu.listen((e) => e.preventDefault());
    _blurSub = html.window.onBlur.listen((_) {
      if (mounted) setState(() => _windowBlurred = true);
      _controller?.pause();
    });
    _focusSub = html.window.onFocus.listen((_) {
      if (mounted) setState(() => _windowBlurred = false);
    });
    _keySub = html.window.onKeyDown.listen((e) {
      // Block PrintScreen, Ctrl/Cmd+P, Ctrl/Cmd+S, F12
      final k = e.key ?? '';
      final isCmd = e.ctrlKey || e.metaKey;
      if (k == 'PrintScreen' ||
          k == 'F12' ||
          (isCmd && (k.toLowerCase() == 's' || k.toLowerCase() == 'p'))) {
        e.preventDefault();
        if (mounted) setState(() => _windowBlurred = true);
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) setState(() => _windowBlurred = false);
        });
      }
      // Block media keyboard seek
      if (k == 'ArrowRight' || k == 'ArrowLeft') {
        e.preventDefault();
      }
    });
  }

  Future<void> _bootstrap() async {
    try {
      final detail = await ApiService().getLessonDetail(widget.lesson.id);
      if (!mounted) return;
      _detail = detail;
      final url = (detail['videoUrl'] as String?) ?? widget.lesson.videoUrl ?? '';
      if (url.isEmpty) {
        setState(() {
          _initializing = false;
          _error = 'Bài giảng chưa có video.';
        });
        return;
      }
      // Disable native controls / download on the underlying <video> on web
      if (kIsWeb) {
        // ignore: undefined_prefixed_name
        ui_web.platformViewRegistry; // no-op import to keep tree
      }
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );
      await controller.initialize();
      controller.addListener(_onTick);
      await controller.setLooping(false);
      _hardenWebVideoElement();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString();
      String msg;
      if (raw.contains('MEDIA_ERR') ||
          raw.contains('NotSupportedError') ||
          raw.contains('format') ||
          raw.contains('decode')) {
        msg = 'Trình duyệt không phát được video này.\n'
            'Hãy dùng URL .mp4 (H.264) trực tiếp.\n'
            'Link Google Drive / YouTube không phát được.';
      } else if (raw.contains('CORS') || raw.contains('cross-origin')) {
        msg = 'Server video chặn CORS. Hãy bật CORS hoặc dùng host khác.';
      } else if (raw.contains('Mixed Content') || raw.contains('http:')) {
        msg = 'Video dùng HTTP nhưng trang HTTPS — vui lòng dùng URL https://';
      } else {
        msg = 'Không tải được video.\n$raw';
      }
      setState(() {
        _initializing = false;
        _error = msg;
      });
    }
  }

  void _hardenWebVideoElement() {
    if (!kIsWeb) return;
    Future.delayed(const Duration(milliseconds: 400), () {
      final videos = html.document.querySelectorAll('video');
      for (final v in videos) {
        v.setAttribute('controlslist', 'nodownload noplaybackrate noremoteplayback');
        v.setAttribute('disablepictureinpicture', 'true');
        v.setAttribute('oncontextmenu', 'return false;');
        // Remove default controls — we render our own
        (v as html.VideoElement).controls = false;
      }
    });
  }

  void _onTick() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final pos = c.value.position;
    if (pos > _maxWatched + const Duration(milliseconds: 250)) {
      // Forward jump detected (manual seek attempt) — clamp back to maxWatched
      c.seekTo(_maxWatched);
      return;
    }
    if (pos > _maxWatched) {
      _maxWatched = pos;
    }
    final isEnd = c.value.duration > Duration.zero &&
        pos >= c.value.duration - const Duration(milliseconds: 600);
    if (isEnd && !_videoFinished) {
      _videoFinished = true;
      c.pause();
    }
    if (mounted) {
      setState(() => _isPlaying = c.value.isPlaying);
    }
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      if (_videoFinished) {
        _videoFinished = false;
        _maxWatched = Duration.zero;
        c.seekTo(Duration.zero).then((_) => c.play());
      } else {
        c.play();
      }
    }
  }

  void _rewind() {
    final c = _controller;
    if (c == null) return;
    final back = c.value.position - const Duration(seconds: 10);
    c.seekTo(back < Duration.zero ? Duration.zero : back);
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  void _openVideoInNewTab() {
    final url = (_detail?['videoUrl'] as String?) ?? widget.lesson.videoUrl ?? '';
    if (url.isEmpty) return;
    if (kIsWeb) {
      html.window.open(url, '_blank');
    }
  }

  Future<void> _openQuiz() async {
    final detail = _detail;
    if (detail == null) return;
    final questions = (detail['questions'] as List<dynamic>?) ?? [];
    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bài giảng này chưa có bài kiểm tra.')),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LessonQuizScreen(
          lessonId: widget.lesson.id,
          lessonTitle: widget.lesson.title,
          questions: questions.cast<Map<String, dynamic>>(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 1100;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.lesson.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SelectionContainer.disabled(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isDesktop ? 24 : 12),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPlayer(),
                  const SizedBox(height: 16),
                  _buildInfo(),
                  const SizedBox(height: 16),
                  _buildQuizCta(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayer() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: Colors.black),
            if (_initializing)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            else if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: Colors.white70, size: 36),
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _openVideoInNewTab,
                            icon: const Icon(Icons.open_in_new_rounded, size: 16),
                            label: const Text('Mở video tab mới'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _videoFinished = true;
                                _error = null;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white54),
                            ),
                            icon: const Icon(Icons.check_rounded, size: 16),
                            label: const Text('Đã xem — vào kiểm tra'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            else if (_controller != null && _controller!.value.isInitialized)
              VideoPlayer(_controller!),
            // Tap blocker layer (no double-click fullscreen, no native menu)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _togglePlay,
              ),
            ),
            if (_windowBlurred)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.92),
                  child: const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Nội dung bài giảng được bảo vệ.\nVui lòng quay lại trang để tiếp tục.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ),
            // Custom controls bar
            if (_controller != null && _controller!.value.isInitialized)
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildProgressBar(),
                      Row(
                        children: [
                          IconButton(
                            onPressed: _togglePlay,
                            icon: Icon(
                              _isPlaying
                                  ? Icons.pause_rounded
                                  : (_videoFinished
                                      ? Icons.replay_rounded
                                      : Icons.play_arrow_rounded),
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Tua lùi 10s',
                            onPressed: _rewind,
                            icon: const Icon(Icons.replay_10_rounded,
                                color: Colors.white),
                          ),
                          const Spacer(),
                          Text(
                            '${_fmt(_controller!.value.position)} / ${_fmt(_controller!.value.duration)}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                          const SizedBox(width: 8),
                          const Tooltip(
                            message: 'Không cho phép tua nhanh',
                            child: Icon(Icons.lock_outline_rounded,
                                color: Colors.white70, size: 18),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final c = _controller!;
    final dur = c.value.duration.inMilliseconds.clamp(1, 1 << 31).toDouble();
    final pos = c.value.position.inMilliseconds.toDouble();
    final watched = _maxWatched.inMilliseconds.toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Stack(
        children: [
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // watched (light)
          FractionallySizedBox(
            widthFactor: (watched / dur).clamp(0.0, 1.0),
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white38,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // current (primary)
          FractionallySizedBox(
            widthFactor: (pos / dur).clamp(0.0, 1.0),
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfo() {
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
          Text(widget.lesson.title, style: AppTextStyles.sectionHeader),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Đối tượng: ${widget.lesson.targetRole}',
                    style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.lock_rounded, size: 14, color: AppColors.textHint),
              const SizedBox(width: 4),
              Text('Không tải/tua nhanh/chụp màn hình',
                  style: AppTextStyles.caption),
            ],
          ),
          if ((_detail?['description'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(_detail!['description'] as String,
                style: AppTextStyles.bodyText),
          ],
        ],
      ),
    );
  }

  Widget _buildQuizCta() {
    final qs = (_detail?['questions'] as List?) ?? [];
    final canQuiz = _videoFinished && qs.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.quiz_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bài kiểm tra cuối bài',
                    style: AppTextStyles.bodyTextMedium),
                Text(
                  qs.isEmpty
                      ? 'Bài này chưa có câu hỏi.'
                      : (canQuiz
                          ? '${qs.length} câu hỏi — sẵn sàng làm bài.'
                          : 'Xem hết video để mở khoá ${qs.length} câu hỏi.'),
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: canQuiz ? _openQuiz : null,
            icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
            label: const Text('Vào kiểm tra'),
          ),
        ],
      ),
    );
  }
}
