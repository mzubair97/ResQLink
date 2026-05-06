// services/trip_service.dart
import 'dart:math' show sin, cos, sqrt, atan2, pi;
import 'package:flutter/foundation.dart';
// ← CHANGED: use http package, not dart:io HttpClient
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_models.dart';
import 'hospital_location_service.dart';

class TripService {
  static SupabaseClient get _sb => Supabase.instance.client;

  // Simple in-memory cache so we don't hammer Nominatim
  static final Map<String, String> _geoCache = {};

  static Future<List<Trip>> fetchTripHistory(String driverId) async {
    try {
      final res = await _sb
          .from('ambulance_requests')
          .select()
          .eq('driver_id', driverId)
          .eq('status', 'completed')
          .order('created_at', ascending: false);

      if ((res as List).isEmpty) return [];

      // Reverse-geocode all unique coord pairs in parallel
      final futures = res.map((r) => buildTripFromRow(r)).toList();
      return await Future.wait(futures);
    } catch (e) {
      debugPrint('[TripService] fetchTripHistory error: $e');
      return [];
    }
  }

  static Future<Trip> buildTripFromRow(Map<String, dynamic> r) async {
    final pickupText = r['pickup_location'] as String? ?? '';
    final dropText = r['drop_location'] as String? ?? '';
    final pickupLat = (r['pickup_lat'] as num?)?.toDouble();
    final pickupLng = (r['pickup_lng'] as num?)?.toDouble();
    final dropLat = (r['drop_lat'] as num?)?.toDouble();
    final dropLng = (r['drop_lng'] as num?)?.toDouble();

    // ── Pickup label ────────────────────────────────────────────────────────
    final String fromLabel;
    if (pickupLat != null && pickupLng != null) {
      fromLabel = await _reverseGeocode(pickupLat, pickupLng);
    } else if (pickupText.isNotEmpty && !_looksLikeCoords(pickupText)) {
      fromLabel = pickupText;
    } else if (_looksLikeCoords(pickupText)) {
      fromLabel = await _geocodeText(pickupText);
    } else {
      fromLabel = '—';
    }

    // ── Drop label — PREFER the stored hospital name over geocoding ─────────
    final String toLabel;
    if (dropText.isNotEmpty &&
        !_looksLikeCoords(dropText) &&
        dropText != 'Nearest Hospital' &&
        dropText != 'Drop not recorded') {
      // We stored a real hospital name — use it directly, no geocoding needed
      toLabel = dropText;
    } else if (dropLat != null && dropLng != null) {
      // Geocode the hospital coordinates
      toLabel = await _reverseGeocode(dropLat, dropLng);
    } else if (_looksLikeCoords(dropText)) {
      toLabel = await _geocodeText(dropText);
    } else {
      toLabel = 'Drop not recorded';
    }

    return Trip(
      id: r['id']?.toString() ?? '',
      caseId:
          '#${(r['id']?.toString() ?? '000000').substring(0, 6).toUpperCase()}',
      from: fromLabel,
      to: toLabel,
      duration: _calcDuration(
        r['accepted_at'] ??
            r['created_at'], // prefer accepted_at, fall back to created_at
        r['completed_at'],
      ),
      distance: _calcDistance(
          r['pickup_lat'], r['pickup_lng'], r['drop_lat'], r['drop_lng']),
      date: formatDateStatic(r['created_at']),
      status: 'Completed',
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static bool _looksLikeCoords(String s) {
    return RegExp(r'^-?\d+\.\d+,?\s*-?\d+\.\d+$').hasMatch(s.trim());
  }

  /// Reverse-geocode lat/lng → human-readable area name via Nominatim
  /// FIX: Uses http package instead of dart:io HttpClient (which fails on Android)
  static Future<String> _reverseGeocode(double lat, double lng) async {
    final key = '${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)}';
    if (_geoCache.containsKey(key)) return _geoCache[key]!;
    final label = await HospitalLocationService.reverseGeocode(lat, lng);
    final result = label.isNotEmpty ? label : key;
    _geoCache[key] = result;
    return result;
  }

  /// Forward-geocode a raw "lat, lng" string
  static Future<String> _geocodeText(String coordText) async {
    final parts = coordText.split(RegExp(r'[,\s]+'));
    if (parts.length >= 2) {
      final lat = double.tryParse(parts[0]);
      final lng = double.tryParse(parts[1]);
      if (lat != null && lng != null) return _reverseGeocode(lat, lng);
    }
    return coordText;
  }

  /// FIX: Correct haversine formula (previous version had a broken sin² calculation)
  static String _calcDistance(
      dynamic pLat, dynamic pLng, dynamic dLat, dynamic dLng) {
    try {
      final lat1 = (pLat as num).toDouble();
      final lng1 = (pLng as num).toDouble();
      final lat2 = (dLat as num).toDouble();
      final lng2 = (dLng as num).toDouble();

      // Guard: same point means no drop coords saved
      if ((lat1 - lat2).abs() < 0.0001 && (lng1 - lng2).abs() < 0.0001) {
        return '—';
      }

      // ── Correct haversine ──────────────────────────────────────────────────
      const R = 6371.0;
      final dLatR = (lat2 - lat1) * pi / 180;
      final dLngR = (lng2 - lng1) * pi / 180;
      final a = sin(dLatR / 2) * sin(dLatR / 2) +
          cos(lat1 * pi / 180) *
              cos(lat2 * pi / 180) *
              sin(dLngR / 2) *
              sin(dLngR / 2);
      final c = 2 * atan2(sqrt(a), sqrt(1 - a));
      final dist = R * c;

      if (dist < 0.1) return '—'; // suspiciously small → likely bad data
      return '${dist.toStringAsFixed(1)} km';
    } catch (_) {
      return '—';
    }
  }

  static String _calcDuration(dynamic start, dynamic end) {
    // 'start' here should be accepted_at, 'end' is completed_at
    if (start == null || end == null) return '—';
    try {
      final s = DateTime.parse(start as String).toLocal();
      final e = DateTime.parse(end as String).toLocal();
      if (e.isBefore(s) || e.isAtSameMomentAs(s)) return '—';
      final diff = e.difference(s);
      if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes % 60}m';
      if (diff.inMinutes > 0)
        return '${diff.inMinutes}m ${diff.inSeconds % 60}s';
      return '< 1m';
    } catch (_) {
      return '—';
    }
  }

  /// Convert UTC ISO string to local time before comparing with today
  static String formatDateStatic(String? iso) {
    if (iso == null) return '—';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '—';
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return 'TODAY';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.day == yesterday.day &&
        dt.month == yesterday.month &&
        dt.year == yesterday.year) {
      return 'YESTERDAY';
    }
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  // ── Stats helpers (called from DriverTripsTab) ─────────────────────────────

  /// Total km driven across a list of trips (excludes '—' entries)
  static double totalKm(List<Trip> trips) {
    double sum = 0;
    for (final t in trips) {
      if (t.distance != '—') {
        final val = double.tryParse(t.distance.replaceAll(' km', ''));
        if (val != null) sum += val;
      }
    }
    return sum;
  }

  /// Average trip duration in minutes across a list of trips (excludes '—')
  static double? avgDurationMinutes(List<Trip> trips) {
    final valid = <int>[];
    for (final t in trips) {
      if (t.duration == '—') continue;
      // Parse "Xm Ys" or "Xh Ym"
      final hoursMatch = RegExp(r'(\d+)h').firstMatch(t.duration);
      final minsMatch = RegExp(r'(\d+)m').firstMatch(t.duration);
      final secsMatch = RegExp(r'(\d+)s').firstMatch(t.duration);
      int totalMins = 0;
      if (hoursMatch != null) totalMins += int.parse(hoursMatch.group(1)!) * 60;
      if (minsMatch != null) totalMins += int.parse(minsMatch.group(1)!);
      if (secsMatch != null && hoursMatch == null && minsMatch == null) {
        totalMins = 1; // less than 1 min → round up to 1
      }
      if (totalMins > 0) valid.add(totalMins);
    }
    if (valid.isEmpty) return null;
    return valid.reduce((a, b) => a + b) / valid.length;
  }
}
