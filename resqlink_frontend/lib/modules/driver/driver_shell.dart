// ─────────────────────────────────────────────────────────────────────────────
// modules/driver/ — DriverShell (IndexedStack) + complete ride flow
// Tabs: Home | Live Map (ride flow) | Trips | Profile
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../models/app_models.dart';
import '../../services/app_service.dart';
import '../auth/auth_screens.dart';

// ══════════════════════════════════════════════════════════════════════════════
// DRIVER SHELL
// ══════════════════════════════════════════════════════════════════════════════

class DriverShell extends StatefulWidget {
  const DriverShell({super.key});
  @override State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  int _index = 0;
  final _user = AppUser.mockDriver();

  void _goTab(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    body: IndexedStack(index: _index, children: [
      DriverHomeTab(user: _user, onDispatch: () => _goTab(1)),
      DriverRideFlow(user: _user, onComplete: () => _goTab(2)),
      DriverTripsTab(user: _user),
      DriverProfileTab(user: _user),
    ]),
    bottomNavigationBar: ResQBottomNav(
      currentIndex: _index, onTap: _goTab,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_rounded),           label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.map_rounded),             label: 'Live Map'),
        BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded),   label: 'Trips'),
        BottomNavigationBarItem(icon: Icon(Icons.person_rounded),          label: 'Profile'),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// HOME TAB
// ══════════════════════════════════════════════════════════════════════════════

class DriverHomeTab extends StatefulWidget {
  final AppUser user;
  final VoidCallback onDispatch;
  const DriverHomeTab({super.key, required this.user, required this.onDispatch});
  @override State<DriverHomeTab> createState() => _DriverHomeTabState();
}

class _DriverHomeTabState extends State<DriverHomeTab> {
  bool _onDuty = true;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(automaticallyImplyLeading: false,
        title: Text('Driver Portal', style: AppTextStyles.heading(18)),
        actions: [Padding(padding: const EdgeInsets.only(right: 12),
          child: Container(width: 38, height: 38,
              decoration: const BoxDecoration(color: AppColors.white08, shape: BoxShape.circle),
              child: const Icon(Icons.person_rounded, size: 20)))]),
    body: SingleChildScrollView(padding: const EdgeInsets.only(bottom: 24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Driver card
      Container(margin: const EdgeInsets.fromLTRB(20, 12, 20, 14), padding: const EdgeInsets.all(16), decoration: AppDecorations.card,
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.user.name, style: AppTextStyles.bodyMedium(size: 16), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text('License: ${widget.user.licenseNumber ?? "—"}', style: AppTextStyles.body(size: 12, color: AppColors.red), overflow: TextOverflow.ellipsis),
          ])),
          Switch(value: _onDuty, onChanged: (v) => setState(() => _onDuty = v)),
          const SizedBox(width: 8),
          AnimatedContainer(duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: _onDuty ? AppColors.green.withOpacity(0.15) : AppColors.white08, borderRadius: BorderRadius.circular(20)),
            child: Text(_onDuty ? 'ON DUTY' : 'OFF DUTY', style: AppTextStyles.bodyMedium(size: 11, color: _onDuty ? AppColors.green : AppColors.white40))),
        ])),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: const [
        StatCard(label: 'TRIPS TODAY', value: '04'),
        SizedBox(width: 12),
        StatCard(label: 'KM COVERED', value: '42'),
      ])),
      const SizedBox(height: 14),
      // Dispatch alert
      Container(margin: const EdgeInsets.symmetric(horizontal: 20), padding: const EdgeInsets.all(14), decoration: AppDecorations.alertBox, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.local_shipping_rounded, color: AppColors.red, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text('New dispatch request nearby', style: AppTextStyles.bodyMedium(size: 13), overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 6),
        Text('242 Oak Street, Apt 4B — 2.4 miles', style: AppTextStyles.body(size: 12, color: AppColors.white70), overflow: TextOverflow.ellipsis),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: ElevatedButton(onPressed: widget.onDispatch, style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(42)), child: const Text('Accept & Navigate'))),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton(onPressed: () {}, style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(42)), child: const Text('Decline'))),
        ]),
      ])),
      const SizedBox(height: 20),
      SectionHeader(title: 'RECENT TRIPS', actionLabel: 'See all', onAction: () {}),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Column(children: const [
        _TripPreviewTile(date: 'TODAY', route: 'Scene → ABC Hospital', meta: '14m 22s  •  8.4 km', caseId: '#8291'),
        SizedBox(height: 10),
        _TripPreviewTile(date: 'APR 11', route: 'Scene → City General', meta: '9m 05s  •  5.1 km', caseId: '#8290'),
      ])),
    ])),
  );
}

