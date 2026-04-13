// ─────────────────────────────────────────────────────────────────────────────
// modules/donor/ — DonorShell (IndexedStack hub) + all screens/flows
// Tabs: Home | Requests | History | Profile
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../models/app_models.dart';
import '../../services/app_service.dart';
import '../auth/auth_screens.dart';

// ══════════════════════════════════════════════════════════════════════════════
// DONOR SHELL
// ══════════════════════════════════════════════════════════════════════════════

class DonorShell extends StatefulWidget {
  const DonorShell({super.key});
  @override State<DonorShell> createState() => _DonorShellState();
}

class _DonorShellState extends State<DonorShell> {
  int _index = 0;
  final _user = AppUser.mockDonor();

  void _goTab(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    body: IndexedStack(index: _index, children: [
      DonorHomeTab(user: _user, onRequestsTap: () => _goTab(1)),
      DonorRequestsTab(user: _user),
      DonorHistoryTab(user: _user),
      DonorProfileTab(user: _user),
    ]),
    bottomNavigationBar: ResQBottomNav(
      currentIndex: _index, onTap: _goTab,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_rounded),    label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.water_drop),      label: 'Requests'),
        BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'History'),
        BottomNavigationBarItem(icon: Icon(Icons.person_rounded),  label: 'Profile'),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// HOME TAB
// ══════════════════════════════════════════════════════════════════════════════

class DonorHomeTab extends StatefulWidget {
  final AppUser user;
  final VoidCallback onRequestsTap;
  const DonorHomeTab({super.key, required this.user, required this.onRequestsTap});
  @override State<DonorHomeTab> createState() => _DonorHomeTabState();
}

class _DonorHomeTabState extends State<DonorHomeTab> {
  bool _available = true;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Padding(padding: const EdgeInsets.fromLTRB(20, 56, 20, 20), child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('RESQLINK', style: AppTextStyles.label(color: AppColors.red).copyWith(letterSpacing: 2, fontSize: 12)),
              Text('Donor Portal', style: AppTextStyles.heading(22)),
            ]),
            GestureDetector(onTap: () {},
              child: Container(width: 44, height: 44, decoration: const BoxDecoration(color: AppColors.white08, shape: BoxShape.circle),
                  child: const Icon(Icons.person_rounded, color: AppColors.white, size: 22))),
          ])),
        // Status card
        Container(margin: const EdgeInsets.symmetric(horizontal: 20), padding: const EdgeInsets.all(16), decoration: AppDecorations.card,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.user.name, style: AppTextStyles.bodyMedium(size: 16), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Text('${widget.user.bloodType ?? "—"} Blood Type', style: AppTextStyles.body(size: 13, color: AppColors.red)),
            ])),
            Column(children: [
              Text('AVAILABLE', style: AppTextStyles.label(color: AppColors.white40)),
              const SizedBox(height: 4),
              Switch(value: _available, onChanged: (v) => setState(() => _available = v)),
            ]),
          ])),
        const SizedBox(height: 14),
        AlertBanner(message: '2 Urgent Requests Nearby', actionLabel: 'VIEW', onAction: widget.onRequestsTap),
        const SizedBox(height: 20),
        const SectionHeader(title: 'QUICK ACTIONS'),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [
          _quickBtn(Icons.map_outlined, 'Camps', null),
          const SizedBox(width: 10),
          _quickBtn(Icons.water_drop, 'Requests', widget.onRequestsTap),
          const SizedBox(width: 10),
          _quickBtn(Icons.settings_outlined, 'Settings', null),
        ])),
        const SizedBox(height: 20),
        const SectionHeader(title: 'RECENT ACTIVITY'),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: const Column(children: [
          DonationHistoryTile(date: 'OCT 12', name: 'City General Hospital', type: 'Whole Blood', time: '10:30 AM'),
          DonationHistoryTile(date: 'JUL 05', name: 'Red Cross Center',       type: 'Plasma',      time: '02:15 PM'),
        ])),
      ]),
    ),
  );

  Widget _quickBtn(IconData icon, String label, VoidCallback? onTap) => Expanded(
    child: GestureDetector(onTap: onTap,
      child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
        child: Column(children: [Icon(icon, color: AppColors.red, size: 22), const SizedBox(height: 5),
          Text(label, style: AppTextStyles.body(size: 11))]))));
}

