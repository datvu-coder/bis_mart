import 'package:geolocator/geolocator.dart';

Future<({double latitude, double longitude})> getPlatformPosition() async {
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw 'Không thể lấy vị trí GPS. Vui lòng cấp quyền truy cập vị trí.';
  }

  if (!await Geolocator.isLocationServiceEnabled()) {
    throw 'Vui lòng bật dịch vụ định vị (GPS) trên thiết bị.';
  }

  final position = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
  );
  return (latitude: position.latitude, longitude: position.longitude);
}