class _TripPreviewTile extends StatelessWidget {
  final String date, route, meta, caseId;
  const _TripPreviewTile({required this.date, required this.route, required this.meta, required this.caseId});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.white08)),
    child: Row(children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6), decoration: BoxDecoration(color: AppColors.redDim, borderRadius: BorderRadius.circular(7)),
          child: Text(date, style: AppTextStyles.bodyMedium(size: 10, color: AppColors.red))),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(route, style: AppTextStyles.bodyMedium(size: 12), overflow: TextOverflow.ellipsis),
        Text(meta,  style: AppTextStyles.body(size: 11, color: AppColors.white40)),
      ])),
      Text(caseId, style: AppTextStyles.body(size: 10, color: AppColors.white40)),
      const SizedBox(width: 4),
      const Icon(Icons.chevron_right, color: AppColors.white40, size: 16),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// RIDE FLOW  — multi-phase map screen within the Live Map tab
// Phases: dispatched → enRoute → arrivedAtScene → enRouteToHospital → delivered
// ══════════════════════════════════════════════════════════════════════════════

class DriverRideFlow extends StatefulWidget {
  final AppUser user;
  final VoidCallback onComplete;
  const DriverRideFlow({super.key, required this.user, required this.onComplete});
  @override State<DriverRideFlow> createState() => _DriverRideFlowState();
}

class _DriverRideFlowState extends State<DriverRideFlow> {
  RidePhase _phase = RidePhase.dispatched;
  bool _showSummary = false;

  String get _phaseLabel {
    switch (_phase) {
      case RidePhase.dispatched:         return 'DISPATCH RECEIVED';
      case RidePhase.enRoute:            return 'EN ROUTE TO SCENE';
      case RidePhase.arrivedAtScene:     return 'ARRIVED AT SCENE';
      case RidePhase.enRouteToHospital:  return 'EN ROUTE TO HOSPITAL';
      case RidePhase.delivered:          return 'DELIVERED';
    }
  }

  String get _btnLabel {
    switch (_phase) {
      case RidePhase.dispatched:         return 'Start Navigation';
      case RidePhase.enRoute:            return 'Arrived at Scene';
      case RidePhase.arrivedAtScene:     return 'Pickup Patient — Start Ride';
      case RidePhase.enRouteToHospital:  return 'Mark Delivered';
      case RidePhase.delivered:          return 'View Trip Summary';
    }
  }

  IconData get _btnIcon {
    switch (_phase) {
      case RidePhase.dispatched:         return Icons.navigation_rounded;
      case RidePhase.enRoute:            return Icons.where_to_vote_outlined;
      case RidePhase.arrivedAtScene:     return Icons.person_pin_circle_rounded;
      case RidePhase.enRouteToHospital:  return Icons.local_hospital_rounded;
      case RidePhase.delivered:          return Icons.receipt_long_rounded;
    }
  }

  void _advance() {
    if (_phase == RidePhase.delivered) { setState(() => _showSummary = true); return; }
    setState(() => _phase = RidePhase.values[_phase.index + 1]);
  }

  void _resetPhase() => setState(() { _phase = RidePhase.dispatched; _showSummary = false; });

