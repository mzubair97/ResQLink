// ─────────────────────────────────────────────────────────────────────────────
// services/app_service.dart
// Mock async services. Replace Future.delayed + mock data with Supabase calls.
// All methods return the same shape so the UI layer never needs to change.
// ─────────────────────────────────────────────────────────────────────────────

import '../models/app_models.dart';

class AuthService {
  // Replace with: await supabase.auth.signInWithPassword(email: e, password: p)
  static Future<AppUser> login(String email, String password, UserRole role) async {
    await Future.delayed(const Duration(milliseconds: 800));
    switch (role) {
      case UserRole.donor:    return AppUser.mockDonor();
      case UserRole.driver:   return AppUser.mockDriver();
      case UserRole.customer: return AppUser.mockCustomer();
    }
  }

  // Replace with: await supabase.auth.signUp(...) then insert into profiles
  static Future<AppUser> register(Map<String, dynamic> data, UserRole role) async {
    await Future.delayed(const Duration(seconds: 1));
    switch (role) {
      case UserRole.donor:    return AppUser.mockDonor();
      case UserRole.driver:   return AppUser.mockDriver();
      case UserRole.customer: return AppUser.mockCustomer();
    }
  }

  // Replace with: await supabase.auth.verifyOtp(...)
  static Future<bool> verifyOtp(String phone, String otp) async {
    await Future.delayed(const Duration(milliseconds: 600));
    return otp == '123456'; // mock: any 6-digit code works
  }

  static Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 300));
    // await supabase.auth.signOut();
  }
}

class RequestService {
  // Replace with: supabase.from('blood_requests').select().eq('status','open')
  static Future<List<BloodRequest>> fetchNearbyBloodRequests() async {
    await Future.delayed(const Duration(milliseconds: 600));
    return BloodRequest.mockList();
  }

  // Replace with: supabase.from('blood_requests').insert({...})
  static Future<BloodRequest> submitBloodRequest(Map<String, dynamic> data) async {
    await Future.delayed(const Duration(seconds: 1));
    return BloodRequest(
      id: 'RQ-${DateTime.now().millisecondsSinceEpoch}',
      bloodType: data['bloodType'] ?? 'O+',
      hospital: data['hospital'] ?? '',
      address: data['address'] ?? '',
      units: data['units'] ?? 1,
      priority: data['priority'] ?? 'Normal',
      distance: '—',
      urgencyLevel: data['priority'] == 'Urgent' ? 'URGENT' : 'STANDARD',
      status: RequestStatus.waiting,
    );
  }

  // Replace with: supabase.from('ambulance_requests').insert({...})
  static Future<AmbulanceRequest> submitAmbulanceRequest(Map<String, dynamic> data) async {
    await Future.delayed(const Duration(seconds: 1));
    return AmbulanceRequest(
      id: 'AMB-${DateTime.now().millisecondsSinceEpoch}',
      emergencyType: data['emergencyType'] ?? '',
      severity: data['severity'] ?? 'Medium',
      address: data['address'] ?? '',
      notes: data['notes'] ?? '',
      status: RequestStatus.waiting,
      assignedDriverName: 'Alex Driver',  // mock match
      eta: '8 min',
    );
  }

  // Simulate polling for a match (replace with Supabase realtime subscription)
  static Future<AmbulanceRequest> pollForMatch(String requestId) async {
    await Future.delayed(const Duration(seconds: 3));
    return AmbulanceRequest(
      id: requestId, emergencyType: 'Cardiac Arrest', severity: 'Critical',
      address: '242 Oak Street, Apt 4B', notes: '',
      status: RequestStatus.matched,
      assignedDriverName: 'Alex Driver', eta: '8 min',
    );
  }
}

class TripService {
  // Replace with: supabase.from('trips').select().eq('driver_id', driverId)
  static Future<List<Trip>> fetchTripHistory(String driverId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return Trip.mockList();
  }
}

class DonationService {
  // Replace with: supabase.from('donations').select().eq('donor_id', donorId)
  static Future<List<DonationRecord>> fetchDonationHistory(String donorId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return DonationRecord.mockList();
  }

  // Replace with: supabase.from('blood_requests').update({'status':'accepted'})
  static Future<void> acceptDonationRequest(String requestId, String donorId) async {
    await Future.delayed(const Duration(milliseconds: 700));
  }
}

class ProfileService {
  // Replace with: supabase.from('profiles').update({...}).eq('id', userId)
  static Future<void> updateProfile(String userId, Map<String, dynamic> data) async {
    await Future.delayed(const Duration(milliseconds: 800));
  }
}
