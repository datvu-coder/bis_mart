export 'post_video_player_stub.dart'
    if (dart.library.html) 'post_video_player_web.dart'
    if (dart.library.io) 'post_video_player_mobile.dart';