  @override
  Widget build(BuildContext context) {
    if (_showSummary) return _summaryScreen();
    return Scaffold(
      body: Stack(children: [
        // Map
        SizedBox.expand(child: CustomPaint(painter: const MapGridPainter(opacity: 0.1))),
        // Route visualization
        Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(_phase == RidePhase.enRouteToHospital ? Icons.local_hospital_rounded : Icons.local_shipping_rounded,
              color: AppColors.red, size: 44),
          const SizedBox(height: 6),
          Text('Live tracking active', style: AppTextStyles.body(size: 12, color: AppColors.white70)),
        ])),
        // Top ETA card
        Positioned(top: MediaQuery.of(context).padding.top + 12, left: 20, right: 20,
          child: Container(padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFF2D2222), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.white08)),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.emergency, color: AppColors.white, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('ARRIVAL TIME', style: AppTextStyles.label(color: AppColors.white40)),
                Text('14:22', style: AppTextStyles.heading(20)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('ETA', style: AppTextStyles.label(color: AppColors.white40)),
                Text('8 MIN', style: AppTextStyles.heading(18, color: AppColors.red)),
              ]),
            ]))),
        // Phase badge
        Positioned(top: MediaQuery.of(context).padding.top + 104, left: 0, right: 0,
          child: Center(child: AnimatedSwitcher(duration: const Duration(milliseconds: 280),
            child: Container(key: ValueKey(_phaseLabel),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(color: AppColors.redDim, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.redMid)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle)),
                const SizedBox(width: 7),
                Text(_phaseLabel, style: AppTextStyles.label(color: AppColors.red)),
              ]))))),
        // Bottom sheet
        Align(alignment: Alignment.bottomCenter,
          child: Container(width: double.infinity, padding: EdgeInsets.fromLTRB(22, 14, 22, MediaQuery.of(context).padding.bottom + 16),
            decoration: const BoxDecoration(color: Color(0xFF1A1212), borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.white15, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 14),
              Text('• SEVERITY: CRITICAL', style: AppTextStyles.label(color: AppColors.red)),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('242 Oak Street, Apt 4B', style: AppTextStyles.heading(17), overflow: TextOverflow.ellipsis),
                  Text('San Francisco, CA 94102', style: AppTextStyles.body(size: 12, color: AppColors.white40)),
                ])),
                Container(width: 40, height: 40, decoration: const BoxDecoration(color: AppColors.white08, shape: BoxShape.circle),
                    child: const Icon(Icons.phone_outlined, size: 18)),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                _infoPill('DISTANCE', '2.4 mi'),
                const SizedBox(width: 10),
                _infoPill('TRAFFIC', 'Light', color: AppColors.green),
              ]),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: _advance,
                icon: Icon(_btnIcon, size: 20),
                label: Text(_btnLabel, style: AppTextStyles.bodyMedium(size: 14))),
            ]))),
      ]),
    );
  }

  Widget _infoPill(String label, String value, {Color color = AppColors.white}) => Expanded(
    child: Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: AppColors.white08, borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppTextStyles.label()),
        const SizedBox(height: 3),
        Text(value, style: AppTextStyles.heading(16, color: color)),
      ])));

  // ── Summary ──────────────────────────────────────────────────────────────────
  Widget _summaryScreen() => Scaffold(
    appBar: ResQAppBar(title: 'Trip Summary', onBack: () {}),
    body: Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Column(children: [
      const SizedBox(height: 20),
      Stack(alignment: Alignment.center, children: [
        Container(width: 110, height: 110, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.redMid, width: 1.5))),
        Container(width: 88, height: 88, decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: AppColors.white, size: 48)),
      ]),
      const SizedBox(height: 22),
      Text('Emergency Transport\nCompleted', textAlign: TextAlign.center, style: AppTextStyles.heading(24)),
      const SizedBox(height: 8),
      Text('Mission Successful  •  Case #8291', style: AppTextStyles.body(size: 13, color: AppColors.white40)),
      const SizedBox(height: 28),
      Row(children: [
        _statBox('TIME TAKEN', '14m 22s'),
        const SizedBox(width: 14),
        _statBox('DISTANCE', '8.4 km'),
      ]),
      const SizedBox(height: 20),
      Container(height: 140, decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.white08)),
        child: Stack(children: [
          ClipRRect(borderRadius: BorderRadius.circular(16), child: CustomPaint(size: const Size(double.infinity, 140), painter: const _SummaryMapPainter())),
          Positioned(top: 10, right: 10, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: AppColors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(7), border: Border.all(color: AppColors.green.withOpacity(0.3))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 11), const SizedBox(width: 4),
                Text('Route complete', style: AppTextStyles.body(size: 10, color: AppColors.green)),
              ]))),
          const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.local_hospital_rounded, color: AppColors.red, size: 26),
            SizedBox(height: 3),
            Text('ABC Hospital', style: TextStyle(color: AppColors.white, fontSize: 11, fontWeight: FontWeight.w600)),
          ])),
        ])),
      const Spacer(),
      ElevatedButton(
        onPressed: () { _resetPhase(); widget.onComplete(); },
        child: Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.wifi_tethering_rounded, size: 18), SizedBox(width: 8), Text('Go Back Online')])),
      TextButton(onPressed: () {},
          child: Text('VIEW FULL TRIP LOGS', style: AppTextStyles.label(color: AppColors.white40).copyWith(fontSize: 10))),
      const SizedBox(height: 16),
    ])),
  );

  Widget _statBox(String label, String value) => Expanded(
    child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.red.withOpacity(0.3)), color: AppColors.redDim),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppTextStyles.label()),
        const SizedBox(height: 5),
        Text(value, style: AppTextStyles.heading(22, color: AppColors.red)),
      ])));
}

