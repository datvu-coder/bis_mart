Future<({double latitude, double longitude})> getPlatformPosition() {
  throw UnsupportedError('GPS is not supported on this platform.');
}
