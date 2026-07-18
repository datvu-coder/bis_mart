import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/constants/app_colors.dart';
import '../../services/api_service.dart';

/// Mobile (iOS/Android) lesson video player backed by `video_player`.
/// Enforces no-skip-ahead (mirrors the web player's protection) and pauses
/// automatically when the app goes to the background.
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

class _LessonVideoPlayerState extends State<LessonVideoPlayer>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _initializing = true;
  String? _error;
  bool _videoFinished = false;
  Duration _maxWatched = Duration.zero;
  bool _finishedNotified = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrapVideo();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _controller?.pause();
    }
  }

  Future<void> _bootstrapVideo() async {
    try {
      final url =
          await ApiService().buildPartVideoUrl(widget.lessonId, widget.partId);
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
      if (!mounted) return;
      controller.addListener(_onTick);
      setState(() {
        _controller = controller;
        _initializing = false;
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
    if (!mounted) return;
    final c = _controller;
    if (c == null) return;
    final value = c.value;
    final pos = value.position;

    if (pos > _maxWatched + const Duration(milliseconds: 350)) {
      c.seekTo(_maxWatched);
      return;
    }
    if (pos > _maxWatched) _maxWatched = pos;

    if (value.isInitialized &&
        value.duration.inMilliseconds > 0 &&
        pos >= value.duration - const Duration(milliseconds: 300) &&
        !_finishedNotified) {
      _finishedNotified = true;
      _videoFinished = true;
      widget.onFinished();
    }

    setState(() {});
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      if (_videoFinished) {
        _videoFinished = false;
        _finishedNotified = false;
        _maxWatched = Duration.zero;
        c.seekTo(Duration.zero);
      }
      c.play();
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

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.6;
    final controller = _controller;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: Colors.black),
                if (controller != null && controller.value.isInitialized)
                  VideoPlayer(controller),
                if (_initializing)
                  const Center(
                      child: CircularProgressIndicator(color: Colors.white))
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
                if (controller != null && _error == null)
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
                          _buildProgressBar(controller),
                          Row(children: [
                            IconButton(
                              onPressed: _togglePlay,
                              icon: Icon(
                                controller.value.isPlaying
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
                              '${_fmt(controller.value.position)} / ${_fmt(controller.value.duration)}',
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
    );
  }

  Widget _buildProgressBar(VideoPlayerController controller) {
    final dur = controller.value.duration.inMilliseconds
        .clamp(1, 1 << 31)
        .toDouble();
    final pos = controller.value.position.inMilliseconds.toDouble();
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
