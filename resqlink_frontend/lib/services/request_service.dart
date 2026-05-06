// ─────────────────────────────────────────────────────────────────────────────
// services/request_service.dart — Blood & Ambulance requests
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_models.dart';
import 'dart:math' show sin, cos, sqrt, atan2, pi;

class RequestService {
  static SupabaseClient get _sb => Supabase.instance.client;

  // ── Blood Requests ──────────────────────────────────────────────────────────

  static Future<List<BloodRequest>> fetchNearbyBloodRequests() async {
    final data = await _sb
        .from('blood_requests')
        .select()
        .eq('status', 'pending') // cancelled is excluded
        .order('created_at', ascending: false);
    return (data as List).map((e) => BloodRequest.fromJson(e)).toList();
  }

  static Future<BloodRequest> submitBloodRequest(
      Map<String, dynamic> data) async {
    final user = _sb.auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    final response = await _sb
        .from('blood_requests')
        .insert({
          'customer_id': user.id,
          'blood_type': data['bloodType'],
          'hospital': data['hospital'],
          'address': data['address'] ?? data['hospital'] ?? '',
          'units': data['units'],
          'urgency_level': data['priority'] == 'Urgent' ? 'URGENT' : 'STANDARD',
          'status': 'pending',
          if (data['latitude'] != null) 'latitude': data['latitude'],
          if (data['longitude'] != null) 'longitude': data['longitude'],
        })
        .select()
        .single();

    return BloodRequest.fromJson(response);
  }

  // ── Ambulance Requests ──────────────────────────────────────────────────────

  static Future<AmbulanceRequest> submitAmbulanceRequest(
      Map<String, dynamic> data) async {
    final user = _sb.auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    final double? pickupLat = (data['pickupLat'] as num?)?.toDouble();
    final double? pickupLng = (data['pickupLng'] as num?)?.toDouble();
    final double? dropLat = (data['dropLat'] as num?)?.toDouble();
    final double? dropLng = (data['dropLng'] as num?)?.toDouble();

    final inserted = await _sb
        .from('ambulance_requests')
        .insert({
          'customer_id': user.id,
          'pickup_location': data['address'],
          'drop_location': data['dropLocation'] ?? '',
          'emergency_type': data['emergencyType'],
          'severity': (data['severity'] as String).toLowerCase(),
          'notes': data['notes'] ?? '',
          'status': 'waiting',
          'pickup_lat': pickupLat,
          'pickup_lng': pickupLng,
          'drop_lat': dropLat,
          'drop_lng': dropLng,
        })
        .select()
        .single();

    return AmbulanceRequest(
      id: inserted['id']?.toString() ?? '',
      emergencyType: inserted['emergency_type'] ?? '',
      severity: inserted['severity'] ?? 'medium',
      address: inserted['pickup_location'] ?? '',
      notes: inserted['notes'] ?? '',
      status: RequestStatus.waiting,
    );
  }

