import 'package:flutter/material.dart';

class LessonVideoPlayer extends StatelessWidget {
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
  Widget build(BuildContext context) => const SizedBox.shrink();
}