// ══════════════════════════════════════════════════════════════════════════════
// REQUESTS TAB  — list → detail → accept flow → donation → completion
// ══════════════════════════════════════════════════════════════════════════════

class DonorRequestsTab extends StatefulWidget {
  final AppUser user;
  const DonorRequestsTab({super.key, required this.user});
  @override State<DonorRequestsTab> createState() => _DonorRequestsTabState();
}

class _DonorRequestsTabState extends State<DonorRequestsTab> {
  BloodRequest? _selected;
  bool _accepted = false, _donating = false, _done = false;

  void _reset() => setState(() { _selected = null; _accepted = false; _donating = false; _done = false; });

  @override
  Widget build(BuildContext context) {
    if (_done)      return _completionScreen();
    if (_donating)  return _donationScreen();
    if (_accepted && _selected != null) return _detailScreen(_selected!, accepted: true);
    if (_selected != null) return _detailScreen(_selected!, accepted: false);
    return _listScreen();
  }

  // ── List ────────────────────────────────────────────────────────────────────
  Widget _listScreen() => Scaffold(
    appBar: ResQAppBar(title: 'Nearby Requests', showBack: false,
      actions: [Padding(padding: const EdgeInsets.only(right: 8),
        child: IconButton(icon: Container(width: 36, height: 36,
            decoration: BoxDecoration(color: AppColors.white08, borderRadius: BorderRadius.circular(50)),
            child: const Icon(Icons.filter_list, size: 18)), onPressed: () {}))]),
    body: FutureBuilder<List<BloodRequest>>(
      future: RequestService.fetchNearbyBloodRequests(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.red, strokeWidth: 2));
        }
        final requests = snap.data ?? BloodRequest.mockList();
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          itemCount: requests.length,
          itemBuilder: (_, i) => _RequestCard(req: requests[i],
            onAccept: () => setState(() { _selected = requests[i]; _accepted = true; }),
            onView:   () => setState(() { _selected = requests[i]; })),
        );
      },
    ),
  );

  // ── Detail ───────────────────────────────────────────────────────────────────
  Widget _detailScreen(BloodRequest req, {required bool accepted}) => Scaffold(
    appBar: ResQAppBar(title: 'Request Details', onBack: _reset,
      actions: [IconButton(icon: const Icon(Icons.share_outlined), onPressed: () {}),
                IconButton(icon: const Icon(Icons.more_vert), onPressed: () {})]),
    body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(color: AppColors.redDim, border: Border.all(color: AppColors.redMid), borderRadius: BorderRadius.circular(20)),
          child: Text('⚠ EMERGENCY REQUEST', style: AppTextStyles.label(color: AppColors.red).copyWith(letterSpacing: 1))),
      const SizedBox(height: 20),
      Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 24), decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(22)),
        child: Column(children: [
          Text('BLOOD GROUP REQUIRED', style: AppTextStyles.label(color: Colors.white54)),
          Text(req.bloodType.length > 2 ? req.bloodType[0] : req.bloodType.substring(0, req.bloodType.length - 1),
              style: AppTextStyles.heading(72)),
          Text(req.bloodType.endsWith('+') ? 'Positive' : 'Negative', style: AppTextStyles.heading(32)),
          const SizedBox(height: 8),
          Text('🕒 Urgent — respond quickly', style: AppTextStyles.body(size: 12, color: Colors.white70)),
        ])),
      const SizedBox(height: 14),
      _infoRow(Icons.local_hospital_rounded, req.hospital, '${req.distance} away'),
      const SizedBox(height: 8),
      _infoRow(Icons.water_drop, '${req.units} Units Required', 'Approximately ${req.units * 450}ml total'),
      const SizedBox(height: 8),
      _infoRow(Icons.location_on_outlined, req.address, req.urgencyLevel),
      const SizedBox(height: 28),
      if (!accepted) ...[
        ElevatedButton(onPressed: () => setState(() { _selected = req; _accepted = true; }),
            child: Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.volunteer_activism, size: 18), SizedBox(width: 8), Text('Accept Donation')])),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: _reset, child: const Text('Decline Request')),
      ] else ...[
        ElevatedButton(onPressed: () => setState(() => _donating = true),
            child: Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.water_drop_rounded, size: 18), SizedBox(width: 8), Text('Start Donation Process')])),
      ],
    ])),
  );

  Widget _infoRow(IconData icon, String title, String sub) => Container(
    padding: const EdgeInsets.all(13), decoration: AppDecorations.card,
    child: Row(children: [
      Icon(icon, color: AppColors.red, size: 20),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: AppTextStyles.bodyMedium(size: 13), overflow: TextOverflow.ellipsis),
        Text(sub,   style: AppTextStyles.body(size: 11, color: AppColors.white40), overflow: TextOverflow.ellipsis),
      ])),
    ]));

  // ── Donation Process ─────────────────────────────────────────────────────────
  Widget _donationScreen() => Scaffold(
    appBar: ResQAppBar(title: 'Donation in Progress', onBack: () => setState(() => _donating = false)),
    body: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(children: [
      const SizedBox(height: 16),
      Container(height: 160, decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.white08)),
          child: Stack(children: [
            ClipRRect(borderRadius: BorderRadius.circular(18), child: CustomPaint(size: const Size(double.infinity, 160), painter: const MapGridPainter())),
            const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.local_hospital_rounded, color: AppColors.red, size: 32),
              SizedBox(height: 4),
              Text('ABC Hospital', style: TextStyle(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ])),
          ])),
      const SizedBox(height: 24),
      Container(padding: const EdgeInsets.all(18), decoration: AppDecorations.card, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('DONATION STEPS', style: AppTextStyles.label(color: AppColors.red)),
        const SizedBox(height: 14),
        _step('1', 'Arrive at hospital reception', true),
        _step('2', 'Present your ID and this request ID: ${_selected?.id ?? "RQ-0001"}', true),
        _step('3', 'Medical staff will guide you', false),
        _step('4', 'Donation takes approximately 15-20 minutes', false),
      ])),
      const SizedBox(height: 24),
      Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.redDim, borderRadius: BorderRadius.circular(12), border: const Border(left: BorderSide(color: AppColors.red, width: 3))),
          child: Text('"Every donation is a beacon of hope for someone in urgent need."',
              textAlign: TextAlign.center, style: AppTextStyles.body(size: 13, color: AppColors.red).copyWith(fontStyle: FontStyle.italic))),
      const SizedBox(height: 28),
      ElevatedButton(
        onPressed: () async {
          await DonationService.acceptDonationRequest(_selected?.id ?? '', widget.user.id);
          if (mounted) setState(() => _done = true);
        },
        child: Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.check_circle_outline, size: 18), SizedBox(width: 8), Text('Mark Donation Complete')])),
    ])),
  );

  Widget _step(String num, String text, bool done) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 24, height: 24, decoration: BoxDecoration(shape: BoxShape.circle, color: done ? AppColors.green : AppColors.surface3),
          child: Center(child: done ? const Icon(Icons.check, size: 14, color: Colors.white) : Text(num, style: AppTextStyles.body(size: 11, color: AppColors.white40)))),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: AppTextStyles.body(size: 13, color: done ? AppColors.white70 : AppColors.white40))),
    ]));

  // ── Completion ────────────────────────────────────────────────────────────────
  Widget _completionScreen() => Scaffold(
    body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(children: [
      const SizedBox(height: 40),
      Container(width: 90, height: 90, decoration: BoxDecoration(color: AppColors.redDim, shape: BoxShape.circle, border: Border.all(color: AppColors.redMid, width: 2)),
          child: const Icon(Icons.check_circle_rounded, color: AppColors.red, size: 52)),
      const SizedBox(height: 20),
      Text('Donation Accepted', style: AppTextStyles.heading(24)),
      const SizedBox(height: 8),
      Text('Your contribution is being processed to save lives.', textAlign: TextAlign.center,
          style: AppTextStyles.body(size: 14, color: AppColors.white40)),
      const SizedBox(height: 28),
      Container(padding: const EdgeInsets.all(18), decoration: AppDecorations.card, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('HOSPITAL DETAILS', style: AppTextStyles.label(color: AppColors.red)),
        const SizedBox(height: 6),
        Text(_selected?.hospital ?? 'ABC Hospital', style: AppTextStyles.bodyMedium(size: 17)),
        const SizedBox(height: 12),
        Row(children: [
          _detailCol('UNIT ID', _selected?.id ?? '#RQ-9921'),
          const SizedBox(width: 32),
          _detailCol('STATUS', 'Verified', isStatus: true),
        ]),
        const SizedBox(height: 12),
        Text('LOCATION', style: AppTextStyles.label()),
        const SizedBox(height: 3),
        Text(_selected?.address ?? '123 Medical Plaza, Level 4', style: AppTextStyles.body(size: 13), overflow: TextOverflow.ellipsis),
      ])),
      const SizedBox(height: 28),
      ElevatedButton(onPressed: _reset,
          child: Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.dashboard_rounded, size: 18), SizedBox(width: 8), Text('Back to Requests')])),
    ]))),
  );

  Widget _detailCol(String label, String value, {bool isStatus = false}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppTextStyles.label()),
      const SizedBox(height: 3),
      Text(value, style: AppTextStyles.bodyMedium(size: 13, color: isStatus ? AppColors.green : AppColors.white)),
    ]);
}

