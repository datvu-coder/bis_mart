import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<({double latitude, double longitude})> getPlatformPosition() {
  final completer = Completer<({double latitude, double longitude})>();

  html.window.navigator.geolocation.getCurrentPosition().then((position) {
    final coords = position.coords;
    if (coords == null) {
      completer.completeError('Không thể lấy toạ độ GPS');
      return;
    }
    completer.complete((
      latitude: (coords.latitude ?? 0).toDouble(),
      longitude: (coords.longitude ?? 0).toDouble(),
    ));
  }).catchError((error) {
    completer.completeError('Không thể lấy vị trí GPS. Vui lòng cấp quyền truy cập vị trí.');
  });

  return completer.future;
}
