import 'dart:convert';
import 'dart:math' show sin, cos, sqrt, atan2, pi;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class HospitalLocationService {
  // ── Single method to find nearest hospital ─────────────────────────────
  // Returns: {'name': String, 'lat': double, 'lng': double} or null
  static Future<Map<String, dynamic>?> findNearestHospital(
      double lat, double lng) async {
    debugPrint('🔍 [findNearestHospital] Starting for lat=$lat, lng=$lng');

    // First try online search
    List<Map<String, dynamic>> all = [];
    try {
      final results = await Future.wait([
        _searchNominatim(lat, lng, 'hospital'),
        _searchNominatim(lat, lng, 'clinic'),
        _searchNominatim(lat, lng, 'medical centre'),
      ]);

      // Flatten all results into one list
      for (final list in results) {
        if (list != null) all.addAll(list);
      }

      debugPrint(
          '🔍 [findNearestHospital] Online search returned ${all.length} results');
    } catch (e) {
      debugPrint('🔍 [findNearestHospital] Online search failed: $e');
    }

    // If no online results, use offline database
    if (all.isEmpty) {
      debugPrint(
          '🔍 [findNearestHospital] No online results, using offline hospital database');
      return _findNearestOfflineHospital(lat, lng);
    }

    // Find the single closest one by haversine distance
    double bestDist = double.infinity;
    Map<String, dynamic>? best;

    for (final item in all) {
      final hLat = item['lat'] as double;
      final hLng = item['lng'] as double;
      final d = _km(lat, lng, hLat, hLng);
      if (d < bestDist) {
        bestDist = d;
        best = item;
      }
    }

    if (best != null) {
      debugPrint(
          '🔍 [findNearestHospital] Online success: ${best['name']} (${bestDist.toStringAsFixed(2)} km)');
      return best;
    }

    // Final fallback to offline database
    debugPrint(
        '🔍 [findNearestHospital] No valid online results, using offline hospital database');
    return _findNearestOfflineHospital(lat, lng);
  }

  // ── Offline hospital database for Karachi area ─────────────────────────
  static Map<String, dynamic>? _findNearestOfflineHospital(
      double lat, double lng) {
    // Major hospitals in Karachi with approximate coordinates
    final List<Map<String, dynamic>> karachiHospitals = [
      {
        'name': 'Jinnah Postgraduate Medical Centre',
        'lat': 24.8695,
        'lng': 67.0599
      },
      {'name': 'Civil Hospital Karachi', 'lat': 24.8615, 'lng': 67.0099},
      {'name': 'Aga Khan University Hospital', 'lat': 24.8850, 'lng': 67.0820},
      {'name': 'Indus Hospital', 'lat': 24.8900, 'lng': 67.1700},
      {'name': 'Liaquat National Hospital', 'lat': 24.8670, 'lng': 67.0580},
      {
        'name': 'National Institute of Cardiovascular Diseases',
        'lat': 24.8610,
        'lng': 67.0080
      },
      {
        'name': 'Karachi Institute of Heart Diseases',
        'lat': 24.8600,
        'lng': 67.0070
      },
      {'name': 'Abbasi Shaheed Hospital', 'lat': 24.9500, 'lng': 67.0800},
      {'name': 'Gulshan-e-Iqbal Hospital', 'lat': 24.9300, 'lng': 67.1200},
      {'name': 'Ziauddin Hospital Clifton', 'lat': 24.8100, 'lng': 67.0400},
      {
        'name': 'Ziauddin Hospital North Nazimabad',
        'lat': 24.9600,
        'lng': 67.0500
      },
      {'name': 'Dr. Ziauddin Hospital Kemari', 'lat': 24.8800, 'lng': 67.0000},
      {'name': 'Patel Hospital', 'lat': 24.8700, 'lng': 67.0600},
      {'name': 'South City Hospital', 'lat': 24.8200, 'lng': 67.0800},
      {'name': 'Mideast Hospital', 'lat': 24.8500, 'lng': 67.0300},
      {
        'name': 'Karachi Medical & Dental College Hospital',
        'lat': 24.9400,
        'lng': 67.1100
      },
      {'name': 'Sindh Government Hospital', 'lat': 24.9000, 'lng': 67.1000},
      {'name': 'Korangi General Hospital', 'lat': 24.8300, 'lng': 67.1600},
      {'name': 'Malir City Hospital', 'lat': 24.8900, 'lng': 67.2000},
      {'name': 'Ibrahim Hyderi Hospital', 'lat': 24.8700, 'lng': 67.2200},
    ];

    // Find the closest hospital
    double bestDist = double.infinity;
    Map<String, dynamic>? best;

    for (final hospital in karachiHospitals) {
      final hLat = hospital['lat'] as double;
      final hLng = hospital['lng'] as double;
      final d = _km(lat, lng, hLat, hLng);

      if (d < bestDist && d < 20.0) {
        // Within 20km
        bestDist = d;
        best = hospital;
      }
    }

    if (best != null) {
      debugPrint(
          '🔍 [findNearestHospital] Offline result: ${best['name']} (${bestDist.toStringAsFixed(2)} km)');
    } else {
      debugPrint('🔍 [findNearestHospital] No hospital found within 20km');
    }

    return best;
  }

  static List<Map<String, dynamic>> _offlineFallback(double lat, double lng) {
    final hospitals = <Map<String, dynamic>>[
      {'name': 'Aga Khan University Hospital', 'lat': 24.8933, 'lng': 67.0753},
      {
        'name': 'Jinnah Postgraduate Medical Centre',
        'lat': 24.8979,
        'lng': 67.0595
      },
      {'name': 'Civil Hospital Karachi', 'lat': 24.8603, 'lng': 67.0104},
      {'name': 'Liaquat National Hospital', 'lat': 24.8766, 'lng': 67.0650},
      {'name': 'South City Hospital', 'lat': 24.8441, 'lng': 67.0283},
    ];
    for (final h in hospitals) {
      h['dist'] = _km(lat, lng, h['lat'] as double, h['lng'] as double);
      h['label'] = h['name'] as String;
    }
    hospitals
        .sort((a, b) => (a['dist'] as double).compareTo(b['dist'] as double));
    return hospitals;
  }

  // ── Internal: one Nominatim search query ──────────────────────────────
  static Future<List<Map<String, dynamic>>?> _searchNominatim(
      double lat, double lng, String query) async {
    try {
      debugPrint('🔍 [Overpass] Searching hospitals near $lat, $lng');

      final overpassQuery = '[out:json][timeout:10];'
          '('
          'node["amenity"="hospital"](around:8000,$lat,$lng);'
          'way["amenity"="hospital"](around:8000,$lat,$lng);'
          'node["amenity"="clinic"](around:8000,$lat,$lng);'
          'node["healthcare"="hospital"](around:8000,$lat,$lng);'
          ');'
          'out center 15;';

      final uri = Uri.parse('https://overpass-api.de/api/interpreter');
      final res = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'User-Agent': 'ResQLink/1.0',
            },
            body: 'data=${Uri.encodeComponent(overpassQuery)}',
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) {
        debugPrint('🔍 [Overpass] HTTP ${res.statusCode}');
        return _offlineFallback(lat, lng);
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final elements = data['elements'] as List? ?? [];

      if (elements.isEmpty) {
        debugPrint('🔍 [Overpass] No results, using fallback');
        return _offlineFallback(lat, lng);
      }

      final results = <Map<String, dynamic>>[];
      for (final el in elements) {
        final tags = el['tags'] as Map<String, dynamic>? ?? {};
        final name = tags['name'] as String? ??
            tags['name:en'] as String? ??
            tags['amenity'] as String? ??
            'Hospital';

        // nodes have lat/lon directly; ways have 'center'
        final elLat = (el['lat'] as num?)?.toDouble() ??
            (el['center'] as Map?)?['lat'] as double?;
        final elLng = (el['lon'] as num?)?.toDouble() ??
            (el['center'] as Map?)?['lon'] as double?;

        if (elLat == null || elLng == null) continue;

        final dist = _km(lat, lng, elLat, elLng);
        results.add({
          'name': name,
          'lat': elLat,
          'lng': elLng,
          'dist': dist,
          'label': name,
        });
      }

      results
          .sort((a, b) => (a['dist'] as double).compareTo(b['dist'] as double));

      debugPrint('🔍 [Overpass] Found ${results.length} hospitals');
      return results;
    } catch (e) {
      debugPrint('🔍 [Overpass] Error: $e — using fallback');
      return _offlineFallback(lat, lng);
    }
  }

  // ── Accurate haversine distance in km ─────────────────────────────────
  static double _km(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371.0;
    final phi1 = lat1 * pi / 180;
    final phi2 = lat2 * pi / 180;
    final dPhi = (lat2 - lat1) * pi / 180;
    final dLam = (lng2 - lng1) * pi / 180;
    final a = sin(dPhi / 2) * sin(dPhi / 2) +
        cos(phi1) * cos(phi2) * sin(dLam / 2) * sin(dLam / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  // ── Reverse geocode: lat/lng → human readable address ─────────────────
  static Future<String> reverseGeocode(double lat, double lng) async {
    debugPrint('🔍 [reverseGeocode] Starting for lat=$lat, lng=$lng');

    // Try up to 2 times with exponential backoff (reduced from 3 for faster fallback)
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse'
          '?lat=$lat&lon=$lng&format=json&zoom=16&addressdetails=1',
        );

        // Increased timeout and better headers for reliability
        final res = await http.get(uri, headers: {
          'User-Agent': 'ResQLink-EmergencyApp/1.0 (contact@resqlink.com)',
          'Accept-Language': 'en-US,en;q=0.9',
          'Accept': 'application/json',
          'Connection': 'keep-alive',
        }).timeout(
            Duration(seconds: 5 + (attempt * 3))); // 5, 8 seconds (faster)

        if (res.statusCode != 200) {
          debugPrint(
              '[reverseGeocode] HTTP ${res.statusCode} for lat=$lat, lon=$lng');
          if (attempt == 1)
            return _offlineReverseGeocode(lat, lng); // Use offline fallback
          await Future.delayed(
              Duration(milliseconds: 300 * (attempt + 1))); // Shorter backoff
          continue;
        }

        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final addr = data['address'] as Map<String, dynamic>? ?? {};

        // Build: "Neighbourhood, City" — most human-readable
        final parts = <String>[];
        for (final key in [
          'road',
          'neighbourhood',
          'suburb',
          'town',
          'village',
          'city_district',
          'city',
        ]) {
          final v = addr[key] as String?;
          if (v != null && v.isNotEmpty) {
            parts.add(v);
            if (parts.length == 2) break;
          }
        }

        if (parts.isNotEmpty) {
          debugPrint('🔍 [reverseGeocode] Online success: ${parts.join(', ')}');
          return parts.join(', ');
        }

        // Fallback: first two segments of display_name
        final display = data['display_name'] as String? ?? '';
        final fallback = display.split(',').take(2).join(',').trim();
        final result =
            fallback.isNotEmpty ? fallback : _offlineReverseGeocode(lat, lng);
        debugPrint('🔍 [reverseGeocode] Online fallback: $result');
        return result;
      } catch (e) {
        debugPrint('[reverseGeocode] Attempt ${attempt + 1} failed: $e');
        if (attempt == 1) {
          // Final fallback - use offline reverse geocoding
          final offlineResult = _offlineReverseGeocode(lat, lng);
          debugPrint(
              '🔍 [reverseGeocode] Using offline fallback: $offlineResult');
          return offlineResult;
        }
        // Wait before retry with exponential backoff
        await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }

    // This should never be reached, but just in case
    return _offlineReverseGeocode(lat, lng);
  }

  // ── Offline reverse geocoding fallback for Karachi area ─────────────────
  static String _offlineReverseGeocode(double lat, double lng) {
    debugPrint(
        '🔍 [reverseGeocode] Using offline fallback for lat=$lat, lng=$lng');

    // Karachi area approximate boundaries
    const double karachiNorth = 25.0;
    const double karachiSouth = 24.8;
    const double karachiEast = 67.4;
    const double karachiWest = 66.9;

    // Check if coordinates are in Karachi area
    if (lat >= karachiSouth &&
        lat <= karachiNorth &&
        lng >= karachiWest &&
        lng <= karachiEast) {
      // Define some known Karachi areas based on approximate coordinates
      final Map<String, List<double>> karachiAreas = {
        'DHA, Karachi': [24.8, 67.1],
        'Clifton, Karachi': [24.81, 67.03],
        'Defence, Karachi': [24.82, 67.08],
        'Gulshan-e-Iqbal, Karachi': [24.93, 67.12],
        'Gulistan-e-Jauhar, Karachi': [24.92, 67.15],
        'North Nazimabad, Karachi': [24.95, 67.05],
        'Nazimabad, Karachi': [24.96, 67.04],
        'Liaquatabad, Karachi': [24.91, 67.03],
        'Gulberg, Karachi': [24.93, 67.03],
        'Jahangeerabad, Karachi': [24.91, 67.03],
        'Saddar, Karachi': [24.86, 67.01],
        'Korangi, Karachi': [24.83, 67.15],
        'Landhi, Karachi': [24.85, 67.18],
        'Malir, Karachi': [24.89, 67.20],
        'Shah Faisal, Karachi': [24.88, 67.18],
        'Federal B Area, Karachi': [24.94, 67.07],
        'North Karachi, Karachi': [24.98, 67.12],
        'Orangi, Karachi': [24.96, 67.08],
        'Baldia, Karachi': [24.94, 67.00],
        'Site, Karachi': [24.87, 67.00],
      };

      // Find the closest known area
      String closestArea = 'Karachi';
      double minDistance = double.infinity;

      for (final entry in karachiAreas.entries) {
        final areaLat = entry.value[0];
        final areaLng = entry.value[1];
        final distance = _km(lat, lng, areaLat, areaLng);

        if (distance < minDistance && distance < 3.0) {
          // Within 3km
          minDistance = distance;
          closestArea = entry.key;
        }
      }

      debugPrint(
          '🔍 [reverseGeocode] Offline result: $closestArea (${minDistance.toStringAsFixed(2)} km)');
      return closestArea;
    }

    // If not in Karachi area, return generic location
    return 'Location (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})';
  }

  static Future<List<Map<String, dynamic>>?> searchNearbyHospitals(
      double lat, double lng, String query) async {
    return _searchNominatim(lat, lng, query);
  }

  // ── Forward geocode: text → suggestions list ──────────────────────────
  static Future<List<Map<String, dynamic>>> searchAddress(String query) async {
    debugPrint('🔍 [searchAddress] Starting search for: "$query"');
    if (query.trim().length < 3) {
      debugPrint('🔍 [searchAddress] Query too short, returning empty');
      return [];
    }

    // Try up to 1 time for online search (faster fallback)
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent("$query, Karachi")}'
        '&format=json'
        '&limit=5'
        '&addressdetails=1'
        '&countrycodes=pk',
      );
      final res = await http.get(uri, headers: {
        'User-Agent': 'ResQLink-EmergencyApp/1.0 (contact@resqlink.com)',
        'Accept-Language': 'en-US,en;q=0.9',
        'Accept': 'application/json',
        'Connection': 'keep-alive',
      }).timeout(const Duration(seconds: 6)); // 6 seconds timeout

      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        final results = list
            .map((item) {
              final display = item['display_name'] as String? ?? '';
              final label = display.split(',').take(3).join(',').trim();
              return {
                'label': label,
                'lat': double.tryParse(item['lat'] as String? ?? '') ?? 0.0,
                'lng': double.tryParse(item['lon'] as String? ?? '') ?? 0.0,
              };
            })
            .where((s) => (s['lat'] as double) != 0.0)
            .toList();

        debugPrint(
            '🔍 [searchAddress] Online success: ${results.length} results');
        return results;
      } else {
        debugPrint('[searchAddress] HTTP ${res.statusCode} for "$query"');
      }
    } catch (e) {
      debugPrint('[searchAddress] Online search failed: $e');
    }

    // Fallback to offline search
    debugPrint('🔍 [searchAddress] Using offline search');
    return _offlineSearchAddress(query);
  }

  // ── Offline address search for Karachi area ─────────────────────────
  static List<Map<String, dynamic>> _offlineSearchAddress(String query) {
    debugPrint('🔍 [searchAddress] Offline search for: "$query"');

    final Map<String, List<double>> karachiLocations = {
      'Jinnah Hospital, Karachi': [24.8695, 67.0599],
      'Civil Hospital, Karachi': [24.8615, 67.0099],
      'Aga Khan Hospital, Karachi': [24.8850, 67.0820],
      'Indus Hospital, Karachi': [24.8900, 67.1700],
      'Liaquat National Hospital, Karachi': [24.8670, 67.0580],
      'DHA, Karachi': [24.8, 67.1],
      'Clifton, Karachi': [24.81, 67.03],
      'Defence, Karachi': [24.82, 67.08],
      'Gulshan-e-Iqbal, Karachi': [24.93, 67.12],
      'Gulistan-e-Jauhar, Karachi': [24.92, 67.15],
      'North Nazimabad, Karachi': [24.95, 67.05],
      'Nazimabad, Karachi': [24.96, 67.04],
      'Liaquatabad, Karachi': [24.91, 67.03],
      'Gulberg, Karachi': [24.93, 67.03],
      'Jahangeerabad, Karachi': [24.91, 67.03],
      'Saddar, Karachi': [24.86, 67.01],
      'Korangi, Karachi': [24.83, 67.15],
      'Landhi, Karachi': [24.85, 67.18],
      'Malir, Karachi': [24.89, 67.20],
      'Shah Faisal, Karachi': [24.88, 67.18],
      'Federal B Area, Karachi': [24.94, 67.07],
      'North Karachi, Karachi': [24.98, 67.12],
      'Orangi, Karachi': [24.96, 67.08],
      'Baldia, Karachi': [24.94, 67.00],
      'Site, Karachi': [24.87, 67.00],
      'Karachi Airport': [24.9065, 67.1608],
      'Karachi University': [24.9340, 67.1120],
      'NED University, Karachi': [24.9316, 67.1121],
      'IBA, Karachi': [24.8541, 67.0689],
    };

    final queryLower = query.toLowerCase();
    final List<Map<String, dynamic>> results = [];

    for (final entry in karachiLocations.entries) {
      if (entry.key.toLowerCase().contains(queryLower)) {
        results.add({
          'label': entry.key,
          'lat': entry.value[0],
          'lng': entry.value[1],
        });
      }
    }

    debugPrint('🔍 [searchAddress] Offline results: ${results.length} matches');
    return results.take(5).toList(); // Limit to 5 results
  }
}