class _RequestCard extends StatelessWidget {
  final BloodRequest req;
  final VoidCallback onAccept, onView;
  const _RequestCard({required this.req, required this.onAccept, required this.onView});

  Color get _urgColor {
    if (req.urgencyLevel == 'CRITICAL') return AppColors.red;
    if (req.urgencyLevel == 'URGENT')   return AppColors.orange;
    return AppColors.white40;
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.white08)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 46, height: 46, decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle),
            child: Center(child: Text(req.bloodType, style: AppTextStyles.bodyMedium(size: 13)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: _urgColor.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
              child: Text(req.urgencyLevel, style: AppTextStyles.label(color: _urgColor))),
          const SizedBox(height: 3),
          Text(req.hospital, style: AppTextStyles.bodyMedium(size: 14), overflow: TextOverflow.ellipsis),
        ])),
        Text('${req.distance}\nDIST', textAlign: TextAlign.right, style: AppTextStyles.body(size: 10, color: AppColors.white40)),
      ]),
      Padding(padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(req.address, style: AppTextStyles.body(size: 12, color: AppColors.white40), overflow: TextOverflow.ellipsis)),
      Row(children: [
        Expanded(child: ElevatedButton(onPressed: onAccept, style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(42)), child: const Text('Accept'))),
        const SizedBox(width: 10),
        Expanded(child: OutlinedButton(onPressed: onView, style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(42)), child: const Text('Details'))),
      ]),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// HISTORY TAB
