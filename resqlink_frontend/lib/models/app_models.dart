// ─────────────────────────────────────────────────────────────────────────────
// models/app_models.dart
// ─────────────────────────────────────────────────────────────────────────────

enum UserRole { customer, donor, driver }

enum RequestStatus { idle, waiting, matched, inProgress, completed, cancelled }

enum RidePhase {
  dispatched,
  enRoute,
  arrivedAtScene,
  enRouteToHospital,
  delivered
}

enum DonationPhase { requested, accepted, inProgress, completed }

class AppUser {
  final String id;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final String? bloodType;
  final String? licenseNumber;
  final String? vehicleType;
  final String? vehiclePlate;
  final String location;
  final String? avatarUrl; // Profile picture URL from Supabase Storage
  bool isAvailable;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.bloodType,
    this.licenseNumber,
    this.vehicleType,
    this.vehiclePlate,
    this.location = 'Karachi, PK',
    this.avatarUrl,
    this.isAvailable = true,
  });

  /// Builds an AppUser from a Supabase 'profiles' row.
  /// All optional fields are safely mapped with null-fallback.
  factory AppUser.fromProfile(
      Map<String, dynamic> data, String authId, String authEmail) {
    final roleStr = data['role'] as String? ?? 'customer';
    final role = UserRole.values.firstWhere(
      (r) => r.name == roleStr,
      orElse: () => UserRole.customer,
    );
    return AppUser(
      id: authId,
      name: data['name'] ?? '',
      email: data['email'] ?? authEmail,
      phone: data['phone'] ?? '',
      role: role,
      bloodType: data['blood_type'],
      licenseNumber: data['license_number'],
      vehicleType: data['vehicle_type'],
      vehiclePlate: data['vehicle_plate'],
      location: data['location'] ?? 'Karachi, PK',
      avatarUrl: data['avatar_url'],
    );
  }

  static AppUser mockDonor() => AppUser(
        id: 'donor-001',
        name: 'Sarah Jenkins',
        email: 'sarah@example.com',
        phone: '+92 300 123 4567',
        role: UserRole.donor,
        bloodType: 'A+',
      );

  static AppUser mockDriver() => AppUser(
        id: 'driver-001',
        name: 'Alex Driver',
        email: 'alex@resqlink.com',
        phone: '+92 300 987 6543',
        role: UserRole.driver,
        licenseNumber: 'DL-12345-XYZ',
        vehicleType: 'Ambulance Type II',
        vehiclePlate: 'AMB-4521',
      );

  static AppUser mockCustomer() => AppUser(
        id: 'cust-001',
        name: 'John Doe',
        email: 'john@example.com',
        phone: '+92 300 000 1234',
        role: UserRole.customer,
        bloodType: 'O+',
      );
}

// ── BloodRequest ──────────────────────────────────────────────────────────────
class BloodRequest {
  final String id;
  final String bloodType;
  final String hospital;
  final String address;
  final int units;
  final String priority; // 'Normal' | 'Urgent'
  final String distance;
  final String urgencyLevel; // 'CRITICAL' | 'URGENT' | 'STANDARD'
  final String? customerId; // customer who created the request
  final double? latitude; // stored in blood_requests (DB source of truth)
  final double? longitude; // stored in blood_requests (DB source of truth)
  RequestStatus status;
  String? matchedDonorName;

  BloodRequest({
    required this.id,
    required this.bloodType,
    required this.hospital,
    required this.address,
    required this.units,
    required this.priority,
    required this.distance,
    required this.urgencyLevel,
    this.customerId,
    this.latitude,
    this.longitude,
    this.status = RequestStatus.idle,
    this.matchedDonorName,
  });