// ── Summary map painter ──────────────────────────────────────────────────────
class _SummaryMapPainter extends CustomPainter {
  const _SummaryMapPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF111111));
    final road = Paint()..color = const Color(0xFF1E1E1E)..strokeWidth = 18..strokeCap = StrokeCap.round;
    final grid = Paint()..color = AppColors.red.withOpacity(0.05)..strokeWidth = 0.5;
    const step = 26.0;
    for (double x = 0; x < size.width; x += step) canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    for (double y = 0; y < size.height; y += step) canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    canvas.drawLine(Offset(size.width * 0.3, 0), Offset(size.width * 0.4, size.height), road);
    canvas.drawLine(Offset(0, size.height * 0.5), Offset(size.width, size.height * 0.55), road);
    final route = Paint()..color = AppColors.green.withOpacity(0.6)..strokeWidth = 3..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(size.width * 0.15, size.height * 0.8)..lineTo(size.width * 0.4, size.height * 0.8)
      ..lineTo(size.width * 0.4, size.height * 0.55)..lineTo(size.width * 0.72, size.height * 0.55)
      ..lineTo(size.width * 0.72, size.height * 0.22);
    canvas.drawPath(path, route);
    canvas.drawCircle(Offset(size.width * 0.15, size.height * 0.8), 5, Paint()..color = AppColors.white40);
    canvas.drawCircle(Offset(size.width * 0.72, size.height * 0.22), 5, Paint()..color = AppColors.red);
  }
  @override bool shouldRepaint(covariant CustomPainter old) => false;
}

// ══════════════════════════════════════════════════════════════════════════════
// TRIPS TAB
// ══════════════════════════════════════════════════════════════════════════════

class DriverTripsTab extends StatelessWidget {
  final AppUser user;
  const DriverTripsTab({super.key, required this.user});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const ResQAppBar(title: 'Trip History', showBack: false),
    body: FutureBuilder<List<Trip>>(
      future: TripService.fetchTripHistory(user.id),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.red, strokeWidth: 2));
        }
        final trips = snap.data ?? Trip.mockList();
        return Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 14), child: Row(children: const [
            StatCard(label: 'TOTAL TRIPS',    value: '04'),
            SizedBox(width: 10),
            StatCard(label: 'KM THIS WEEK',   value: '29.5'),
            SizedBox(width: 10),
            StatCard(label: 'AVG TIME',       value: '13m'),
          ])),
          Expanded(child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            itemCount: trips.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _TripTile(trip: trips[i]),
          )),
        ]);
      },
    ),
  );
}