// ══════════════════════════════════════════════════════════════════════════════

class DonorHistoryTab extends StatelessWidget {
  final AppUser user;
  const DonorHistoryTab({super.key, required this.user});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: ResQAppBar(title: 'Donation History', showBack: false,
      actions: [Padding(padding: const EdgeInsets.only(right: 8),
        child: IconButton(icon: Container(width: 36, height: 36,
            decoration: BoxDecoration(color: AppColors.white08, borderRadius: BorderRadius.circular(50)),
            child: const Icon(Icons.filter_list, size: 18)), onPressed: () {}))]),
    body: FutureBuilder<List<DonationRecord>>(
      future: DonationService.fetchDonationHistory(user.id),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.red, strokeWidth: 2));
        }
        final records = snap.data ?? DonationRecord.mockList();
        final r2023 = records.where((r) => ['OCT 12','JUL 05','MAR 15'].contains(r.date)).toList();
        final r2022 = records.where((r) => r.date == 'DEC 20').toList();
        return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: const [StatCard(label: 'TOTAL DONATIONS', value: '08'), SizedBox(width: 12), StatCard(label: 'LIVES IMPACTED', value: '24')]),
          const SizedBox(height: 24),
          if (r2023.isNotEmpty) ...[
            Text('2023 CONTRIBUTIONS', style: AppTextStyles.label(color: AppColors.white70).copyWith(fontSize: 11)),
            const SizedBox(height: 12),
            ...r2023.map((r) => DonationHistoryTile(date: r.date, name: r.hospital, type: r.type, time: r.time)),
            const SizedBox(height: 18),
          ],
          if (r2022.isNotEmpty) ...[
            Text('2022 CONTRIBUTIONS', style: AppTextStyles.label(color: AppColors.white70).copyWith(fontSize: 11)),
            const SizedBox(height: 12),
            ...r2022.map((r) => DonationHistoryTile(date: r.date, name: r.hospital, type: r.type, time: r.time)),
          ],
        ]));
      },
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// PROFILE TAB
// ══════════════════════════════════════════════════════════════════════════════

