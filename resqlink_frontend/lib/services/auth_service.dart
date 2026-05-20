// services/auth_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import '../models/app_models.dart';
import 'mock_otp_service.dart';
import 'storage_service.dart';

class AuthService {
  static SupabaseClient get _sb => Supabase.instance.client;

  // ── Login ──────────────────────────────────────────────────────────────────
  static Future<AppUser> login(
      String email, String password, UserRole role) async {
    final res =
        await _sb.auth.signInWithPassword(email: email, password: password);
    final user = res.user;
    if (user == null) throw Exception('Login failed');
    final data = await _sb.from('profiles').select().eq('id', user.id).single();
    return AppUser.fromProfile(data, user.id, user.email ?? email);
  }

  // ── Step 1: Create auth account only (no profile yet) ─────────────────────
  static Future<void> register(Map<String, dynamic> data, UserRole role) async {
    final res = await _sb.auth.signUp(
      email: data['email'] as String,
      password: data['password'] as String,
    );
    if (res.user == null) throw Exception('Signup failed');
    // Supabase automatically sends OTP email at this point
  }

  // ── Step 2: Called AFTER OTP verified — insert profile rows ───────────────
  static Future<void> completeRegistration(
      Map<String, dynamic> data, UserRole role) async {
    final user = _sb.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    // Upload profile photo first if provided
    String? avatarUrl;
    if (data['profilePhotoPath'] != null) {
      avatarUrl = await StorageService.uploadAvatarFromPath(
        user.id,
        data['profilePhotoPath'] as String,
      );
    }

    await _sb.from('profiles').insert({
      'id': user.id,
      'name': data['name'],
      'email': data['email'],
      'phone': data['phone'],
      'role': role.name,
      if (avatarUrl != null) 'avatar_url': avatarUrl, // ← saves photo URL
    });

    if (role == UserRole.driver) {
      await _sb.from('drivers').insert({
        'user_id': user.id,
        'license_number': data['license'] ?? '',
        'is_on_duty': false,
      });
    }

    if (role == UserRole.donor) {
      await _sb.from('donor_data').insert({
        'donor_id': user.id,
        'blood_type': data['bloodType'] ?? '',
        'is_available': false,
      });
    }

    if (role == UserRole.customer) {
      await _sb.from('customer_data').insert({
        'customer_id': user.id,
        'address': '',
      });
    }

    final documentPaths =
        (data['documentPaths'] as Map<String, String?>?) ?? const {};
    for (final entry in documentPaths.entries) {
      if (entry.key == 'profile_photo' || entry.value == null) continue;
      await StorageService.uploadDocument(
        userId: user.id,
        role: role.name,
        documentType: entry.key,
        file: File(entry.value!),
      );
    }
  }

  // ── OTP ────────────────────────────────────────────────────────────────────
  static Future<bool> verifyOtp(String email, String otp) =>
      MockOtpService.verifyOtp(email, otp);

  static Future<void> logout() async => _sb.auth.signOut();
}
