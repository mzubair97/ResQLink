// ─────────────────────────────────────────────────────────────────────────────
// services/location_service.dart
// Real GPS location service using geolocator + geocoding.
// Handles permission flow and returns human-readable address.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  // ── Permission ─────────────────────────────────────────────────────────────

  /// Request location permission and return whether it was granted.
  /// Throws a descriptive [String] on permanent denial.
  static Future<bool> requestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.deniedForever) {
      throw 'Location permission permanently denied. '
          'Please enable it in app settings.';
    }

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw 'Location permission denied.';
      }
      if (permission == LocationPermission.deniedForever) {
        throw 'Location permission permanently denied. '
            'Please enable it in app settings.';
      }
    }

    return true;
  }

  // ── Live GPS position ──────────────────────────────────────────────────────

  /// Returns the current [Position] (lat/lng) from GPS.
  /// Handles permissions internally.
  static Future<Position> getCurrentPosition() async {
    await requestPermission();
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 15),
    );
  }

  // ── Reverse geocoding ──────────────────────────────────────────────────────

  /// Returns a readable address string from [lat]/[lng].
  /// Falls back to raw coordinates on any error.
  static Future<String> reverseGeocode(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return '$lat, $lng';
      final p = placemarks.first;
      final parts = <String>[
        if (p.street?.isNotEmpty == true) p.street!,
        if (p.locality?.isNotEmpty == true) p.locality!,
        if (p.country?.isNotEmpty == true) p.country!,
      ];
      return parts.isNotEmpty ? parts.join(', ') : '$lat, $lng';
    } catch (_) {
      return '$lat, $lng';
    }
  }

  // ── Combined helper ────────────────────────────────────────────────────────

  /// Fetches current GPS position AND converts it to a readable address.
  /// Returns a [LocationResult] with both lat/lng and the readable address.
  static Future<LocationResult> getCurrentLocationWithAddress() async {
    final pos = await getCurrentPosition();
    final address = await reverseGeocode(pos.latitude, pos.longitude);
    return LocationResult(
      latitude: pos.latitude,
      longitude: pos.longitude,
      address: address,
    );
  }
}

/// Value object returned by [LocationService.getCurrentLocationWithAddress].
class LocationResult {
  final double latitude;
  final double longitude;
  final String address;

  const LocationResult({
    required this.latitude,
    required this.longitude,
    required this.address,
  });
}
