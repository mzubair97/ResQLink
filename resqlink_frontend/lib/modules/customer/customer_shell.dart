// ─────────────────────────────────────────────────────────────────────────────
// modules/customer/ — CustomerShell (IndexedStack hub) + all screens
// Tabs: Home | Ambulance | Blood | Profile
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../models/app_models.dart';
import '../../services/app_service.dart';
import '../auth/auth_screens.dart';

// ══════════════════════════════════════════════════════════════════════════════
// CUSTOMER SHELL  —  IndexedStack root
// ══════════════════════════════════════════════════════════════════════════════

class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key});
  @override State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int _index = 0;
  final _user = AppUser.mockCustomer();

  void _goTab(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(index: _index, children: [
        CustomerHomeTab(user: _user, onAmbulanceTap: () => _goTab(1), onBloodTap: () => _goTab(2)),
        CustomerAmbulanceFlow(user: _user),
        CustomerBloodFlow(user: _user),
        CustomerProfileTab(user: _user),
      ]),
      bottomNavigationBar: ResQBottomNav(
        currentIndex: _index,
        onTap: _goTab,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded),           label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.local_shipping_rounded),  label: 'Ambulance'),
          BottomNavigationBarItem(icon: Icon(Icons.water_drop_rounded),      label: 'Blood'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded),          label: 'Profile'),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// HOME TAB
// ══════════════════════════════════════════════════════════════════════════════

class CustomerHomeTab extends StatelessWidget {
  final AppUser user;
  final VoidCallback onAmbulanceTap, onBloodTap;
  const CustomerHomeTab({super.key, required this.user, required this.onAmbulanceTap, required this.onBloodTap});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(automaticallyImplyLeading: false,
      title: Text('Customer Portal', style: AppTextStyles.heading(18)),
      actions: [_avatarBtn(context)]),
    body: SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Quick actions card
        Container(
          margin: const EdgeInsets.fromLTRB(20, 12, 20, 14),
          padding: const EdgeInsets.all(18),
          decoration: AppDecorations.card,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('WHAT DO YOU NEED?', style: AppTextStyles.label(color: AppColors.white40)),
            const SizedBox(height: 4),
            Text('Request Assistance', style: AppTextStyles.bodyMedium(size: 17)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: ElevatedButton(
                onPressed: onAmbulanceTap,
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                child: Row(mainAxisSize: MainAxisSize.min, children: const [
                  Icon(Icons.local_shipping_rounded, size: 18), SizedBox(width: 8), Text('Ambulance'),
                ]))),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton(
                onPressed: onBloodTap,
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                child: Row(mainAxisSize: MainAxisSize.min, children: const [
                  Icon(Icons.water_drop_rounded, size: 18, color: AppColors.red), SizedBox(width: 8), Text('Blood'),
                ]))),
            ]),
          ]),
        ),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: const [
          StatCard(label: 'REQUESTS SENT', value: '03'),
          SizedBox(width: 12),
          StatCard(label: 'HELPED BY',     value: '09'),
        ])),
        const SizedBox(height: 14),
        AlertBanner(message: 'Last request fulfilled in 12 min', color: AppColors.green),
        const SizedBox(height: 20),
        const SectionHeader(title: 'RECENT ACTIVITY'),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Column(children: [
          _actTile('APR 10', 'Ambulance Request', 'Dispatched in 8 min', Icons.local_shipping_rounded),
          const SizedBox(height: 10),
          _actTile('APR 10', 'Blood Request — O+', 'Fulfilled by 2 donors', Icons.water_drop_rounded),
        ])),
      ]),
    ),
  );

  Widget _avatarBtn(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 12),
    child: GestureDetector(
      onTap: () {},
      child: Container(width: 38, height: 38,
          decoration: const BoxDecoration(color: AppColors.white08, shape: BoxShape.circle),
          child: const Icon(Icons.person_rounded, size: 20))));

  Widget _actTile(String date, String title, String sub, IconData icon) => Container(
    padding: const EdgeInsets.all(13), margin: const EdgeInsets.only(bottom: 2),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      Container(width: 40, height: 40,
          decoration: BoxDecoration(color: AppColors.redDim, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: AppColors.red, size: 20)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: AppTextStyles.bodyMedium(size: 13), overflow: TextOverflow.ellipsis),
        Text(sub,   style: AppTextStyles.body(size: 11, color: AppColors.white40), overflow: TextOverflow.ellipsis),
      ])),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 15),
        const SizedBox(height: 2),
        Text(date, style: AppTextStyles.body(size: 10, color: AppColors.white40)),
      ]),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// AMBULANCE FLOW  (multi-step within the tab, no Navigator.push for main steps)
