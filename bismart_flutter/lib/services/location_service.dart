import 'dart:async';
import 'dart:math' as math;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class LocationService {
  static Future<({double latitude, double longitude})> getCurrentPosition() async {
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

  /// Haversine distance in meters
  static double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) * math.cos(_toRad(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  static double _toRad(double deg) => deg * 3.14159265358979 / 180;
}
