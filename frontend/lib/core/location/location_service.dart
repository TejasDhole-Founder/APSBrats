import 'package:geolocator/geolocator.dart';

/// Reads the phone's position once, asking for permission only when called.
class LocationService {
  /// Returns the current latitude and longitude, rounded to three decimal
  /// places (about 0.1 km). Throws [LocationException] with a message the
  /// user can act on.
  Future<({double latitude, double longitude})> currentRounded() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException('Turn on location services to use this.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const LocationException(
        'Location permission is needed. You can type your city instead.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
    );
    return (
      latitude: _round(position.latitude),
      longitude: _round(position.longitude),
    );
  }

  static double _round(double value) =>
      double.parse(value.toStringAsFixed(3));
}

class LocationException implements Exception {
  const LocationException(this.message);

  final String message;

  @override
  String toString() => message;
}
