// ─────────────────────────────────────────────────────────────────────────────
// models/app_models.dart
// Mock data models — replace field sources with Supabase responses.
// ─────────────────────────────────────────────────────────────────────────────

enum UserRole { customer, donor, driver }

enum RequestStatus { idle, waiting, matched, inProgress, completed, cancelled }

enum RidePhase { dispatched, enRoute, arrivedAtScene, enRouteToHospital, delivered }

enum DonationPhase { requested, accepted, inProgress, completed }

class AppUser {
  final String id;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final String? bloodType;    // donor / customer
  final String? licenseNumber; // driver
  final String? vehicleType;   // driver
  final String? vehiclePlate;  // driver
  final String location;
  bool isAvailable;            // donor / driver

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
    this.location = 'San Francisco, CA',
    this.isAvailable = true,
  });

  /// Simulates what you'd get back from Supabase auth + profile join.
  static AppUser mockDonor() => AppUser(
    id: 'donor-001', name: 'Sarah Jenkins', email: 'sarah@example.com',
    phone: '+1 (555) 123-4567', role: UserRole.donor, bloodType: 'A+',
  );

  static AppUser mockDriver() => AppUser(
    id: 'driver-001', name: 'Alex Driver', email: 'alex@resqlink.com',
    phone: '+1 (555) 987-6543', role: UserRole.driver,
    licenseNumber: 'DL-12345-XYZ', vehicleType: 'Ambulance Type II',
    vehiclePlate: 'AMB-4521',
  );

  static AppUser mockCustomer() => AppUser(
    id: 'cust-001', name: 'John Doe', email: 'john@example.com',
    phone: '+1 (555) 000-1234', role: UserRole.customer, bloodType: 'O+',
  );
}

class BloodRequest {
  final String id;
  final String bloodType;
  final String hospital;
  final String address;
  final int units;
  final String priority;       // 'Normal' | 'Urgent'
  final String distance;
  final String urgencyLevel;   // 'CRITICAL' | 'URGENT' | 'STANDARD'
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
    this.status = RequestStatus.idle,
    this.matchedDonorName,
  });

  static List<BloodRequest> mockList() => [
    BloodRequest(id: 'RQ-9921', bloodType: 'O-', hospital: 'ABC Hospital',
      address: '123 Emergency Lane, Central District', units: 2,
      priority: 'Urgent', distance: '1.2 km', urgencyLevel: 'CRITICAL'),
    BloodRequest(id: 'RQ-9920', bloodType: 'B+', hospital: "St. Mary's Clinic",
      address: '456 Health Ave, West Block', units: 1,
      priority: 'Urgent', distance: '3.7 km', urgencyLevel: 'URGENT'),
    BloodRequest(id: 'RQ-9918', bloodType: 'AB+', hospital: 'Unity Health Hub',
      address: '789 Care Blvd, North Wing', units: 3,
      priority: 'Normal', distance: '5.1 km', urgencyLevel: 'STANDARD'),
  ];
}

class AmbulanceRequest {
  final String id;
  final String emergencyType;
  final String severity;
  final String address;
  final String notes;
  RequestStatus status;
  RidePhase phase;
  String? assignedDriverName;
  String? eta;

  AmbulanceRequest({
    required this.id,
    required this.emergencyType,
    required this.severity,
    required this.address,
    required this.notes,
    this.status = RequestStatus.waiting,
    this.phase = RidePhase.dispatched,
    this.assignedDriverName,
    this.eta,
  });
}

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
    Trip(id: '1', caseId: '#8291', from: 'Scene — 242 Oak St',
      to: 'ABC Hospital', duration: '14m 22s', distance: '8.4 km',
      date: 'TODAY', status: 'Completed'),
    Trip(id: '2', caseId: '#8290', from: 'Scene — 57 Pine Ave',
      to: 'City General Hospital', duration: '9m 05s', distance: '5.1 km',
      date: 'YESTERDAY', status: 'Completed'),
    Trip(id: '3', caseId: '#8288', from: 'Scene — 890 Elm Blvd',
      to: "St. Mary's Clinic", duration: '22m 11s', distance: '12.3 km',
      date: 'APR 10', status: 'Completed'),
    Trip(id: '4', caseId: '#8285', from: 'Scene — 34 Maple Rd',
      to: 'Unity Medical Center', duration: '6m 48s', distance: '3.7 km',
      date: 'APR 09', status: 'Completed'),
  ];
}

class DonationRecord {
  final String id;
  final String date;
  final String hospital;
  final String type;
  final String time;

  const DonationRecord({
    required this.id, required this.date, required this.hospital,
    required this.type, required this.time,
  });

  static List<DonationRecord> mockList() => const [
    DonationRecord(id: '1', date: 'OCT 12', hospital: 'City General Hospital', type: 'Whole Blood', time: '10:30 AM'),
    DonationRecord(id: '2', date: 'JUL 05', hospital: 'Red Cross Center',      type: 'Plasma',      time: '02:15 PM'),
    DonationRecord(id: '3', date: 'MAR 15', hospital: "St. Mary's Clinic",     type: 'Whole Blood', time: '09:00 AM'),
    DonationRecord(id: '4', date: 'DEC 20', hospital: 'Unity Health Hub',      type: 'Whole Blood', time: '11:45 AM'),
  ];
}
