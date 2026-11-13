
import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Check whether location service is enabled on the device.
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Check and request location permission.
  Future<LocationPermission> checkPermission() async {
    LocationPermission permission =
        await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('লোকেশন ব্যবহারের অনুমতি দেওয়া হয়নি।');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'লোকেশন পারমিশন স্থায়ীভাবে বন্ধ। '
        'ফোনের Settings থেকে অনুমতি দিন।',
      );
    }

    return permission;
  }

  /// Get current device location.
  Future<Position> getCurrentLocation() async {
    final bool serviceEnabled =
        await isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception(
        'আপনার ফোনের GPS/Location চালু করুন।',
      );
    }

    await checkPermission();

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
          timeLimit: Duration(seconds: 30),
        ),
      );
    } catch (e) {
      throw Exception(
        'বর্তমান লোকেশন সংগ্রহ করা যায়নি। আবার চেষ্টা করুন।',
      );
    }
  }

  /// Get latitude and longitude.
  Future<Map<String, double>> getCoordinates() async {
    final Position position = await getCurrentLocation();

    return {
      'latitude': position.latitude,
      'longitude': position.longitude,
    };
  }

  /// Open device location settings.
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Open application permission settings.
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// Calculate distance between two coordinates in kilometers.
  double calculateDistance({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    return Geolocator.distanceBetween(
          startLatitude,
          startLongitude,
          endLatitude,
          endLongitude,
        ) /
        1000;
  }
}