// Steps: Form → Waiting → Matched/Tracking → Completed
// ══════════════════════════════════════════════════════════════════════════════

enum _AmbStep { form, waiting, tracking, completed }

class CustomerAmbulanceFlow extends StatefulWidget {
  final AppUser user;
  const CustomerAmbulanceFlow({super.key, required this.user});
  @override State<CustomerAmbulanceFlow> createState() => _CustomerAmbulanceFlowState();
}

class _CustomerAmbulanceFlowState extends State<CustomerAmbulanceFlow> {
  _AmbStep _step = _AmbStep.form;
  AmbulanceRequest? _request;
  bool _loading = false;

  // form state
  String? _emergencyType;
  String _severity = 'Medium';
  final _addressCtrl = TextEditingController();
  final _notesCtrl   = TextEditingController();

  static const _emergencyTypes = ['Cardiac Arrest','Road Accident','Respiratory Emergency','Stroke','Severe Injury','Other'];
  static const _severities = ['Low','Medium','Critical'];

  Color _sevColor(String s) {
    if (s == 'Low') return AppColors.green;
    if (s == 'Critical') return AppColors.red;
    return AppColors.orange;
  }

  @override
  void dispose() { _addressCtrl.dispose(); _notesCtrl.dispose(); super.dispose(); }

  Future<void> _submitRequest() async {
    if (_emergencyType == null) { showErrorSnack(context, 'Select emergency type'); return; }
    if (_addressCtrl.text.trim().isEmpty) { showErrorSnack(context, 'Enter pickup location'); return; }
    setState(() { _loading = true; _step = _AmbStep.waiting; });
    try {
      final req = await RequestService.submitAmbulanceRequest({
        'emergencyType': _emergencyType, 'severity': _severity,
        'address': _addressCtrl.text, 'notes': _notesCtrl.text,
      });
      if (!mounted) return;
      final matched = await RequestService.pollForMatch(req.id);
      if (!mounted) return;
      setState(() { _request = matched; _step = _AmbStep.tracking; });
    } finally { if (mounted) setState(() => _loading = false); }
  }