class _TripTile extends StatelessWidget {
  final Trip trip;
  const _TripTile({required this.trip});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.white08)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: AppColors.redDim, borderRadius: BorderRadius.circular(7)),
            child: Text(trip.date, style: AppTextStyles.bodyMedium(size: 10, color: AppColors.red))),
        const SizedBox(width: 8),
        Text(trip.caseId, style: AppTextStyles.body(size: 11, color: AppColors.white40)),
        const Spacer(),
        Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(color: AppColors.green.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.check_circle_rounded, size: 10, color: AppColors.green), const SizedBox(width: 3),
              Text(trip.status, style: AppTextStyles.body(size: 10, color: AppColors.green)),
            ])),
      ]),
      const SizedBox(height: 10),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.white40, shape: BoxShape.circle)),
          Container(width: 1, height: 22, color: AppColors.white15),
          Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle)),
        ]),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(trip.from, style: AppTextStyles.body(size: 12, color: AppColors.white70), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12),
          Text(trip.to,   style: AppTextStyles.bodyMedium(size: 12), overflow: TextOverflow.ellipsis),
        ])),
      ]),
      const SizedBox(height: 10),
      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: AppColors.white08, borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          const Icon(Icons.timer_outlined, size: 13, color: AppColors.white40), const SizedBox(width: 4),
          Text(trip.duration, style: AppTextStyles.body(size: 11, color: AppColors.white70)),
          const SizedBox(width: 14),
          const Icon(Icons.straighten_rounded, size: 13, color: AppColors.white40), const SizedBox(width: 4),
          Text(trip.distance, style: AppTextStyles.body(size: 11, color: AppColors.white70)),
          const Spacer(),
          Text('View Summary →', style: AppTextStyles.body(size: 10, color: AppColors.red)),
        ])),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// PROFILE TAB
// ══════════════════════════════════════════════════════════════════════════════

class DriverProfileTab extends StatefulWidget {
  final AppUser user;
  const DriverProfileTab({super.key, required this.user});
  @override State<DriverProfileTab> createState() => _DriverProfileTabState();
}

class _DriverProfileTabState extends State<DriverProfileTab> {
  bool _onDuty = true, _loading = false;
  String _vehicleType = 'Ambulance Type II';
  static const _vehicleTypes = ['Ambulance Type I','Ambulance Type II','Ambulance Type III','Mobile ICU','Patient Transport'];

  final _nameCtrl     = TextEditingController(text: 'Alex Driver');
  final _phoneCtrl    = TextEditingController(text: '+1 (555) 987-6543');
  final _emailCtrl    = TextEditingController(text: 'alex@resqlink.com');
  final _licenseCtrl  = TextEditingController(text: 'DL-12345-XYZ');
  final _expiryCtrl   = TextEditingController(text: 'Dec 2026');
  final _plateCtrl    = TextEditingController(text: 'AMB-4521');
  final _locationCtrl = TextEditingController(text: 'Central District Station');