  factory BloodRequest.fromJson(Map<String, dynamic> json) {
    final urgency = json['urgency_level'] as String? ?? 'STANDARD';
    return BloodRequest(
      id: json['id']?.toString() ?? '',
      bloodType: json['blood_type'] ?? '',
      hospital: json['hospital'] ?? '',
      address: json['address'] ?? '',
      units: (json['units'] as num?)?.toInt() ?? 0,
      priority:
          (urgency == 'CRITICAL' || urgency == 'URGENT') ? 'Urgent' : 'Normal',
      distance: json['distance']?.toString() ?? 'N/A',
      urgencyLevel: urgency,
      // ── DB-stored coordinates (preferred over geocoding) ──
      customerId: json['customer_id'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      status: RequestStatus.waiting,
    );
  }

  static List<BloodRequest> mockList() => [
        BloodRequest(
            id: 'RQ-9921',
            bloodType: 'O-',
            hospital: 'ABC Hospital',
            address: '123 Emergency Lane, Central District',
            units: 2,
            priority: 'Urgent',
            distance: '1.2 km',
            urgencyLevel: 'CRITICAL'),
        BloodRequest(
            id: 'RQ-9920',
            bloodType: 'B+',
            hospital: "St. Mary's Clinic",
            address: '456 Health Ave, West Block',
            units: 1,
            priority: 'Urgent',
            distance: '3.7 km',
            urgencyLevel: 'URGENT'),
        BloodRequest(
            id: 'RQ-9918',
            bloodType: 'AB+',
            hospital: 'Unity Health Hub',
            address: '789 Care Blvd, North Wing',
            units: 3,
            priority: 'Normal',
            distance: '5.1 km',
            urgencyLevel: 'STANDARD'),
      ];
}

// ── AmbulanceRequest ──────────────────────────────────────────────────────────
class AmbulanceRequest {
  final String id;
  final String emergencyType;
  final String severity;
  final String address;
  final String? dropLocation; // ← ADD THIS
  final String notes;
  RequestStatus status;
  RidePhase phase;
  String? assignedDriverName;
  String? assignedDriverPhone; // ← ADD THIS (for call button)
  String? eta;

  // Coordinates for map/ETA calculation
  double? pickupLat; // ← ADD THIS
  double? pickupLng; // ← ADD THIS
  double? dropLat; // ← ADD THIS
  double? dropLng; // ← ADD THIS

  AmbulanceRequest({
    required this.id,
    required this.emergencyType,
    required this.severity,
    required this.address,
    this.dropLocation,
    required this.notes,
    this.status = RequestStatus.waiting,
    this.phase = RidePhase.dispatched,
    this.assignedDriverName,
    this.assignedDriverPhone,
    this.eta,
    this.pickupLat,
    this.pickupLng,
    this.dropLat,
    this.dropLng,
  });
}

// ── Trip ──────────────────────────────────────────────────────────────────────
class Trip {
  final String id;
  final String caseId;
  final String from;
  final String to;
  final String duration;
  final String distance;
  final String date;
  final String status;

  const Trip({
    required this.id,
    required this.caseId,
    required this.from,
    required this.to,
    required this.duration,
    required this.distance,
    required this.date,
    required this.status,
  });

  static List<Trip> mockList() => const [
        Trip(
            id: '1',
            caseId: '#8291',
            from: 'Scene — 242 Oak St',
            to: 'ABC Hospital',
            duration: '14m 22s',
            distance: '8.4 km',
            date: 'TODAY',
            status: 'Completed'),
        Trip(
            id: '2',
            caseId: '#8290',
            from: 'Scene — 57 Pine Ave',
            to: 'City General Hospital',
            duration: '9m 05s',
            distance: '5.1 km',
            date: 'YESTERDAY',
            status: 'Completed'),
      ];
}

// ── DonationRecord ────────────────────────────────────────────────────────────
class DonationRecord {
  final String id;
  final String date;
  final String year; // e.g. "2024"
  final String hospital;
  final String type;
  final String time;
  final DateTime completedAtDate;

  const DonationRecord({
    this.id = '',
    required this.date,
    required this.year,
    required this.hospital,
    required this.type,
    required this.time,
    required this.completedAtDate,
  });

  factory DonationRecord.fromJson(Map<String, dynamic> json) {
    final req = json['blood_requests'] as Map? ?? {};
    DateTime completedAt;
    try {
      final raw = json['completed_at'] ?? json['created_at'];
      completedAt = DateTime.parse(raw as String).toLocal();
    } catch (_) {
      completedAt = DateTime.now();
    }
    return DonationRecord(
      id: json['id']?.toString() ?? '',
      date: '${_month(completedAt.month)} ${completedAt.day}',
      year: completedAt.year.toString(),
      time:
          '${completedAt.hour}:${completedAt.minute.toString().padLeft(2, '0')}',
      hospital: req['hospital'] ?? 'Unknown Hospital',
      type: req['blood_type'] ?? 'Blood',
      completedAtDate: completedAt,
    );
  }

  static String _month(int m) {
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
      'DEC'
    ];
    return months[m - 1];
  }

  static List<DonationRecord> mockList() => [
        DonationRecord(
            id: '1',
            date: 'OCT 12',
            year: '2024',
            hospital: 'City General Hospital',
            type: 'Whole Blood',
            time: '10:30',
            completedAtDate: DateTime(2024, 10, 12)),
        DonationRecord(
            id: '2',
            date: 'JUL 05',
            year: '2024',
            hospital: 'Red Cross Center',
            type: 'Plasma',
            time: '14:15',
            completedAtDate: DateTime(2024, 7, 5)),
      ];
}
