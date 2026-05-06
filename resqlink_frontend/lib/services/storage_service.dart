// ─────────────────────────────────────────────────────────────────────────────
// services/storage_service.dart
// Supabase Storage upload helpers for profile images and blood-proof documents.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  static SupabaseClient get _sb => Supabase.instance.client;

  // ── Buckets ────────────────────────────────────────────────────────────────
  static const _avatarBucket = 'avatars';
  static const _proofBucket = 'blood-proofs';

  // ── Profile avatar ─────────────────────────────────────────────────────────

  /// Upload [file] as the profile avatar for [userId].
  /// Returns the public URL of the uploaded image.
  static Future<String> uploadAvatar(String userId, File file) async {
    final ext = file.path.split('.').last.toLowerCase();
    final path = '$userId/avatar.$ext';

    await _sb.storage
        .from(_avatarBucket)
        .upload(path, file, fileOptions: const FileOptions(upsert: true));

    final url = _sb.storage.from(_avatarBucket).getPublicUrl(path);

    // Save to profiles table
    await _sb.from('profiles').update({'avatar_url': url}).eq('id', userId);

    return url;
  }

  /// Upload profile photo and save to profiles table avatar_url
  static Future<String> uploadAvatarFromPath(
      String userId, String filePath) async {
    final file = File(filePath);
    final ext = filePath.split('.').last.toLowerCase();
    final path = '$userId/avatar.$ext';

    await _sb.storage.from(_avatarBucket).upload(
          path,
          file,
          fileOptions: const FileOptions(upsert: true),
        );

    final url = _sb.storage.from(_avatarBucket).getPublicUrl(path);
    return url;
  }
  // ── Blood group proof ──────────────────────────────────────────────────────

  /// Upload [file] as the blood-group proof document for [userId].
  /// Returns the public URL of the uploaded document.
  static Future<String> uploadBloodProof(String userId, File file) async {
    final ext = file.path.split('.').last.toLowerCase();
    final path = '$userId/blood_proof.$ext';

    await _sb.storage.from(_proofBucket).upload(
          path,
          file,
          fileOptions: const FileOptions(upsert: true),
        );

    final url = _sb.storage.from(_proofBucket).getPublicUrl(path);

    // Persist URL to profiles table for admin review
    await _sb
        .from('profiles')
        .update({'blood_proof_url': url}).eq('id', userId);

    return url;
  }

  // ── Document upload (for all roles) ──────────────────────────────────────

  /// Upload a document file for any role and save record to DB.
  /// [role] = 'donor' | 'customer' | 'driver'
  /// [documentType] = 'government_id' | 'medical_certificate' etc.
  static Future<String> uploadDocument({
    required String userId,
    required String role,
    required String documentType,
    required File file,
  }) async {
    final bucket = '$role-documents';
    final ext = file.path.split('.').last.toLowerCase();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = '$userId/${documentType}_$timestamp.$ext';
    final fileName = file.path.split('/').last;

    // Upload to storage
    await _sb.storage
        .from(bucket)
        .upload(path, file, fileOptions: const FileOptions(upsert: true));

    // Get signed URL (since bucket is private)
    final signedUrl = await _sb.storage
        .from(bucket)
        .createSignedUrl(path, 60 * 60 * 24 * 365); // 1 year

    // Save record to the correct documents table
    final table = '${role}_documents';
    final idColumn = '${role}_id';

    await _sb.from(table).insert({
      idColumn: userId,
      'document_type': documentType,
      'file_url': signedUrl,
      'file_name': fileName,
    });

    return signedUrl;
  }

  /// Fetch all documents for a user from their role's documents table.
  static Future<List<Map<String, dynamic>>> fetchDocuments({
    required String userId,
    required String role,
  }) async {
    try {
      final table = '${role}_documents';
      final idColumn = '${role}_id';
      final res = await _sb
          .from(table)
          .select()
          .eq(idColumn, userId)
          .order('uploaded_at', ascending: false);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (_) {
      return [];
    }
  }
}