  @override
  void dispose() {
    for (final c in [_nameCtrl, _phoneCtrl, _emailCtrl, _licenseCtrl, _expiryCtrl, _plateCtrl, _locationCtrl]) c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    await ProfileService.updateProfile(widget.user.id, {'name': _nameCtrl.text});
    if (mounted) { setState(() => _loading = false); showSuccessSnack(context, 'Profile updated!'); }
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (mounted) Navigator.pushAndRemoveUntil(context, fadeRoute(const RoleSelectionScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const ResQAppBar(title: 'My Profile', showBack: false),
    body: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 24), child: Column(children: [
      const SizedBox(height: 20),
      Stack(alignment: Alignment.bottomRight, children: [
        Container(padding: const EdgeInsets.all(3), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.red, width: 2)),
            child: const CircleAvatar(radius: 46, backgroundColor: AppColors.surface2, child: Icon(Icons.person_rounded, color: AppColors.white40, size: 42))),
        Container(padding: const EdgeInsets.all(7), decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle),
            child: const Icon(Icons.camera_alt, size: 15, color: AppColors.white)),
      ]),
      const SizedBox(height: 8),
      Text('Change Photo', style: AppTextStyles.body(size: 12, color: AppColors.red)),
      const SizedBox(height: 20),
      // Duty toggle
      Container(padding: const EdgeInsets.all(13), decoration: AppDecorations.cardSmall, child: Row(children: [
        const Icon(Icons.local_shipping_rounded, color: AppColors.red, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('On Duty Status', style: AppTextStyles.bodyMedium(size: 13)),
          Text(_onDuty ? 'Accepting dispatch requests' : 'Not accepting requests',
              style: AppTextStyles.body(size: 11, color: AppColors.white40)),
        ])),
        Switch(value: _onDuty, onChanged: (v) => setState(() => _onDuty = v)),
      ])),
      const SizedBox(height: 16),
      ProfileField(label: 'FULL NAME', hint: 'Name', controller: _nameCtrl),
      const SizedBox(height: 12),
      ProfileField(label: 'PHONE', hint: 'Phone', controller: _phoneCtrl, prefixIcon: Icons.phone_outlined, keyboardType: TextInputType.phone),
      const SizedBox(height: 12),
      ProfileField(label: 'EMAIL', hint: 'Email', controller: _emailCtrl, prefixIcon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
      const SizedBox(height: 16),
      Align(alignment: Alignment.centerLeft, child: Text('DRIVER CREDENTIALS', style: AppTextStyles.label(color: AppColors.red))),
      const SizedBox(height: 10),
      ProfileField(label: 'LICENSE NUMBER', hint: 'DL-12345-XYZ', controller: _licenseCtrl, prefixIcon: Icons.badge_outlined),
      const SizedBox(height: 12),
      ProfileField(label: 'LICENSE EXPIRY',  hint: 'Dec 2026',     controller: _expiryCtrl,  prefixIcon: Icons.calendar_today_outlined),
      const SizedBox(height: 12),
      Align(alignment: Alignment.centerLeft, child: Text('VEHICLE TYPE', style: AppTextStyles.label())),
      const SizedBox(height: 8),
      Container(padding: const EdgeInsets.symmetric(horizontal: 14), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.white08)),
        child: DropdownButtonHideUnderline(child: DropdownButton<String>(
          isExpanded: true, dropdownColor: AppColors.surface2, value: _vehicleType,
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.white40),
          items: _vehicleTypes.map((v) => DropdownMenuItem(value: v, child: Text(v, style: AppTextStyles.body(size: 13)))).toList(),
          onChanged: (v) => setState(() => _vehicleType = v!),
        ))),
      const SizedBox(height: 12),
      ProfileField(label: 'VEHICLE PLATE', hint: 'AMB-4521', controller: _plateCtrl, prefixIcon: Icons.directions_car_outlined),
      const SizedBox(height: 12),
      ProfileField(label: 'BASE LOCATION', hint: 'Station', controller: _locationCtrl, prefixIcon: Icons.location_on_outlined, suffixIcon: Icons.my_location),
      const SizedBox(height: 16),
      // Certifications
      Container(padding: const EdgeInsets.all(13), decoration: AppDecorations.cardSmall, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.verified_rounded, color: AppColors.green, size: 16), const SizedBox(width: 7), Text('CERTIFICATIONS', style: AppTextStyles.label(color: AppColors.green))]),
        const SizedBox(height: 10),
        _certRow('EMT Basic', true),
        const SizedBox(height: 5),
        _certRow('Advanced Life Support', true),
        const SizedBox(height: 5),
        _certRow('Hazmat Level I', false),
      ])),
      const SizedBox(height: 28),
      ElevatedButton(onPressed: _loading ? null : _save,
          style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
          child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save Changes')),
      const SizedBox(height: 12),
      TextButton.icon(onPressed: _logout, icon: const Icon(Icons.logout, color: AppColors.red, size: 18),
          label: Text('Sign Out', style: AppTextStyles.bodyMedium(size: 14, color: AppColors.red))),
      const SizedBox(height: 32),
    ])),
  );

  Widget _certRow(String label, bool ok) => Row(children: [
    Icon(ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked, size: 15, color: ok ? AppColors.green : AppColors.white40),
    const SizedBox(width: 8),
    Expanded(child: Text(label, style: AppTextStyles.body(size: 12, color: ok ? AppColors.white70 : AppColors.white40))),
  ]);
}
