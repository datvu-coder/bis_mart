// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../services/api_service.dart';

/// Web video player with anti-piracy guards: blocks right-click, PrintScreen,
/// F12, Ctrl+S/P, disables seeking ahead of the max watched position, and
/// blacks out the video when the browser tab/window loses focus.
class LessonVideoPlayer extends StatefulWidget {
  final String lessonId;
  final String partId;
  final VoidCallback onFinished;

  const LessonVideoPlayer({
    super.key,
    required this.lessonId,
    required this.partId,
    required this.onFinished,
  });

  @override
  State<LessonVideoPlayer> createState() => _LessonVideoPlayerState();
}

class _LessonVideoPlayerState extends State<LessonVideoPlayer> {
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
  bool _videoRegistered = false;

  @override
  void initState() {
    super.initState();
    _viewType =
        'lesson-part-${widget.partId}-${DateTime.now().microsecondsSinceEpoch}';
    _attachWebGuards();
    _bootstrapVideo();
  }

  @override
  void dispose() {
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

  Future<void> _bootstrapVideo() async {
    try {
      final api = ApiService();
      final url = await api.buildPartVideoUrl(widget.lessonId, widget.partId);

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
      video.onPlay
          .listen((_) => mounted ? setState(() => _isPlaying = true) : null);
      video.onPause
          .listen((_) => mounted ? setState(() => _isPlaying = false) : null);
      video.onEnded.listen((_) {
        if (mounted) {
          setState(() {
            _videoFinished = true;
            _isPlaying = false;
          });
          widget.onFinished();
        }
      });
      video.onError.listen((_) {
        final err = video.error;
        String msg = err == null
            ? 'Không tải được video.'
            : 'Lỗi khi phát video (code ${err.code}).';
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
      _videoRegistered = true;
      _video = video;
      if (mounted) setState(() {});
      _tick = Timer.periodic(
          const Duration(milliseconds: 250), (_) => _onTick());
      Future.delayed(const Duration(seconds: 8), () {
        if (mounted && _initializing && _error == null) {
          setState(() => _initializing = false);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = 'Không tải được video: $e';
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

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.6;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SelectionContainer.disabled(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: Colors.black),
                  if (_video != null && _videoRegistered)
                    HtmlElementView(viewType: _viewType),
                  if (_initializing)
                    const Center(
                        child:
                            CircularProgressIndicator(color: Colors.white))
                  else if (_error != null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white, height: 1.4)),
                      ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    bottom: 56,
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
                              'Nội dung được bảo vệ.\nVui lòng quay lại để tiếp tục.',
                              textAlign: TextAlign.center,
                              style:
                                  TextStyle(color: Colors.white, fontSize: 14),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_video != null && _error == null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
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
                            Row(children: [
                              IconButton(
                                onPressed: _togglePlay,
                                icon: Icon(
                                  _isPlaying
                                      ? Icons.pause_rounded
                                      : (_videoFinished
                                          ? Icons.replay_rounded
                                          : Icons.play_arrow_rounded),
                                  color: Colors.white,
                                  size: 28,
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
                              const Icon(Icons.lock_outline_rounded,
                                  color: Colors.white70, size: 16),
                              const SizedBox(width: 8),
                            ]),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
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
      child: Stack(children: [
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
      ]),
    );
  }
}