  void _completeRide() => setState(() => _step = _AmbStep.completed);
  void _reset() => setState(() { _step = _AmbStep.form; _request = null; _emergencyType = null; _severity = 'Medium'; _addressCtrl.clear(); _notesCtrl.clear(); });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: KeyedSubtree(key: ValueKey(_step), child: _body()),
    );
  }

  Widget _body() {
    switch (_step) {
      case _AmbStep.form:      return _formScreen();
      case _AmbStep.waiting:   return _waitingScreen();
      case _AmbStep.tracking:  return _trackingScreen();
      case _AmbStep.completed: return _completedScreen();
    }
  }

  // ── Form ────────────────────────────────────────────────────────────────────
  Widget _formScreen() => Scaffold(
    appBar: const ResQAppBar(title: 'Ambulance Request', showBack: false),
    body: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('EMERGENCY TYPE', style: AppTextStyles.label()),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.white08)),
          child: DropdownButtonHideUnderline(child: DropdownButton<String>(
            isExpanded: true, dropdownColor: AppColors.surface2, value: _emergencyType,
            hint: Text('Select emergency type...', style: AppTextStyles.body(size: 14, color: AppColors.white40)),
            icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.white40),
            items: _emergencyTypes.map((e) => DropdownMenuItem(value: e, child: Text(e, style: AppTextStyles.body(size: 14)))).toList(),
            onChanged: (v) => setState(() => _emergencyType = v),
          )),
        ),
        const SizedBox(height: 20),
        Text('SEVERITY LEVEL', style: AppTextStyles.label()),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.white08)),
          child: Row(children: _severities.map((s) {
            final sel = _severity == s; final c = _sevColor(s);
            return Expanded(child: GestureDetector(
              onTap: () => setState(() => _severity = s),
              child: AnimatedContainer(duration: const Duration(milliseconds: 180),
                alignment: Alignment.center, padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: sel ? c.withOpacity(0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  border: sel ? Border.all(color: c.withOpacity(0.5)) : null),
                child: Text(s, style: AppTextStyles.bodyMedium(size: 13, color: sel ? c : AppColors.white40)))));
          }).toList()),
        ),
        const SizedBox(height: 20),
        Text('PICKUP LOCATION', style: AppTextStyles.label()),
        const SizedBox(height: 8),
        TextField(
          controller: _addressCtrl, style: AppTextStyles.body(size: 14),
          decoration: InputDecoration(
            hintText: 'Enter address or street name...',
            hintStyle: AppTextStyles.body(size: 14, color: AppColors.white40),
            suffixIcon: const Icon(Icons.my_location, color: AppColors.red, size: 20))),
        const SizedBox(height: 10),
        // Map placeholder
        Container(height: 140, decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.white08)),
          child: Stack(children: [
            ClipRRect(borderRadius: BorderRadius.circular(14), child: CustomPaint(size: const Size(double.infinity, 140), painter: const MapGridPainter())),
            Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.location_on, color: AppColors.red, size: 32),
              Text('Tap to pin location', style: AppTextStyles.body(size: 11, color: AppColors.white40)),
            ])),
          ])),
        const SizedBox(height: 20),
        Text('ADDITIONAL DETAILS', style: AppTextStyles.label()),
        const SizedBox(height: 8),
        TextField(controller: _notesCtrl, maxLines: 3, style: AppTextStyles.body(size: 14),
          decoration: InputDecoration(hintText: 'Briefly describe the situation...', hintStyle: AppTextStyles.body(size: 14, color: AppColors.white40), alignLabelWithHint: true)),
        const SizedBox(height: 28),
        ElevatedButton(
          onPressed: _loading ? null : _submitRequest,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.local_shipping_rounded, size: 18), const SizedBox(width: 8), const Text('Request Now'),
          ])),
      ]),
    ),
  );

  // ── Waiting ─────────────────────────────────────────────────────────────────
  Widget _waitingScreen() => Scaffold(
    appBar: const ResQAppBar(title: 'Finding Driver', showBack: false),
    body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 100, height: 100, decoration: BoxDecoration(color: AppColors.redDim, shape: BoxShape.circle, border: Border.all(color: AppColors.redMid)),
        child: const CircularProgressIndicator(color: AppColors.red, strokeWidth: 2.5)),
      const SizedBox(height: 28),
      Text('Finding nearest driver...', style: AppTextStyles.heading(18)),
      const SizedBox(height: 8),
      Text('Please keep your phone close', style: AppTextStyles.body(size: 13, color: AppColors.white40)),
      const SizedBox(height: 32),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 40),
        child: OutlinedButton(onPressed: _reset, style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)), child: const Text('Cancel Request'))),
    ])),
  );

  // ── Tracking ─────────────────────────────────────────────────────────────────
  Widget _trackingScreen() => Scaffold(
    body: Stack(children: [
      SizedBox.expand(child: CustomPaint(painter: const MapGridPainter(opacity: 0.1))),
      // Route line
      Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.local_shipping_rounded, color: AppColors.red, size: 44),
        const SizedBox(height: 6),
        Text('Driver en route', style: AppTextStyles.body(size: 13, color: AppColors.white70)),
      ])),
      // Top ETA card
      Positioned(top: MediaQuery.of(context).padding.top + 12, left: 20, right: 20,
        child: Container(padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFF2D2222), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.white08)),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.emergency, color: AppColors.white, size: 20)),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('DRIVER', style: AppTextStyles.label(color: AppColors.white40)),
              Text(_request?.assignedDriverName ?? 'Alex Driver', style: AppTextStyles.bodyMedium(size: 15), overflow: TextOverflow.ellipsis),
            ]),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('ETA', style: AppTextStyles.label(color: AppColors.white40)),
              Text(_request?.eta ?? '8 MIN', style: AppTextStyles.heading(18, color: AppColors.red)),
            ]),
          ])),
      ),
      // Bottom sheet
      Align(alignment: Alignment.bottomCenter,
        child: Container(width: double.infinity, padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
          decoration: const BoxDecoration(color: Color(0xFF1A1212), borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.white15, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('• SEVERITY: ${_severity.toUpperCase()}', style: AppTextStyles.label(color: AppColors.red)),
            const SizedBox(height: 8),
            Text(_addressCtrl.text.isNotEmpty ? _addressCtrl.text : '242 Oak Street, Apt 4B',
                style: AppTextStyles.heading(17), overflow: TextOverflow.ellipsis),
            Text('San Francisco, CA', style: AppTextStyles.body(size: 13, color: AppColors.white40)),
            const SizedBox(height: 16),
            Row(children: [
              _infoTile('DISTANCE', '2.4 mi'),
              const SizedBox(width: 10),
              _infoTile('TRAFFIC', 'Light', color: AppColors.green),
            ]),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _completeRide,
                child: const Text('Request Completed ✓')),
          ])),
      ),
    ]),
  );

  Widget _infoTile(String label, String value, {Color color = AppColors.white}) => Expanded(
    child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.white08, borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppTextStyles.label()),
        const SizedBox(height: 3),
        Text(value, style: AppTextStyles.heading(16, color: color)),
      ])),
  );

  // ── Completed ────────────────────────────────────────────────────────────────
  Widget _completedScreen() => Scaffold(
    body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(children: [
      const SizedBox(height: 32),
      Container(width: 90, height: 90, decoration: BoxDecoration(color: AppColors.redDim, shape: BoxShape.circle, border: Border.all(color: AppColors.redMid, width: 2)),
          child: const Icon(Icons.check_circle_rounded, color: AppColors.red, size: 52)),
      const SizedBox(height: 20),
      Text('Request Completed', style: AppTextStyles.heading(24)),
      const SizedBox(height: 8),
      Text('Help is on the way. Stay calm.', textAlign: TextAlign.center,
          style: AppTextStyles.body(size: 14, color: AppColors.white40)),
      const SizedBox(height: 32),
      Container(padding: const EdgeInsets.all(18), decoration: AppDecorations.card, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('REQUEST SUMMARY', style: AppTextStyles.label(color: AppColors.red)),
        const SizedBox(height: 14),
        _summaryRow('Driver', _request?.assignedDriverName ?? 'Alex Driver'),
        _summaryRow('Emergency', _emergencyType ?? '—'),
        _summaryRow('Severity',  _severity),
        _summaryRow('ETA',       _request?.eta ?? '8 min'),
      ])),
      const SizedBox(height: 28),
      ElevatedButton(onPressed: _reset, child: const Text('Back to Home')),
    ]))),
  );

  Widget _summaryRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: AppTextStyles.body(size: 13, color: AppColors.white40)),
      Flexible(child: Text(value, style: AppTextStyles.bodyMedium(size: 13), overflow: TextOverflow.ellipsis, textAlign: TextAlign.end)),
    ]));
}

