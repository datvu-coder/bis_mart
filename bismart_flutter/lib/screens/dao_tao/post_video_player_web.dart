// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import '../../services/api_service.dart';

/// Native HTML5 video player (range-streamed, JWT-auth via ?t=).
class PostVideoPlayer extends StatefulWidget {
  final String postId;
  const PostVideoPlayer({super.key, required this.postId});

  @override
  State<PostVideoPlayer> createState() => _PostVideoPlayerState();
}

class _PostVideoPlayerState extends State<PostVideoPlayer> {
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
