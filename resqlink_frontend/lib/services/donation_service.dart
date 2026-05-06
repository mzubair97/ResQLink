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