// ══════════════════════════════════════════════════════════════════════════════
// BLOOD FLOW  (multi-step: Form → Waiting → Matched → Completed)
// ══════════════════════════════════════════════════════════════════════════════

enum _BloodStep { form, waiting, matched, completed }

class CustomerBloodFlow extends StatefulWidget {
  final AppUser user;
  const CustomerBloodFlow({super.key, required this.user});
  @override State<CustomerBloodFlow> createState() => _CustomerBloodFlowState();
}

class _CustomerBloodFlowState extends State<CustomerBloodFlow> {
  _BloodStep _step = _BloodStep.form;
  String _bloodGroup = 'A+', _priority = 'Urgent';
  bool _loading = false, _detecting = false;
  final _hospitalCtrl = TextEditingController();
  final _unitsCtrl    = TextEditingController();

  static const _groups = ['A+','A-','B+','B-','O+','O-','AB+','AB-'];

  @override
  void dispose() { _hospitalCtrl.dispose(); _unitsCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_hospitalCtrl.text.trim().isEmpty) { showErrorSnack(context, 'Enter hospital / location'); return; }
    setState(() { _loading = true; _step = _BloodStep.waiting; });
    try {
      await RequestService.submitBloodRequest({
        'bloodType': _bloodGroup, 'priority': _priority,
        'hospital': _hospitalCtrl.text, 'units': int.tryParse(_unitsCtrl.text) ?? 1,
      });
      if (!mounted) return;
      await Future.delayed(const Duration(seconds: 3)); // simulate matching
      if (!mounted) return;
      setState(() => _step = _BloodStep.matched);
    } finally { if (mounted) setState(() => _loading = false); }
  }

  void _complete() => setState(() => _step = _BloodStep.completed);
  void _reset()    => setState(() { _step = _BloodStep.form; _hospitalCtrl.clear(); _unitsCtrl.clear(); });

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 280),
    child: KeyedSubtree(key: ValueKey(_step), child: _body()),
  );

  Widget _body() {
    switch (_step) {
      case _BloodStep.form:      return _formScreen();
      case _BloodStep.waiting:   return _waitingScreen();
      case _BloodStep.matched:   return _matchedScreen();
      case _BloodStep.completed: return _completedScreen();
    }
  }

  Widget _formScreen() => Scaffold(
    appBar: const ResQAppBar(title: 'Blood Request', showBack: false),
    body: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('SELECT BLOOD GROUP', style: AppTextStyles.label(color: AppColors.red)),
        Text('Required', style: AppTextStyles.body(size: 12, color: AppColors.white40)),
      ]),
      const SizedBox(height: 10),
      GridView.builder(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.2),
        itemCount: _groups.length,
        itemBuilder: (_, i) {
          final g = _groups[i]; final sel = g == _bloodGroup;
          return GestureDetector(onTap: () => setState(() => _bloodGroup = g),
            child: AnimatedContainer(duration: const Duration(milliseconds: 180), alignment: Alignment.center,
              decoration: BoxDecoration(color: sel ? AppColors.redDim : AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: sel ? AppColors.red : AppColors.white08, width: sel ? 2 : 1)),
              child: Text(g, style: AppTextStyles.bodyMedium(size: 13, color: sel ? AppColors.red : AppColors.white70))));
        }),
      const SizedBox(height: 22),
      Text('REQUEST PRIORITY', style: AppTextStyles.label(color: AppColors.red)),
      const SizedBox(height: 8),
      Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.white08)),
        child: Row(children: ['Normal','Urgent'].map((p) {
          final sel = _priority == p;
          return Expanded(child: GestureDetector(onTap: () => setState(() => _priority = p),
            child: AnimatedContainer(duration: const Duration(milliseconds: 200), alignment: Alignment.center, padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: sel ? (p == 'Urgent' ? AppColors.red : AppColors.surface2) : Colors.transparent, borderRadius: BorderRadius.circular(9)),
              child: Text(p, style: AppTextStyles.bodyMedium(size: 13, color: sel ? AppColors.white : AppColors.white40)))));
        }).toList()),
      ),
      const SizedBox(height: 22),
      ProfileField(label: 'HOSPITAL / LOCATION', hint: 'Enter hospital name or address...', controller: _hospitalCtrl, prefixIcon: Icons.location_on_outlined),
      const SizedBox(height: 14),
      ProfileField(label: 'UNITS REQUIRED (BAGS)', hint: 'How many units?', controller: _unitsCtrl, prefixIcon: Icons.bloodtype_outlined, keyboardType: TextInputType.number),
      const SizedBox(height: 20),
      // Location detector card
      Container(width: double.infinity, padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.white08)),
        child: Column(children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: AppColors.redDim, shape: BoxShape.circle, border: Border.all(color: AppColors.redMid)),
              child: const Icon(Icons.gps_fixed, color: AppColors.red, size: 22)),
          const SizedBox(height: 8),
          Text(_detecting ? 'Detecting your location...' : 'Auto-detect current location',
              style: AppTextStyles.body(size: 13, color: AppColors.white70)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(shape: const StadiumBorder(), minimumSize: const Size(170, 44)),
            onPressed: () async {
              setState(() => _detecting = true);
              await Future.delayed(const Duration(seconds: 2));
              if (mounted) setState(() { _detecting = false; _hospitalCtrl.text = 'ABC Hospital, 123 Medical Plaza'; });
            },
            icon: _detecting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.gps_fixed, size: 18),
            label: Text(_detecting ? 'Detecting...' : 'Detect Location', style: AppTextStyles.bodyMedium(size: 14))),
        ])),
      const SizedBox(height: 28),
      ElevatedButton(onPressed: _loading ? null : _submit,
          child: Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.water_drop_rounded, size: 18), SizedBox(width: 8), Text('Submit Request')])),
    ])),
  );

  Widget _waitingScreen() => Scaffold(
    appBar: const ResQAppBar(title: 'Finding Donors', showBack: false),
    body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 100, height: 100, decoration: BoxDecoration(color: AppColors.redDim, shape: BoxShape.circle, border: Border.all(color: AppColors.redMid)),
          child: const CircularProgressIndicator(color: AppColors.red, strokeWidth: 2.5)),
      const SizedBox(height: 28),
      Text('Searching for $_bloodGroup donors...', style: AppTextStyles.heading(17)),
      const SizedBox(height: 8),
      Text('This usually takes under 2 minutes', style: AppTextStyles.body(size: 13, color: AppColors.white40)),
      const SizedBox(height: 32),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 40),
          child: OutlinedButton(onPressed: _reset, style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)), child: const Text('Cancel'))),
    ])),
  );

  Widget _matchedScreen() => Scaffold(
    appBar: const ResQAppBar(title: 'Donor Matched', showBack: false),
    body: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(children: [
      const SizedBox(height: 20),
      Container(width: 80, height: 80, decoration: BoxDecoration(color: AppColors.green.withOpacity(0.15), shape: BoxShape.circle, border: Border.all(color: AppColors.green.withOpacity(0.4))),
          child: const Icon(Icons.volunteer_activism, color: AppColors.green, size: 40)),
      const SizedBox(height: 16),
      Text('Donor Found!', style: AppTextStyles.heading(24, color: AppColors.green)),
      const SizedBox(height: 8),
      Text('A donor has accepted your request and is on the way.', textAlign: TextAlign.center,
          style: AppTextStyles.body(size: 14, color: AppColors.white40)),
      const SizedBox(height: 28),
      Container(padding: const EdgeInsets.all(18), decoration: AppDecorations.card, child: Column(children: [
        Row(children: [
          Container(width: 50, height: 50, decoration: BoxDecoration(color: AppColors.redDim, shape: BoxShape.circle, border: Border.all(color: AppColors.redMid)),
              child: Center(child: Text(_bloodGroup, style: AppTextStyles.bodyMedium(size: 13, color: AppColors.red)))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Sarah Jenkins', style: AppTextStyles.bodyMedium(size: 15)),
            Text('ETA: 12 minutes', style: AppTextStyles.body(size: 13, color: AppColors.white40)),
          ])),
          Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: AppColors.white08, shape: BoxShape.circle),
              child: const Icon(Icons.phone_outlined, color: AppColors.red, size: 18)),
        ]),
      ])),
      const SizedBox(height: 20),
      Container(height: 130, decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.white08)),
        child: Stack(children: [
          ClipRRect(borderRadius: BorderRadius.circular(14), child: CustomPaint(size: const Size(double.infinity, 130), painter: const MapGridPainter())),
          const Center(child: Icon(Icons.location_on, color: AppColors.red, size: 32)),
        ])),
      const SizedBox(height: 24),
      ElevatedButton(onPressed: _complete, child: const Text('Mark as Received')),
    ])),
  );

  Widget _completedScreen() => Scaffold(
    body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(children: [
      const SizedBox(height: 40),
      Container(width: 90, height: 90, decoration: BoxDecoration(color: AppColors.redDim, shape: BoxShape.circle, border: Border.all(color: AppColors.redMid, width: 2)),
          child: const Icon(Icons.check_circle_rounded, color: AppColors.red, size: 52)),
      const SizedBox(height: 20),
      Text('Donation Received', style: AppTextStyles.heading(24)),
      const SizedBox(height: 8),
      Text('Thank you. Your request has been fulfilled.', textAlign: TextAlign.center,
          style: AppTextStyles.body(size: 14, color: AppColors.white40)),
      const SizedBox(height: 28),
      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.redDim, borderRadius: BorderRadius.circular(12), border: const Border(left: BorderSide(color: AppColors.red, width: 3))),
          child: Text('"Every donation is a beacon of hope for someone in urgent need."',
              textAlign: TextAlign.center, style: AppTextStyles.body(size: 13, color: AppColors.red).copyWith(fontStyle: FontStyle.italic))),
      const SizedBox(height: 28),
      ElevatedButton(onPressed: _reset, child: const Text('Back to Home')),
    ]))),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// PROFILE TAB
