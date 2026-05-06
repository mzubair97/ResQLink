// services/mock_otp_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';

class MockOtpService {
  static SupabaseClient get _sb => Supabase.instance.client;
  static const int resendCooldownSeconds = 30;
  static DateTime? _lastSentAt;

  /// Resend OTP email to [email]
  static Future<bool> sendOtp(String email) async {
    if (_lastSentAt != null) {
      final elapsed = DateTime.now().difference(_lastSentAt!).inSeconds;
      if (elapsed < resendCooldownSeconds) {
        throw 'Please wait ${resendCooldownSeconds - elapsed}s before resending';
      }
    }
    await _sb.auth.resend(type: OtpType.signup, email: email);
    _lastSentAt = DateTime.now();
    return true;
  }

  /// Verify the 6-digit code the user typed
  static Future<bool> verifyOtp(String email, String code) async {
    try {
      final res = await _sb.auth.verifyOTP(
        email: email,
        token: code,
        type: OtpType.signup,
      );
      return res.user != null;
    } catch (_) {
      return false;
    }
  }

  static int resendCooldownRemaining() {
    if (_lastSentAt == null) return 0;
    final elapsed = DateTime.now().difference(_lastSentAt!).inSeconds;
    final remaining = resendCooldownSeconds - elapsed;
    return remaining > 0 ? remaining : 0;
  }
}