  // ── Poll for driver match ───────────────────────────────────────────────────
  /// Polls DB every 3 s for up to 120 s (40 attempts).
  /// Resolves when status = 'accepted'. Throws [DriverNotFoundException] on timeout.
  // ── Poll for driver match ───────────────────────────────────────────────────
  /// Polls DB every 3 s for up to 120 s (40 attempts).
  /// Resolves when status = 'accepted'. Throws [DriverNotFoundException] on timeout.
  // ── Poll for driver match ───────────────────────────────────────────────────
  static Future<AmbulanceRequest> pollForMatch(String requestId) async {
    for (int i = 0; i < 40; i++) {
      await Future.delayed(const Duration(seconds: 3));
      try {
        // Step 1: Get the ambulance request
        final requestRes = await _sb
            .from('ambulance_requests')
            .select('*')
            .eq('id', requestId)
            .single();

        final status = requestRes['status'] as String?;
        final driverId = requestRes['driver_id'] as String?;

        // Check if driver accepted
        if ((status == 'accepted' || status == 'completed') &&
            driverId != null) {
          // Step 2: Get driver record to find user_id
          final driverRes = await _sb
              .from('drivers')
              .select('user_id')
              .eq('id', driverId)
              .maybeSingle();

          // Step 3: Get profile using user_id (profiles.id = auth.users.id)
          String driverName = 'Driver';
          String driverPhone = '';

          if (driverRes != null && driverRes['user_id'] != null) {
            final profileRes = await _sb
                .from('profiles')
                .select('name, phone')
                .eq('id', driverRes['user_id'])
                .maybeSingle();

            if (profileRes != null) {
              driverName = profileRes['name'] as String? ?? 'Driver';
              driverPhone = profileRes['phone'] as String? ?? '';
              debugPrint('[pollForMatch] Found driver: $driverName');
            }
          }

          // Step 4: Calculate ETA from coordinates
          final pickupLat = _toDouble(requestRes['pickup_lat']);
          final pickupLng = _toDouble(requestRes['pickup_lng']);
          final dropLat = _toDouble(requestRes['drop_lat']);
          final dropLng = _toDouble(requestRes['drop_lng']);

          // Try to get driver's current location for accurate ETA
          double? driverLat, driverLng;
          if (driverRes != null) {
            final driverWithLoc = await _sb
                .from('drivers')
                .select('current_lat, current_lng')
                .eq('id', driverId)
                .maybeSingle();
            if (driverWithLoc != null) {
              driverLat = _toDouble(driverWithLoc['current_lat']);
              driverLng = _toDouble(driverWithLoc['current_lng']);
            }
          }

          // Calculate ETA (fallback to pickup→drop if driver location unknown)
          final eta = _calculateEta(
            driverLat: driverLat ?? pickupLat,
            driverLng: driverLng ?? pickupLng,
            pickupLat: pickupLat,
            pickupLng: pickupLng,
          );

          debugPrint(
              '[pollForMatch] ETA calculated: $eta | Coords: pickup=($pickupLat,$pickupLng) drop=($dropLat,$dropLng)');

          return AmbulanceRequest(
            id: requestRes['id']?.toString() ?? requestId,
            emergencyType: requestRes['emergency_type'] ?? '',
            severity: requestRes['severity'] ?? 'medium',
            address: requestRes['pickup_location'] ?? '',
            dropLocation: requestRes['drop_location'] as String?,
            notes: requestRes['notes'] ?? '',
            status: RequestStatus.matched,
            assignedDriverName: driverName,
            assignedDriverPhone: driverPhone,
            eta: eta,
            pickupLat: pickupLat,
            pickupLng: pickupLng,
            dropLat: dropLat,
            dropLng: dropLng,
          );
        }
      } catch (e, stack) {
        debugPrint('[pollForMatch] attempt $i error: $e\n$stack');
      }
    }
    throw DriverNotFoundException('No driver found. Please try again.');
  }

// ── Helper: Calculate ETA from coordinates ───────────────────────────────────
  static String _calculateEta({
    double? driverLat,
    double? driverLng,
    double? pickupLat,
    double? pickupLng,
  }) {
    // If any coordinate is missing, return default
    if (driverLat == null ||
        driverLng == null ||
        pickupLat == null ||
        pickupLng == null) {
      return '5-10 min'; // Safe fallback
    }

    // Calculate distance using Haversine formula
    final distance =
        _haversineDistance(driverLat, driverLng, pickupLat, pickupLng);

    // Assume average city speed: 25-30 km/h (includes traffic lights, etc.)
    const avgSpeedKmh = 28.0;

    // Calculate time in minutes
    final timeMinutes = (distance / avgSpeedKmh * 60).round();

    // Format nicely
    if (timeMinutes < 2) return '1-2 min';
    if (timeMinutes < 5) return '$timeMinutes min';
    if (timeMinutes < 15) return '$timeMinutes min';
    if (timeMinutes < 30)
      return '${timeMinutes ~/ 5 * 5} min'; // Round to nearest 5
    return '${(timeMinutes / 60).toStringAsFixed(1)} hr';
  }

// ── Helper: Haversine distance between two coordinates (in km) ───────────────
  static double _haversineDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0; // Earth's radius in kilometers
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static double _deg2rad(double deg) => deg * 3.14159265359 / 180.0;

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}

/// Typed exception — customer screen catches this and shows error instead of freezing.
class DriverNotFoundException implements Exception {
  final String message;
  const DriverNotFoundException(this.message);
  @override
  String toString() => message;
}

Future<void> acceptRequest(String requestId, String driverId) async {
  var _sb;
  await _sb
      .from('ambulance_requests')
      .update({
        'status': 'accepted',
        'driver_id': driverId,
      })
      .eq('id', requestId)
      .eq('status', 'waiting'); // safety check
}
