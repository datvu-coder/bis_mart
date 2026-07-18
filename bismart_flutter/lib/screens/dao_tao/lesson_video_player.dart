export 'lesson_video_player_stub.dart'
    if (dart.library.html) 'lesson_video_player_web.dart'
    if (dart.library.io) 'lesson_video_player_mobile.dart';
