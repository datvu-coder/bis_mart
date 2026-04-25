import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/lesson.dart';
import '../../services/api_service.dart';
import 'lesson_quiz_screen.dart';

/// Anti-piracy lesson player using a native HTML5 <video> element via
/// HtmlElementView. Avoids the `video_player` plugin (which can throw
/// "init has not been implemented" on web).
class LessonDetailScreen extends StatefulWidget {
  final Lesson lesson;
  const LessonDetailScreen({super.key, required this.lesson});

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen>
    with WidgetsBindingObserver {
  html.VideoElement? _video;
  late final String _viewType;
  bool _initializing = true;
  String? _error;
  bool _videoFinished = false;
  bool _isPlaying = false;
  Duration _maxWatched = Duration.zero;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _windowBlurred = false;
  Timer? _tick;
  StreamSubscription<html.Event>? _blurSub;
  StreamSubscription<html.Event>? _focusSub;
  StreamSubscription<html.Event>? _ctxSub;
  StreamSubscription<html.KeyboardEvent>? _keySub;

  Map<String, dynamic>? _detail;

  @override
  void initState() {
    super.initState();
    _viewType =
        'lesson-video-${widget.lesson.id}-${DateTime.now().microsecondsSinceEpoch}';
    WidgetsBinding.instance.addObserver(this);
    _attachWebGuards();
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    _blurSub?.cancel();
    _focusSub?.cancel();
    _ctxSub?.cancel();
    _keySub?.cancel();
    try {
      _video?.pause();
      _video?.removeAttribute('src');
      _video?.load();
    } catch (_) {}
    super.dispose();
  }

  void _attachWebGuards() {
    if (!kIsWeb) return;
    _ctxSub = html.document.onContextMenu.listen((e) => e.preventDefault());
    _blurSub = html.window.onBlur.listen((_) {
      if (mounted) setState(() => _windowBlurred = true);
      _video?.pause();
    });
    _focusSub = html.window.onFocus.listen((_) {
      if (mounted) setState(() => _windowBlurred = false);
    });
    _keySub = html.window.onKeyDown.listen((e) {
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
      if (k == 'ArrowRight' || k == 'ArrowLeft') {
        e.preventDefault();
      }
    });
  }

  Future<void> _bootstrap() async {
    try {
      final api = ApiService();
      final detail = await api.getLessonDetail(widget.lesson.id);
      if (!mounted) return;
      _detail = detail;
      String url = '';
      final videoPath = (detail['videoPath'] as String?) ?? '';
      if (videoPath.isNotEmpty) {
        url = await api.buildLessonVideoUrl(widget.lesson.id);
      } else {
        url = (detail['videoUrl'] as String?) ?? widget.lesson.videoUrl ?? '';
      }
      if (url.isEmpty) {
        setState(() {
          _initializing = false;
          _error = 'Bài giảng chưa có video.';
        });
        return;
      }

      final video = html.VideoElement()
        ..src = url
        ..autoplay = false
        ..controls = false
        ..setAttribute(
            'controlslist', 'nodownload noplaybackrate noremoteplayback')
        ..setAttribute('disablepictureinpicture', 'true')
        ..setAttribute('playsinline', 'true')
        ..setAttribute('preload', 'auto')
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'contain'
        ..style.backgroundColor = '#000';
      video.onContextMenu.listen((e) => e.preventDefault());

      video.onLoadedMetadata.listen((_) {
        final d = video.duration;
        if (d.isFinite && mounted) {
          setState(() {
            _duration = Duration(milliseconds: (d * 1000).toInt());
            _initializing = false;
          });
        }
      });
      video.onPlay.listen((_) {
        if (mounted) setState(() => _isPlaying = true);
      });
      video.onPause.listen((_) {
        if (mounted) setState(() => _isPlaying = false);
      });
      video.onEnded.listen((_) {
        if (mounted) {
          setState(() {
            _videoFinished = true;
            _isPlaying = false;
          });
        }
      });
      video.onError.listen((_) {
        final err = video.error;
        String msg;
        if (err != null) {
          switch (err.code) {
            case 1:
              msg = 'Trình duyệt huỷ tải video.';
              break;
            case 2:
              msg = 'Lỗi mạng khi tải video.';
              break;
            case 3:
              msg = 'Không giải mã được video. Hãy upload .mp4 (H.264).';
              break;
            case 4:
              msg = 'Định dạng không hỗ trợ.\nHãy upload .mp4 (H.264 + AAC).';
              break;
            default:
              msg = 'Lỗi khi phát video (code ${err.code}).';
          }
        } else {
          msg = 'Không tải được video.';
        }
        if (mounted) {
          setState(() {
            _initializing = false;
            _error = msg;
          });
        }
      });

      // ignore: undefined_prefixed_name
      ui_web.platformViewRegistry
          .registerViewFactory(_viewType, (int _) => video);

      _video = video;
      if (mounted) setState(() {});

      _tick = Timer.periodic(const Duration(milliseconds: 250), (_) => _onTick());

      Future.delayed(const Duration(seconds: 8), () {
        if (mounted && _initializing && _error == null) {
          setState(() => _initializing = false);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = 'Không tải được video.\n$e';
      });
    }
  }

  void _onTick() {
    final v = _video;
    if (v == null) return;
    final cur = v.currentTime;
    if (!cur.isFinite) return;
    final pos = Duration(milliseconds: (cur * 1000).toInt());
    if (pos > _maxWatched + const Duration(milliseconds: 350)) {
      v.currentTime = _maxWatched.inMilliseconds / 1000.0;
      return;
    }
    if (pos > _maxWatched) _maxWatched = pos;
    if (mounted) {
      setState(() {
        _position = pos;
        if (_duration == Duration.zero && v.duration.isFinite) {
          _duration = Duration(milliseconds: (v.duration * 1000).toInt());
        }
      });
    }
  }

  void _togglePlay() {
    final v = _video;
    if (v == null) return;
    if (!v.paused) {
      v.pause();
    } else {
      if (_videoFinished) {
        _videoFinished = false;
        _maxWatched = Duration.zero;
        v.currentTime = 0;
      }
      v.play();
    }
  }

  void _rewind() {
    final v = _video;
    if (v == null) return;
    final back = v.currentTime - 10;
    v.currentTime = back < 0 ? 0 : back;
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
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
        title: Text(widget.lesson.title,
            maxLines: 1, overflow: TextOverflow.ellipsis),
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
            if (_video != null) HtmlElementView(viewType: _viewType),
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
                      const Icon(Icons.lock_rounded,
                          color: Colors.white70, size: 36),
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13, height: 1.4),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Vui lòng liên hệ quản trị viên.',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            // Tap layer for play/pause; leaves a 56px strip at bottom for controls.
            Positioned(
              left: 0, right: 0, top: 0, bottom: 56,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _togglePlay,
                child: const SizedBox.expand(),
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
            if (_video != null && _error == null)
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
                            '${_fmt(_position)} / ${_fmt(_duration)}',
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
    final dur = _duration.inMilliseconds.clamp(1, 1 << 31).toDouble();
    final pos = _position.inMilliseconds.toDouble();
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
              const Icon(Icons.lock_rounded,
                  size: 14, color: AppColors.textHint),
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