// ══════════════════════════════════════════════════════════════════════════════

class CustomerProfileTab extends StatefulWidget {
  final AppUser user;
  const CustomerProfileTab({super.key, required this.user});
  @override State<CustomerProfileTab> createState() => _CustomerProfileTabState();
}

class _CustomerProfileTabState extends State<CustomerProfileTab> {
  bool _notifications = true, _shareLocation = true, _loading = false;
  final _nameCtrl    = TextEditingController(text: 'John Doe');
  final _phoneCtrl   = TextEditingController(text: '+1 (555) 000-1234');
  final _emailCtrl   = TextEditingController(text: 'john@example.com');
  final _addressCtrl = TextEditingController(text: '123 Main Street, SF');
  final _contactNameCtrl  = TextEditingController(text: 'Jane Doe');
  final _contactPhoneCtrl = TextEditingController(text: '+1 (555) 000-5678');
  final _allergyCtrl      = TextEditingController(text: 'None');

  @override
  void dispose() {
    for (final c in [_nameCtrl, _phoneCtrl, _emailCtrl, _addressCtrl, _contactNameCtrl, _contactPhoneCtrl, _allergyCtrl]) c.dispose();
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
    body: Stack(children: [
      SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(children: [
          const SizedBox(height: 20),
          // Avatar
          Stack(alignment: Alignment.bottomRight, children: [
            Container(padding: const EdgeInsets.all(3), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.red, width: 2)),
                child: const CircleAvatar(radius: 46, backgroundColor: AppColors.surface2, child: Icon(Icons.person_rounded, color: AppColors.white40, size: 42))),
            Container(padding: const EdgeInsets.all(7), decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle),
                child: const Icon(Icons.camera_alt, size: 15, color: AppColors.white)),
          ]),
          const SizedBox(height: 8),
          Text('Change Photo', style: AppTextStyles.body(size: 12, color: AppColors.red)),
          const SizedBox(height: 22),
          // Toggles
          _toggleRow(Icons.notifications_active, 'Emergency Notifications', 'Get alerts on request status', _notifications, (v) => setState(() => _notifications = v)),
          const SizedBox(height: 10),
          _toggleRow(Icons.location_on_rounded, 'Share Live Location', 'Allow responders to track you', _shareLocation, (v) => setState(() => _shareLocation = v)),
          const SizedBox(height: 22),
          // Personal
          ProfileField(label: 'FULL NAME',    hint: 'Your name',   controller: _nameCtrl),
          const SizedBox(height: 12),
          ProfileField(label: 'PHONE',        hint: 'Phone number', controller: _phoneCtrl,   prefixIcon: Icons.phone_outlined, keyboardType: TextInputType.phone),
          const SizedBox(height: 12),
          ProfileField(label: 'EMAIL',        hint: 'Email',        controller: _emailCtrl,   prefixIcon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 12),
          ProfileField(label: 'HOME ADDRESS', hint: 'Address',      controller: _addressCtrl, prefixIcon: Icons.home_outlined, suffixIcon: Icons.my_location),
          const SizedBox(height: 18),
          Align(alignment: Alignment.centerLeft, child: Text('EMERGENCY CONTACT', style: AppTextStyles.label(color: AppColors.red))),
          const SizedBox(height: 10),
          ProfileField(label: 'CONTACT NAME',  hint: 'Name',  controller: _contactNameCtrl,  prefixIcon: Icons.person_outline),
          const SizedBox(height: 12),
          ProfileField(label: 'CONTACT PHONE', hint: 'Phone', controller: _contactPhoneCtrl, prefixIcon: Icons.phone_outlined, keyboardType: TextInputType.phone),
          const SizedBox(height: 18),
          Align(alignment: Alignment.centerLeft, child: Text('MEDICAL INFO', style: AppTextStyles.label(color: AppColors.red))),
          const SizedBox(height: 10),
          ProfileField(label: 'BLOOD TYPE',      hint: 'O Positive (O+)', prefixIcon: Icons.water_drop_outlined),
          const SizedBox(height: 12),
          ProfileField(label: 'KNOWN ALLERGIES', hint: 'None',             controller: _allergyCtrl, prefixIcon: Icons.medical_services_outlined),
          const SizedBox(height: 28),
          ElevatedButton(onPressed: _loading ? null : _save,
              style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
              child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save Changes')),
          const SizedBox(height: 12),
          TextButton.icon(onPressed: _logout, icon: const Icon(Icons.logout, color: AppColors.red, size: 18),
              label: Text('Sign Out', style: AppTextStyles.bodyMedium(size: 14, color: AppColors.red))),
          const SizedBox(height: 32),
        ]),
      ),
    ]),
  );

  Widget _toggleRow(IconData icon, String label, String sub, bool val, ValueChanged<bool> onChange) =>
    Container(padding: const EdgeInsets.all(13), decoration: AppDecorations.cardSmall,
      child: Row(children: [
        Icon(icon, color: AppColors.red, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: AppTextStyles.bodyMedium(size: 13)),
          Text(sub, style: AppTextStyles.body(size: 11, color: AppColors.white40), overflow: TextOverflow.ellipsis),
        ])),
        Switch(value: val, onChanged: onChange),
      ]));
}
