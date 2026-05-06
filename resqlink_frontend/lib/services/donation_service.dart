// ─────────────────────────────────────────────────────────────────────────────
// services/donation_service.dart — Donor donation history & accepting requests
// ─────────────────────────────────────────────────────────────────────────────
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_models.dart';
import 'package:flutter/foundation.dart';

class DonationService {
  static SupabaseClient get _sb => Supabase.instance.client;

  /// Fetches completed donations for a donor, joined with blood_requests
  static Future<List<DonationRecord>> fetchDonationHistory(
      String donorId) async {
    try {
      final res = await _sb
          .from('donations')
          .select('*, blood_requests(*)')
          .eq('donor_id', donorId)
          .order('created_at', ascending: false);
      return (res as List).map((e) => DonationRecord.fromJson(e)).toList();
    } catch (e) {
      debugPrint('[fetchDonationHistory] error: $e');
      return []; // empty list — shows "No donations yet" instead of fake data
    }
  }

  /// Fetches the stored latitude/longitude for a customer from the
  /// [customer_data] table.  Returns a map with nullable 'latitude' and
  /// 'longitude' doubles, or null when no record exists.
  ///
  /// Used by [_DonationMapWidgetState] as a second-priority location source
  /// (after the coordinates embedded in the [blood_requests] row itself).
  static Future<Map<String, double?>?> fetchCustomerLocation(
      String customerId) async {
    try {
      final res = await _sb
          .from('customer_data')
          .select('latitude, longitude')
          .eq('customer_id', customerId)
          .maybeSingle();

      if (res == null) return null;

      final lat = (res['latitude'] as num?)?.toDouble();
      final lng = (res['longitude'] as num?)?.toDouble();

      // Only return when at least one coordinate is valid
      if (lat == null && lng == null) return null;

      debugPrint('[fetchCustomerLocation] found: lat=$lat, lng=$lng');
      return {'latitude': lat, 'longitude': lng};
    } catch (e) {
      debugPrint('[fetchCustomerLocation] error: $e');
      return null;
    }
  }

  /// Donor accepts a blood request → insert donation row + update request status
  static Future<void> acceptDonationRequest(
      String requestId, String donorId) async {
    final reqId = int.tryParse(requestId);
    if (reqId == null) throw Exception('Invalid request ID: $requestId');

    await _sb.from('donations').insert({
      'request_id': reqId,
      'donor_id': donorId,
      'status': 'accepted',
    });

    await _sb.from('blood_requests').update({
      'status': 'matched',
      'donor_id': donorId,
    }).eq('id', reqId);
  }
}