class DonorProfileTab extends StatefulWidget {
  final AppUser user;
  const DonorProfileTab({super.key, required this.user});
  @override State<DonorProfileTab> createState() => _DonorProfileTabState();
}

class _DonorProfileTabState extends State<DonorProfileTab> {
  bool _available = true, _loading = false;
  String _bloodGroup = 'A+';
  static const _groups = ['A+','A-','B+','B-','O+','O-','AB+','AB-'];

  final _nameCtrl     = TextEditingController(text: 'Sarah Jenkins');
  final _phoneCtrl    = TextEditingController(text: '+1 (555) 123-4567');
  final _emailCtrl    = TextEditingController(text: 'sarah@example.com');
  final _locationCtrl = TextEditingController(text: 'San Francisco, CA');

  @override
  void dispose() {
    for (final c in [_nameCtrl, _phoneCtrl, _emailCtrl, _locationCtrl]) c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    await ProfileService.updateProfile(widget.user.id, {'name': _nameCtrl.text, 'bloodType': _bloodGroup});
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
      const SizedBox(height: 22),
      // Availability toggle
      Container(padding: const EdgeInsets.all(14), decoration: AppDecorations.cardSmall, child: Row(children: [
        const Icon(Icons.notifications_active, color: AppColors.red, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Available for Donations', style: AppTextStyles.bodyMedium(size: 13)),
          Text('Receive blood request alerts', style: AppTextStyles.body(size: 11, color: AppColors.white40)),
        ])),
        Switch(value: _available, onChanged: (v) => setState(() => _available = v)),
      ])),
      const SizedBox(height: 18),
      ProfileField(label: 'FULL NAME', hint: 'Your name', controller: _nameCtrl),
      const SizedBox(height: 12),
      ProfileField(label: 'PHONE', hint: 'Phone', controller: _phoneCtrl, prefixIcon: Icons.phone_outlined, keyboardType: TextInputType.phone),
      const SizedBox(height: 12),
      ProfileField(label: 'EMAIL', hint: 'Email', controller: _emailCtrl, prefixIcon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
      const SizedBox(height: 12),
      ProfileField(label: 'CURRENT LOCATION', hint: 'City', controller: _locationCtrl, prefixIcon: Icons.location_on_outlined, suffixIcon: Icons.my_location),
      const SizedBox(height: 18),
      Align(alignment: Alignment.centerLeft, child: Text('BLOOD GROUP', style: AppTextStyles.label())),
      const SizedBox(height: 10),
      GridView.builder(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.3),
        itemCount: _groups.length,
        itemBuilder: (_, i) {
          final g = _groups[i]; final sel = g == _bloodGroup;
          return GestureDetector(onTap: () => setState(() => _bloodGroup = g),
            child: AnimatedContainer(duration: const Duration(milliseconds: 180), alignment: Alignment.center,
              decoration: BoxDecoration(color: sel ? AppColors.redDim : AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: sel ? AppColors.red : AppColors.white08, width: sel ? 2 : 1)),
              child: Text(g, style: AppTextStyles.bodyMedium(size: 12, color: sel ? AppColors.red : AppColors.white70))));
        }),
      const SizedBox(height: 14),
      Container(padding: const EdgeInsets.all(13), decoration: AppDecorations.cardSmall, child: Row(children: [
        const Icon(Icons.history_rounded, color: AppColors.red, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Last Donation', style: AppTextStyles.label()),
          const SizedBox(height: 2),
          Text('Oct 12, 2023 — City General Hospital', style: AppTextStyles.body(size: 12, color: AppColors.white70), overflow: TextOverflow.ellipsis),
        ])),
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
}
