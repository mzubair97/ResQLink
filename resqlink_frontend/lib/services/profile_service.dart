// ─────────────────────────────────────────────────────────────────────────────
// services/profile_service.dart — User profile fetch & updates
// ─────────────────────────────────────────────────────────────────────────────
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  static SupabaseClient get _sb => Supabase.instance.client;

  // ── Fetch ──────────────────────────────────────────────────────────────────

  /// Fetches the full profile row for [userId] from the 'profiles' table.
  static Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    try {
      return await _sb.from('profiles').select().eq('id', userId).single();
    } catch (_) {
      return null;
    }
  }

  // ── Update ─────────────────────────────────────────────────────────────────

  /// Updates the profiles row for [userId] with the given [data] map.
  /// Only non-null fields in [data] are sent.
  static Future<void> updateProfile(
      String userId, Map<String, dynamic> data) async {
    await _sb.from('profiles').update(data).eq('id', userId);
  }

  // ── Convenience helpers ────────────────────────────────────────────────────

  /// Convenience: update basic profile fields (name, phone, location).
  static Future<void> updateBasicProfile({
    required String userId,
    required String name,
    required String phone,
    required String location,
  }) async {
    await updateProfile(userId, {
      'name': name,
      'phone': phone,
      'location': location,
    });
  }

  /// Update driver-specific profile fields.
  static Future<void> updateDriverProfile({
    required String userId,
    required String name,
    required String phone,
    required String location,
    String? licenseNumber,
    String? vehicleType,
    String? vehiclePlate,
  }) async {
    await updateProfile(userId, {
      'name': name,
      'phone': phone,
      'location': location,
      if (licenseNumber != null) 'license_number': licenseNumber,
      if (vehicleType != null) 'vehicle_type': vehicleType,
      if (vehiclePlate != null) 'vehicle_plate': vehiclePlate,
    });
  }

  // ── Fetch last donation ────────────────────────────────────────────────────

  /// Returns the most recent donation record for [donorId], or null if none.
  static Future<Map<String, dynamic>?> fetchLastDonation(String donorId) async {
    try {
      final res = await _sb
          .from('donations')
          .select('*, blood_requests(hospital, blood_type)')
          .eq('donor_id', donorId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return res;
    } catch (_) {
      return null;
    }
  }

  // ── Fetch real blood request counts ───────────────────────────────────────

  /// Returns the count of pending blood requests (for donor home stats).
  static Future<int> fetchPendingBloodRequestCount() async {
    try {
      final res = await _sb.from('blood_requests').select().inFilter(
          'urgency_level', ['URGENT', 'CRITICAL']).eq('status', 'pending');
      return (res as List).length;
    } catch (_) {
      return 0;
    }
  }
}
