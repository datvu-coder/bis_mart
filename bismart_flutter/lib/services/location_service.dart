import 'dart:math' as math;
import 'location_platform_stub.dart'
    if (dart.library.html) 'location_platform_web.dart'
    if (dart.library.io) 'location_platform_io.dart';

class LocationService {
  static Future<({double latitude, double longitude})> getCurrentPosition() {
    return getPlatformPosition();
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
