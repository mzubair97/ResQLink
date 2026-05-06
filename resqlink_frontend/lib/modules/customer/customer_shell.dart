// modules/customer/customer_shell.dart
// Polish v3: haptics, InkWell ripples, AnimatedPressButton, confirm dialogs,
// shimmer loading, RefreshIndicator, RepaintBoundary on maps, staggered lists,
// tel: links on phone icons, accessibility Semantics.
// v4: Replaced all fake MapGridPainter with real flutter_map (OpenStreetMap).
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/hospital_location_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/haptics.dart';
import '../../widgets/shimmer_widgets.dart';
import '../../widgets/animated_press_button.dart';
import '../../models/app_models.dart';
import '../../services/app_service.dart';
import '../auth/auth_screens.dart';
import 'dart:convert'; // for jsonDecode
import 'package:http/http.dart' as http; // for HTTP requests
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../services/app_service.dart'; // for StorageService

// ══════════════════════════════════════════════════════════════════════════════
// CUSTOMER SHELL
// ══════════════════════════════════════════════════════════════════════════════

class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key});
  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int _index = 0;
  AppUser? _user;
  Map<String, dynamic>? _customerRow;
  bool _loading = true;

  static final _sb = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final authUser = _sb.auth.currentUser;
    if (authUser == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final profile =
          await _sb.from('profiles').select().eq('id', authUser.id).single();
      final customerRow = await _sb
          .from('customer_data')
          .select()
          .eq('customer_id', authUser.id)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _user =
              AppUser.fromProfile(profile, authUser.id, authUser.email ?? '');
          _customerRow = customerRow;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _user = AppUser(
            id: authUser.id,
            name: 'Customer',
            email: authUser.email ?? '',
            phone: '',
            role: UserRole.customer,
          );
          _loading = false;
        });
      }
    }
  }

  void _goTab(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: const Center(
            child: CircularProgressIndicator(
                color: AppColors.red, strokeWidth: 2)),
      );
    }
    final user = _user ??
        AppUser(
          id: _sb.auth.currentUser?.id ?? '',
          name: 'Customer',
          email: '',
          phone: '',
          role: UserRole.customer,
        );
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(index: _index, children: [
        CustomerHomeTab(
            user: user,
            onAmbulanceTap: () => _goTab(1),
            onBloodTap: () => _goTab(2)),
        CustomerAmbulanceFlow(user: user),
        CustomerBloodFlow(user: user),
        CustomerProfileTab(user: user, customerRow: _customerRow),
      ]),
      bottomNavigationBar: ResQBottomNav(
        currentIndex: _index,
        onTap: _goTab,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.local_shipping_rounded), label: 'Ambulance'),
          BottomNavigationBarItem(
              icon: Icon(Icons.water_drop_rounded), label: 'Blood'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// HOME TAB
// ══════════════════════════════════════════════════════════════════════════════
class CustomerHomeTab extends StatefulWidget {
  final AppUser user;
  final VoidCallback onAmbulanceTap, onBloodTap;
  const CustomerHomeTab({
    super.key,
    required this.user,
    required this.onAmbulanceTap,
    required this.onBloodTap,
  });
  @override
  State<CustomerHomeTab> createState() => _CustomerHomeTabState();
}

class _CustomerHomeTabState extends State<CustomerHomeTab>
    with SingleTickerProviderStateMixin {
  late AnimationController _listCtrl;
  static final _sb = Supabase.instance.client;

  // Real data
  int _totalRequests = 0;
  int _totalHelped = 0;
  List<Map<String, dynamic>> _recentActivity = [];
  bool _loadingStats = true;

  @override
  void initState() {
    super.initState();
    _listCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final userId = widget.user.id;

      // Count all blood requests by this customer
      final bloodReqs =
          await _sb.from('blood_requests').select().eq('customer_id', userId);

      // Count ambulance requests by this customer
      final ambReqs = await _sb
          .from('ambulance_requests')
          .select()
          .eq('customer_id', userId);

      final totalRequests =
          (bloodReqs as List).length + (ambReqs as List).length;

      // Count how many were fulfilled/matched
      final helped = (bloodReqs as List)
              .where(
                  (r) => r['status'] == 'matched' || r['status'] == 'completed')
              .length +
          (ambReqs as List)
              .where((r) =>
                  r['status'] == 'completed' || r['status'] == 'assigned')
              .length;

      // Recent activity — last 5 blood requests
      final recentBlood = await _sb
          .from('blood_requests')
          .select()
          .eq('customer_id', userId)
          .order('created_at', ascending: false)
          .limit(3);

      // Recent activity — last 2 ambulance requests
      final recentAmb = await _sb
          .from('ambulance_requests')
          .select()
          .eq('customer_id', userId)
          .order('created_at', ascending: false)
          .limit(2);

      // Combine and sort by date
      final combined = [
        ...(recentBlood as List).map(
            (r) => Map<String, dynamic>.from({...r as Map, '_type': 'blood'})),
        ...(recentAmb as List).map((r) =>
            Map<String, dynamic>.from({...r as Map, '_type': 'ambulance'})),
      ];
      combined.sort((a, b) => DateTime.parse(b['created_at'])
          .compareTo(DateTime.parse(a['created_at'])));

      if (mounted) {
        setState(() {
          _totalRequests = totalRequests;
          _totalHelped = helped;
          _recentActivity = combined.take(5).toList();
          _loadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  @override
  void dispose() {
    _listCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text('Customer Portal', style: AppTextStyles.heading(18)),
        ),
        body: RefreshIndicator(
          color: AppColors.red,
          onRefresh: () async {
            setState(() => _loadingStats = true);
            await _loadStats();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Request card
              Container(
                margin: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                decoration: BoxDecoration(
                  gradient: AppGradients.redCard,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black54,
                        offset: Offset(0, 4),
                        blurRadius: 12),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('WHAT DO YOU NEED?',
                            style:
                                AppTextStyles.label(color: AppColors.white40)),
                        const SizedBox(height: 4),
                        Text('Request Assistance',
                            style: AppTextStyles.bodyMedium(size: 17)),
                        const SizedBox(height: 14),
                        Row(children: [
                          Expanded(
                            child: AnimatedPressButton(
                              onTap: () {
                                Haptics.heavy();
                                widget.onAmbulanceTap();
                              },
                              child: ElevatedButton(
                                onPressed: () {
                                  Haptics.heavy();
                                  widget.onAmbulanceTap();
                                },
                                style: ElevatedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(46)),
                                child: const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.local_shipping_rounded,
                                              size: 16),
                                          SizedBox(width: 6),
                                          Text('Ambulance',
                                              style: TextStyle(fontSize: 14)),
                                        ])),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: AnimatedPressButton(
                              onTap: () {
                                Haptics.medium();
                                widget.onBloodTap();
                              },
                              child: OutlinedButton(
                                onPressed: () {
                                  Haptics.medium();
                                  widget.onBloodTap();
                                },
                                style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(46)),
                                child: const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.water_drop_rounded,
                                              size: 16, color: AppColors.red),
                                          SizedBox(width: 6),
                                          Text('Blood',
                                              style: TextStyle(
                                                  fontSize: 14,
                                                  color: AppColors.white)),
                                        ])),
                              ),
                            ),
                          ),
                        ]),
                      ]),
                ),
              ),

              // ── Real stat cards ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _loadingStats
                    ? Row(children: const [
                        Expanded(child: ShimmerBox(height: 70)),
                        SizedBox(width: 12),
                        Expanded(child: ShimmerBox(height: 70)),
                      ])
                    : Row(children: [
                        Expanded(
                            child: StatCard(
                          label: 'REQUESTS SENT',
                          value: _totalRequests.toString().padLeft(2, '0'),
                        )),
                        const SizedBox(width: 12),
                        Expanded(
                            child: StatCard(
                          label: 'HELPED BY',
                          value: _totalHelped.toString().padLeft(2, '0'),
                        )),
                      ]),
              ),
              const SizedBox(height: 14),

              // ── Alert banner — only show if there's recent activity ──
              if (!_loadingStats && _recentActivity.isNotEmpty)
                AlertBanner(
                  message: _recentActivity.first['_type'] == 'blood'
                      ? 'Last blood request: ${_recentActivity.first['status']}'
                      : 'Last ambulance request: ${_recentActivity.first['status']}',
                  color: AppColors.green,
                ),
              const SizedBox(height: 20),

              const SectionHeader(title: 'RECENT ACTIVITY'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _loadingStats
                    ? Column(
                        children: List.generate(
                            3,
                            (_) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: ShimmerBox(height: 66),
                                )))
                    : _recentActivity.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text('No requests yet',
                                  style: AppTextStyles.body(
                                      color: AppColors.white40)),
                            ),
                          )
                        : Column(
                            children: staggeredItems(
                              _recentActivity.map((r) {
                                final isBlood = r['_type'] == 'blood';
                                final date = DateTime.parse(r['created_at']);
                                final dateStr =
                                    '${_monthName(date.month)} ${date.day}';
                                final title = isBlood
                                    ? 'Blood Request — ${r['blood_type'] ?? ''}'
                                    : 'Ambulance Request';
                                final sub =
                                    r['status']?.toString().toUpperCase() ?? '';
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _actTile(
                                    dateStr,
                                    title,
                                    sub,
                                    isBlood
                                        ? Icons.water_drop_rounded
                                        : Icons.local_shipping_rounded,
                                    r['status'],
                                  ),
                                );
                              }).toList(),
                              controller: _listCtrl,
                            ),
                          ),
              ),
            ]),
          ),
        ),
      );

  String _monthName(int m) => const [
        '',
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
      ][m];

  Widget _actTile(String date, String title, String sub, IconData icon,
          String? status) =>
      Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          splashColor: AppColors.redDim,
          onTap: () => Haptics.light(),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black38, offset: Offset(0, 2), blurRadius: 6),
              ],
            ),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: AppColors.redDim,
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: AppColors.red, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: AppTextStyles.bodyMedium(size: 13),
                          overflow: TextOverflow.ellipsis),
                      Text(sub,
                          style: AppTextStyles.body(
                              size: 11, color: AppColors.white40),
                          overflow: TextOverflow.ellipsis),
                    ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Icon(
                  status == 'completed' || status == 'matched'
                      ? Icons.check_circle_rounded
                      : Icons.access_time_rounded,
                  color: status == 'completed' || status == 'matched'
                      ? AppColors.green
                      : AppColors.orange,
                  size: 15,
                ),
                const SizedBox(height: 2),
                Text(date,
                    style:
                        AppTextStyles.body(size: 10, color: AppColors.white40)),
              ]),
            ]),
          ),
        ),
      );
}
// ══════════════════════════════════════════════════════════════════════════════
// AMBULANCE FLOW
// ══════════════════════════════════════════════════════════════════════════════

enum _AmbStep { form, waiting, tracking, completed }

class CustomerAmbulanceFlow extends StatefulWidget {
  final AppUser user;
  const CustomerAmbulanceFlow({super.key, required this.user});
  @override
  State<CustomerAmbulanceFlow> createState() => _CustomerAmbulanceFlowState();
}

class _CustomerAmbulanceFlowState extends State<CustomerAmbulanceFlow> {
  _AmbStep _step = _AmbStep.form;
  AmbulanceRequest? _request;
  bool _loading = false;
  List<Map<String, dynamic>> _searchSuggestions = [];
  bool _searchingAddress = false;
  Timer? _searchDebounce;
  String? _emergencyType;
  String _severity = 'Medium';
  // DO NOT use LocationField widget — use plain TextField + manual geocoding
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // GPS state
  double _pickupLat = 24.8607;
  double _pickupLng = 67.0011;

  String _resolvedAddress = ''; // human-readable address
  bool _locationFetched = false;
  bool _fetchingLocation = false;

  // Request tracking for cancellation
  String? _pendingRequestId;

  final MapController _mapController = MapController();

  static const _emergencyTypes = [
    'Cardiac Arrest',
    'Road Accident',
    'Respiratory Emergency',
    'Stroke',
    'Severe Injury',
    'Other'
  ];
  static const _severities = ['Low', 'Medium', 'Critical'];

  Color _sevColor(String s) {
    if (s == 'Low') return AppColors.green;
    if (s == 'Critical') return AppColors.red;
    return AppColors.orange;
  }

  @override
  void initState() {
    super.initState();
    _autoDetectLocation(); // auto-detect on open
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // ── Core: detect GPS + reverse geocode + find hospital ──────────────────
  Future<void> _autoDetectLocation() async {
    setState(() => _fetchingLocation = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        if (mounted) setState(() => _fetchingLocation = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;

      setState(() {
        _pickupLat = pos.latitude;
        _pickupLng = pos.longitude;
        _locationFetched = true;
      });
      try {
        _mapController.move(LatLng(_pickupLat, _pickupLng), 15);
      } catch (_) {}

      // Only reverse geocode — NO hospital search
      final address = await HospitalLocationService.reverseGeocode(
          pos.latitude, pos.longitude);
      if (mounted) {
        setState(() {
          _resolvedAddress = address;
          if (_addressCtrl.text.isEmpty) _addressCtrl.text = address;
        });
      }
    } catch (e) {
      debugPrint('[_autoDetectLocation] $e');
    } finally {
      if (mounted) setState(() => _fetchingLocation = false);
    }
  }

  // Manual "detect my location" button tap
  Future<void> _detectLocationManually() async {
    setState(() {
      _fetchingLocation = true;
      _searchSuggestions = [];
    });
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        if (mounted) setState(() => _fetchingLocation = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;

      setState(() {
        _pickupLat = pos.latitude;
        _pickupLng = pos.longitude;
        _locationFetched = true;
      });
      try {
        _mapController.move(LatLng(_pickupLat, _pickupLng), 15);
      } catch (_) {}

      final address = await HospitalLocationService.reverseGeocode(
          pos.latitude, pos.longitude);
      if (mounted) {
        setState(() {
          _resolvedAddress = address;
          _addressCtrl.text = address;
        });
      }
    } catch (e) {
      debugPrint('[_detectLocationManually] $e');
    } finally {
      if (mounted) setState(() => _fetchingLocation = false);
    }
  }

  // ADD Nominatim forward-geocode search:
  Future<void> _searchAddress(String query) async {
    if (query.length < 3) {
      setState(() => _searchSuggestions = []);
      return;
    }
    setState(() => _searchingAddress = true);
    final suggestions = await HospitalLocationService.searchAddress(query);
    if (mounted) {
      setState(() {
        _searchSuggestions = suggestions;
        _searchingAddress = false;
      });
    }
  }

  void _selectSuggestion(Map<String, dynamic> suggestion) {
    final lat = suggestion['lat'] as double;
    final lng = suggestion['lng'] as double;
    final label = suggestion['label'] as String;
    setState(() {
      _pickupLat = lat;
      _pickupLng = lng;
      _locationFetched = true;
      _resolvedAddress = label;
      _addressCtrl.text = label;
      _searchSuggestions = [];
    });
    try {
      _mapController.move(LatLng(lat, lng), 15);
    } catch (_) {}
    // NO hospital search here anymore
  }

  // ── Submit ───────────────────────────────────────────────────────────────
  Future<void> _submitRequest() async {
    if (_emergencyType == null) {
      showErrorSnack(context, 'Select emergency type');
      Haptics.medium();
      return;
    }
    if (_addressCtrl.text.trim().isEmpty && !_locationFetched) {
      showErrorSnack(context, 'Enter or detect pickup location');
      Haptics.medium();
      return;
    }

    final address = _addressCtrl.text.trim().isNotEmpty
        ? _addressCtrl.text.trim()
        : _resolvedAddress.isNotEmpty
            ? _resolvedAddress
            : 'Location';

    Haptics.heavy();
    setState(() {
      _loading = true;
      _step = _AmbStep.waiting;
    });

    try {
      final req = await RequestService.submitAmbulanceRequest({
        'emergencyType': _emergencyType,
        'severity': _severity,
        'address': address,
        'notes': _notesCtrl.text,
        'pickupLat': _pickupLat,
        'pickupLng': _pickupLng,
        // No dropLat, dropLng, dropLocation — driver will set these
      });

      if (mounted) setState(() => _pendingRequestId = req.id);

      final matched = await RequestService.pollForMatch(req.id);
      if (!mounted) return;
      setState(() {
        _request = matched;
        _step = _AmbStep.tracking;
      });
    } on DriverNotFoundException catch (e) {
      if (mounted) {
        setState(() {
          _step = _AmbStep.form;
          _loading = false;
        });
        showErrorSnack(context, e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _step = _AmbStep.form;
          _loading = false;
        });
        showErrorSnack(context, 'Failed: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Cancel ───────────────────────────────────────────────────────────────
  Future<void> _reset() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Cancel Request?',
      message: 'Are you sure you want to cancel this ambulance request?',
      confirmLabel: 'Yes, Cancel',
      cancelLabel: 'Keep',
      danger: true,
    );
    if (ok == true) {
      if (_pendingRequestId != null) {
        try {
          await Supabase.instance.client
              .from('ambulance_requests')
              .update({
                'status': 'cancelled',
                'completed_at': DateTime.now().toUtc().toIso8601String(),
              })
              .eq('id', _pendingRequestId!)
              .eq('status', 'waiting');
        } catch (e) {
          debugPrint('[_reset] cancel error: $e');
        }
        _pendingRequestId = null;
      }
      if (mounted) {
        setState(() {
          _step = _AmbStep.form;
          _request = null;
          _emergencyType = null;
          _severity = 'Medium';
          _addressCtrl.clear();
          _notesCtrl.clear();
        });
      }
    }
  }

  void _completeRide() => setState(() => _step = _AmbStep.completed);

  // ═══════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case _AmbStep.form:
        return _formScreen();
      case _AmbStep.waiting:
        return _waitingScreen();
      case _AmbStep.tracking:
        return _trackingScreen();
      case _AmbStep.completed:
        return _completedScreen();
    }
  }

  Widget _formScreen() => Scaffold(
        appBar: const ResQAppBar(title: 'Ambulance Request', showBack: false),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Emergency type ──
            Text('EMERGENCY TYPE', style: AppTextStyles.label()),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.white08),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  dropdownColor: AppColors.surface2,
                  value: _emergencyType,
                  hint: Text('Select emergency type...',
                      style: AppTextStyles.body(
                          size: 14, color: AppColors.white40)),
                  icon: const Icon(Icons.keyboard_arrow_down,
                      color: AppColors.white40),
                  items: _emergencyTypes
                      .map((e) => DropdownMenuItem(
                          value: e,
                          child: Text(e, style: AppTextStyles.body(size: 14))))
                      .toList(),
                  onChanged: (v) {
                    Haptics.light();
                    setState(() => _emergencyType = v);
                  },
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Severity ──
            Text('SEVERITY LEVEL', style: AppTextStyles.label()),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.white08)),
              child: Row(
                children: _severities.map((s) {
                  final sel = _severity == s;
                  final c = _sevColor(s);
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Haptics.light();
                        setState(() => _severity = s);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          color: sel
                              ? c.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                          border: sel
                              ? Border.all(color: c.withValues(alpha: 0.5))
                              : null,
                        ),
                        child: Text(s,
                            style: AppTextStyles.bodyMedium(
                                size: 13, color: sel ? c : AppColors.white40)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 20),

            // ── Pickup location with suggestions ──────────────────────────────
            Text('PICKUP LOCATION', style: AppTextStyles.label()),
            const SizedBox(height: 8),
            TextField(
              controller: _addressCtrl,
              style: AppTextStyles.body(size: 14),
              onChanged: (val) {
                // Debounce search
                _searchDebounce?.cancel();
                _searchDebounce = Timer(const Duration(milliseconds: 600), () {
                  if (val.trim().length >= 3)
                    _searchAddress(val.trim());
                  else
                    setState(() => _searchSuggestions = []);
                });
              },
              decoration: InputDecoration(
                hintText: _fetchingLocation
                    ? 'Detecting location...'
                    : 'Type or detect location',
                hintStyle:
                    AppTextStyles.body(size: 14, color: AppColors.white40),
                prefixIcon: const Icon(Icons.location_on_outlined,
                    color: AppColors.red, size: 20),
                suffixIcon: _fetchingLocation
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.red)))
                    : IconButton(
                        icon: const Icon(Icons.my_location,
                            color: AppColors.red, size: 20),
                        tooltip: 'Use my current location',
                        onPressed: _detectLocationManually,
                      ),
              ),
            ),
            // Search suggestions dropdown
            if (_searchSuggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.white08),
                ),
                child: Column(
                  children: _searchSuggestions
                      .map((s) => InkWell(
                            onTap: () => _selectSuggestion(s),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              child: Row(children: [
                                const Icon(Icons.place_outlined,
                                    color: AppColors.white40, size: 16),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: Text(s['label'] as String,
                                        style: AppTextStyles.body(size: 13),
                                        overflow: TextOverflow.ellipsis)),
                              ]),
                            ),
                          ))
                      .toList(),
                ),
              ),
            if (_searchingAddress)
              Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Searching...',
                      style: AppTextStyles.body(
                          size: 11, color: AppColors.white40))),
            const SizedBox(height: 10),

            // ── Map with expand button ──
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(children: [
                SizedBox(
                  height: 160,
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: LatLng(_pickupLat, _pickupLng),
                      initialZoom: 15,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.resqlink.app',
                        maxNativeZoom: 18,
                        keepBuffer: 4,
                      ),
                      MarkerLayer(markers: [
                        Marker(
                            point: LatLng(_pickupLat, _pickupLng),
                            width: 40,
                            height: 40,
                            child: const Icon(Icons.location_on,
                                color: AppColors.red, size: 36)),
                      ]),
                    ],
                  ),
                ),
                // Expand button
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _FullscreenMapScreen(
                            lat: _pickupLat,
                            lng: _pickupLng,
                          ),
                        )),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(6)),
                      child: const Icon(Icons.fullscreen,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ),
                // Hospital chip
              ]),
            ),

            if (_fetchingLocation)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Detecting your location...',
                    style:
                        AppTextStyles.body(size: 11, color: AppColors.white40)),
              ),

            const SizedBox(height: 20),

            // ── Notes ──
            Text('ADDITIONAL DETAILS', style: AppTextStyles.label()),
            const SizedBox(height: 8),
            TextField(
              controller: _notesCtrl,
              maxLines: 3,
              style: AppTextStyles.body(size: 14),
              decoration: InputDecoration(
                hintText: 'Briefly describe the situation...',
                hintStyle:
                    AppTextStyles.body(size: 14, color: AppColors.white40),
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: 28),

            AnimatedPressButton(
              onTap: _loading ? null : _submitRequest,
              child: ElevatedButton(
                onPressed: _loading ? null : _submitRequest,
                child: Row(mainAxisSize: MainAxisSize.min, children: const [
                  Icon(Icons.local_shipping_rounded, size: 18),
                  SizedBox(width: 8),
                  Text('Request Now'),
                ]),
              ),
            ),
          ]),
        ),
      );

//waiting screen
  Widget _waitingScreen() => Scaffold(
        appBar: const ResQAppBar(title: 'Finding Driver', showBack: false),
        body: Column(children: [
          Expanded(
              child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: 90,
              height: 90,
              child: Stack(alignment: Alignment.center, children: [
                Container(
                    decoration: BoxDecoration(
                        color: AppColors.redDim,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.redMid))),
                const CircularProgressIndicator(
                    color: AppColors.red, strokeWidth: 2.5),
              ]),
            ),
            const SizedBox(height: 28),
            Text('Finding nearest driver...', style: AppTextStyles.heading(18)),
            const SizedBox(height: 8),
            Text('Please keep your phone close',
                style: AppTextStyles.body(size: 13, color: AppColors.white40)),
            const SizedBox(height: 16),
            const ShimmerList(itemCount: 2, itemHeight: 64),
          ]))),
          Padding(
            padding: const EdgeInsets.fromLTRB(40, 0, 40, 32),
            child: OutlinedButton(
              onPressed: _reset,
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46)),
              child: const Text('Cancel Request'),
            ),
          ),
        ]),
      );

  Widget _trackingScreen() {
    // ═══════════════════════════════════════════════════════════════════
    // FIX 4: DEBUG LOGGING — Check console for real data
    // ═══════════════════════════════════════════════════════════════════
    debugPrint('\n🚑 [CUSTOMER TRACKING DEBUG] =========================');
    debugPrint('Request ID: ${_request?.id}');
    debugPrint(
        'Driver Name: ${_request?.assignedDriverName ?? "NULL/MISSING"}');
    debugPrint(
        'Driver Phone: ${_request?.assignedDriverPhone ?? "NULL/MISSING"}');
    debugPrint('ETA: ${_request?.eta ?? "NULL/MISSING"}');
    debugPrint(
        'Pickup Coords: (${_request?.pickupLat}, ${_request?.pickupLng})');
    debugPrint('Drop Coords: (${_request?.dropLat}, ${_request?.dropLng})');
    debugPrint('Drop Location: ${_request?.dropLocation ?? "NULL"}');
    debugPrint('=====================================================\n');
    // ═══════════════════════════════════════════════════════════════════

    return Scaffold(
      body: Stack(children: [
        SizedBox.expand(
          child: FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(_pickupLat, _pickupLng),
              initialZoom: 15,
              interactionOptions:
                  const InteractionOptions(flags: InteractiveFlag.all),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.resqlink.app',
                maxNativeZoom: 18,
                keepBuffer: 4,
              ),
              MarkerLayer(markers: [
                Marker(
                    point: LatLng(_pickupLat, _pickupLng),
                    width: 44,
                    height: 44,
                    child: const Icon(Icons.location_on,
                        color: AppColors.red, size: 40)),
                Marker(
                    point: LatLng(_pickupLat + 0.008, _pickupLng + 0.006),
                    width: 44,
                    height: 44,
                    child: Container(
                      decoration: const BoxDecoration(
                          color: AppColors.red, shape: BoxShape.circle),
                      child: const Icon(Icons.local_shipping_rounded,
                          color: AppColors.white, size: 22),
                    )),
              ]),
            ],
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: const Color(0xFF2D2222),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.white08)),
            child: Row(children: [
              Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: AppColors.red,
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.emergency,
                      color: AppColors.white, size: 20)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                    Text('DRIVER',
                        style: AppTextStyles.label(color: AppColors.white40)),
                    Text(_request?.assignedDriverName ?? 'Driver',
                        style: AppTextStyles.bodyMedium(size: 15),
                        overflow: TextOverflow.ellipsis),
                  ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('ETA',
                    style: AppTextStyles.label(color: AppColors.white40)),
                Text(_request?.eta ?? '8 MIN',
                    style: AppTextStyles.heading(18, color: AppColors.red)),
                const SizedBox(height: 8),
                // ── CALL DRIVER BUTTON ──────────────────────────────────────
                Semantics(
                  label: 'Call driver',
                  button: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    splashColor: AppColors.redDim,
                    onTap: () async {
                      Haptics.light();
                      // Use real driver phone from request
                      final phone = _request?.assignedDriverPhone;
                      if (phone == null || phone.isEmpty) {
                        showErrorSnack(context, 'Driver phone not available');
                        return;
                      }
                      final uri = Uri.parse('tel:$phone');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      } else {
                        showErrorSnack(context, 'Could not launch phone app');
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.green.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.phone_outlined,
                              color: AppColors.green, size: 14),
                          const SizedBox(width: 4),
                          Text('Call',
                              style: AppTextStyles.body(
                                  size: 11, color: AppColors.green)),
                        ],
                      ),
                    ),
                  ),
                ),
              ]),
            ]),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
            decoration: const BoxDecoration(
                color: Color(0xFF1A1212),
                borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                      child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color: AppColors.white15,
                              borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),
                  Text('• SEVERITY: ${_severity.toUpperCase()}',
                      style: AppTextStyles.label(color: AppColors.red)),
                  const SizedBox(height: 8),
                  Text(
                      _addressCtrl.text.isNotEmpty
                          ? _addressCtrl.text
                          : 'Your location',
                      style: AppTextStyles.heading(17),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 16),
                  AnimatedPressButton(
                    onTap: () {
                      Haptics.heavy();
                      _completeRide();
                    },
                    child: ElevatedButton(
                      onPressed: () {
                        Haptics.heavy();
                        _completeRide();
                      },
                      child: const Text('Request Completed ✓'),
                    ),
                  ),
                ]),
          ),
        ),
      ]),
    );
  }

  Widget _completedScreen() => Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const SizedBox(height: 32),
              Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: AppColors.redDim,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.redMid, width: 2),
                  ),
                  child: const Icon(Icons.check_circle_rounded,
                      color: AppColors.red, size: 52)),
              const SizedBox(height: 20),
              Text('Request Completed', style: AppTextStyles.heading(24)),
              const SizedBox(height: 8),
              Text('Help is on the way. Stay calm.',
                  textAlign: TextAlign.center,
                  style:
                      AppTextStyles.body(size: 14, color: AppColors.white40)),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: AppDecorations.card,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('REQUEST SUMMARY',
                          style: AppTextStyles.label(color: AppColors.red)),
                      const SizedBox(height: 14),
                      _summaryRow(
                          'Driver', _request?.assignedDriverName ?? '—'),
                      _summaryRow('Emergency', _emergencyType ?? '—'),
                      _summaryRow('Severity', _severity),
                      _summaryRow('ETA', _request?.eta ?? '—'),
                    ]),
              ),
              const SizedBox(height: 28),
              AnimatedPressButton(
                onTap: () => setState(() {
                  _step = _AmbStep.form;
                  _request = null;
                  _emergencyType = null;
                  _severity = 'Medium';
                  _addressCtrl.clear();
                  _notesCtrl.clear();

                  _pendingRequestId = null;
                }),
                child: ElevatedButton(
                  onPressed: () => setState(() {
                    _step = _AmbStep.form;
                    _request = null;
                    _emergencyType = null;
                    _severity = 'Medium';
                    _addressCtrl.clear();
                    _notesCtrl.clear();

                    _pendingRequestId = null;
                  }),
                  child: const Text('Back to Home'),
                ),
              ),
            ]),
          ),
        ),
      );

  Widget _summaryRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label,
              style: AppTextStyles.body(size: 13, color: AppColors.white40)),
          Flexible(
              child: Text(value,
                  style: AppTextStyles.bodyMedium(size: 13),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end)),
        ]),
      );
}
// ══════════════════════════════════════════════════════════════════════════════
// BLOOD FLOW
// ══════════════════════════════════════════════════════════════════════════════

enum _BloodStep { form, waiting, matched, completed }

class CustomerBloodFlow extends StatefulWidget {
  final AppUser user;
  const CustomerBloodFlow({super.key, required this.user});
  @override
  State<CustomerBloodFlow> createState() => _CustomerBloodFlowState();
}

class _CustomerBloodFlowState extends State<CustomerBloodFlow> {
  _BloodStep _step = _BloodStep.form;
  String _bloodGroup = 'A+', _priority = 'Urgent';
  bool _loading = false;
  String? _matchedRequestId;
  String _matchedDonorName = '';
  String _matchedDonorPhone = '';
  final _hospitalCtrl = TextEditingController();
  final _unitsCtrl = TextEditingController();

  // Live GPS coordinates — default: Karachi
  double _latitude = 24.8607;
  double _longitude = 67.0011;
  LatLng? _customerLocation;
  bool _detectingLocation = false;

  static const _groups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) return;
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
      });
    } catch (_) {}
  }

  String _formatAddress(Map<String, dynamic> addr) {
    final parts = <String>[];
    // Priority order for address components
    if (addr['hospital'] != null) parts.add(addr['hospital']);
    if (addr['road'] != null) parts.add(addr['road']);
    if (addr['suburb'] != null) parts.add(addr['suburb']);
    if (addr['city'] != null) parts.add(addr['city']);
    if (addr['state'] != null) parts.add(addr['state']);
    if (addr['postcode'] != null) parts.add(addr['postcode']);
    if (addr['country'] != null) parts.add(addr['country']);

    return parts.isNotEmpty ? parts.join(', ') : 'Location detected';
  }

  Future<void> _detectLocation() async {
    setState(() => _detectingLocation = true);
    try {
      // 1. Get permission and GPS coordinates
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        if (mounted) setState(() => _detectingLocation = false);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;

      // 2. Reverse geocode with better address extraction
      String addressText = 'Detecting address...';
      try {
        final geoUri = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse'
          '?format=json'
          '&lat=${pos.latitude}'
          '&lon=${pos.longitude}'
          '&zoom=18'
          '&addressdetails=1'
          '&layer=address', // Prioritize street-level addresses
        );
        final geoRes = await http.get(
          geoUri,
          headers: {'User-Agent': 'ResQLink/1.0'},
        );
        if (geoRes.statusCode == 200) {
          final data = jsonDecode(geoRes.body);
          final addr = data['address'] as Map? ?? {};

          // Try multiple strategies to get specific address
          String? specificAddress;

          // Strategy 1: Use display_name (usually most complete)
          final displayName = data['display_name'] as String?;
          if (displayName != null && displayName.isNotEmpty) {
            // Extract first 2-3 parts before "Pakistan" for cleaner display
            final parts = displayName.split(',');
            if (parts.length > 2) {
              // Take everything except the last "Pakistan" part
              specificAddress =
                  parts.sublist(0, parts.length - 1).join(',').trim();
            } else {
              specificAddress = displayName;
            }
          }

          // Strategy 2: Build from specific fields if display_name is too generic
          if (specificAddress == null ||
              specificAddress.contains('Division') ||
              specificAddress.contains('Karachi Division')) {
            final parts = <String>[];

            // Priority order for most specific to least specific
            if (addr['house_number'] != null) parts.add(addr['house_number']);
            if (addr['road'] != null) parts.add(addr['road']);
            if (addr['neighbourhood'] != null) parts.add(addr['neighbourhood']);
            if (addr['suburb'] != null) parts.add(addr['suburb']);
            if (addr['quarter'] != null) parts.add(addr['quarter']);
            if (addr['city_district'] != null) parts.add(addr['city_district']);
            if (addr['borough'] != null) parts.add(addr['borough']);

            // Only add city if we have more specific info
            if (parts.isNotEmpty && addr['city'] != null) {
              parts.add(addr['city']!);
            } else if (parts.isEmpty && addr['city'] != null) {
              // Fallback to city if nothing else
              parts.add(addr['city']!);
            }

            if (addr['state'] != null) parts.add(addr['state']);

            specificAddress = parts.isNotEmpty
                ? parts.join(', ')
                : 'Karachi, Pakistan'; // Final fallback
          }

          addressText = specificAddress;

          // Debug: Print what we got
          debugPrint('📍 Reverse geocode result: $addressText');
          debugPrint('📍 Full address data: $addr');
        }
      } catch (e) {
        debugPrint('❌ Reverse geocoding error: $e');
        // Fallback to coordinates
        addressText =
            '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
      }

      // 3. Update UI
      if (mounted) {
        setState(() {
          _latitude = pos.latitude;
          _longitude = pos.longitude;
          _customerLocation = LatLng(pos.latitude, pos.longitude);
          _hospitalCtrl.text = addressText;
          _detectingLocation = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Location error: $e');
      if (mounted) setState(() => _detectingLocation = false);
    }
  }

  Widget _infoRow(IconData icon, String label, String value) => Row(
        children: [
          Icon(icon, color: AppColors.red, size: 16),
          const SizedBox(width: 10),
          Text('$label  ',
              style: AppTextStyles.body(size: 13, color: AppColors.white40)),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodyMedium(size: 13),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      );

  @override
  void dispose() {
    _hospitalCtrl.dispose();
    _unitsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_hospitalCtrl.text.trim().isEmpty) {
      showErrorSnack(context, 'Enter or detect hospital / location');
      Haptics.medium();
      return;
    }
    Haptics.heavy();
    setState(() {
      _loading = true;
      _step = _BloodStep.waiting;
    });
    try {
      final req = await RequestService.submitBloodRequest({
        'bloodType': _bloodGroup,
        'priority': _priority,
        'hospital': _hospitalCtrl.text,
        'address': _hospitalCtrl.text, // same field for now
        'units': int.tryParse(_unitsCtrl.text) ?? 1,
        'latitude': _latitude,
        'longitude': _longitude,
        'urgency_level': _priority == 'Urgent' ? 'URGENT' : 'STANDARD',
      });
      if (!mounted) return;
      setState(() {
        _loading = false;
        _matchedRequestId = req.id; // ← save immediately so cancel can use it
      });
      _pollForDonor(req.id);
    } catch (e) {
      if (mounted) {
        setState(() {
          _step = _BloodStep.form;
          _loading = false;
        });
        showErrorSnack(
            context, 'Failed: ${e.toString().replaceFirst("Exception: ", "")}');
      }
    }
  }

// Add this NEW function right below _submit()
  void _pollForDonor(String requestId) {
    int attempts = 0;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted || _step != _BloodStep.waiting) return false;
      attempts++;
      if (attempts > 100) {
        // 5 minutes timeout
        if (mounted) {
          setState(() => _step = _BloodStep.form);
          showErrorSnack(context, 'No donor found. Please try again.');
        }
        return false;
      }
      try {
        final sb = Supabase.instance.client;
        final row = await sb
            .from('blood_requests')
            .select('status')
            .eq('id', requestId)
            .single();
        final status = row['status'] as String? ?? '';
        if (status == 'matched' && mounted) {
          // Fetch the donor's real name and phone
          try {
            final sb = Supabase.instance.client;
            final fullRow = await sb
                .from('blood_requests')
                .select('donor_id')
                .eq('id', requestId)
                .single();
            final donorId = fullRow['donor_id'] as String?;
            if (donorId != null) {
              final donorProfile = await sb
                  .from('profiles')
                  .select('name, phone')
                  .eq('id', donorId)
                  .single();
              if (mounted) {
                setState(() {
                  _matchedDonorName =
                      donorProfile['name'] as String? ?? 'Donor';
                  _matchedDonorPhone = donorProfile['phone'] as String? ?? '';
                  _matchedRequestId = requestId;
                  _step = _BloodStep.matched;
                });
              }
            } else {
              if (mounted) setState(() => _step = _BloodStep.matched);
            }
          } catch (_) {
            if (mounted) setState(() => _step = _BloodStep.matched);
          }
          return false;
        }
      } catch (_) {}
      return true; // keep polling
    });
  }

  void _complete() => setState(() => _step = _BloodStep.completed);

  Future<void> _reset() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Cancel Blood Request?',
      message: 'This will cancel your current blood request.',
      confirmLabel: 'Yes, Cancel',
      cancelLabel: 'Keep',
      danger: true,
    );
    if (ok == true) {
      // Cancel in DB if we have a request ID
      if (_matchedRequestId != null) {
        try {
          await Supabase.instance.client.from('blood_requests').update(
              {'status': 'cancelled'}).eq('id', int.parse(_matchedRequestId!));
        } catch (e) {
          debugPrint('[Cancel] failed to cancel in DB: $e');
        }
      }
      if (mounted) {
        setState(() {
          _step = _BloodStep.form;
          _matchedRequestId = null;
          _matchedDonorName = '';
          _matchedDonorPhone = '';
          _hospitalCtrl.clear();
          _unitsCtrl.clear();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case _BloodStep.form:
        return _formScreen();
      case _BloodStep.waiting:
        return _waitingScreen();
      case _BloodStep.matched:
        return _matchedScreen();
      case _BloodStep.completed:
        return _completedScreen();
    }
  }

  Widget _formScreen() => Scaffold(
        appBar: const ResQAppBar(title: 'Blood Request', showBack: false),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: AppColors.redDim,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.redMid)),
                child: Row(children: [
                  const Icon(Icons.water_drop_rounded,
                      color: AppColors.red, size: 28),
                  const SizedBox(width: 12),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Blood Request',
                            style: AppTextStyles.bodyMedium(size: 16)),
                        Text('Fill in the details below',
                            style: AppTextStyles.body(
                                size: 12, color: AppColors.white40)),
                      ]),
                ]),
              ),
              const SizedBox(height: 24),

              // Blood group
              Text('SELECT BLOOD GROUP', style: AppTextStyles.label()),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.3),
                itemCount: _groups.length,
                itemBuilder: (_, i) {
                  final g = _groups[i];
                  final sel = g == _bloodGroup;
                  return GestureDetector(
                    onTap: () => setState(() => _bloodGroup = g),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: sel ? AppColors.red : AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: sel ? AppColors.red : AppColors.white08,
                              width: sel ? 2 : 1),
                          boxShadow: sel
                              ? [
                                  BoxShadow(
                                      color: AppColors.red.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2))
                                ]
                              : null),
                      child: Text(g,
                          style: AppTextStyles.bodyMedium(
                              size: 14,
                              color: sel ? Colors.white : AppColors.white70)),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Priority
              Text('URGENCY LEVEL', style: AppTextStyles.label()),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.white08)),
                child: Row(
                  children: ['Normal', 'Urgent'].map((p) {
                    final sel = _priority == p;
                    final color =
                        p == 'Urgent' ? AppColors.red : AppColors.green;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _priority = p),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                              color: sel
                                  ? color.withOpacity(0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                              border: sel
                                  ? Border.all(color: color.withOpacity(0.5))
                                  : null),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                  p == 'Urgent'
                                      ? Icons.priority_high_rounded
                                      : Icons.check_circle_outline,
                                  color: sel ? color : AppColors.white40,
                                  size: 16),
                              const SizedBox(width: 6),
                              Text(p,
                                  style: AppTextStyles.bodyMedium(
                                      size: 13,
                                      color: sel ? color : AppColors.white40)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              // Hospital
              Text('HOSPITAL / LOCATION', style: AppTextStyles.label()),
              const SizedBox(height: 8),
              TextField(
                controller: _hospitalCtrl,
                style: AppTextStyles.body(size: 14),
                decoration: InputDecoration(
                    hintText: 'Enter hospital name or address...',
                    hintStyle:
                        AppTextStyles.body(size: 14, color: AppColors.white40),
                    prefixIcon: const Icon(Icons.local_hospital_outlined,
                        color: AppColors.red, size: 20)),
              ),
              const SizedBox(height: 12),

              // Detect location button
              GestureDetector(
                onTap: _loading ? null : _detectLocation,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.white08)),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: AppColors.redDim,
                          borderRadius: BorderRadius.circular(8)),
                      child: _detectingLocation
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  color: AppColors.red, strokeWidth: 2))
                          : const Icon(Icons.my_location,
                              color: AppColors.red, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Use Current Location',
                                style: AppTextStyles.bodyMedium(size: 13)),
                            Text(
                                _customerLocation != null
                                    ? 'Location detected ✓'
                                    : 'Tap to auto-fill your location',
                                style: AppTextStyles.body(
                                    size: 11,
                                    color: _customerLocation != null
                                        ? AppColors.green
                                        : AppColors.white40)),
                          ]),
                    ),
                    const Icon(Icons.chevron_right,
                        color: AppColors.white40, size: 20),
                  ]),
                ),
              ),

              // Mini map if location detected
              if (_customerLocation != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: 130,
                    child: FlutterMap(
                      options: MapOptions(
                          initialCenter: _customerLocation!, initialZoom: 15),
                      children: [
                        TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.resqlink.app'),
                        MarkerLayer(markers: [
                          Marker(
                              point: _customerLocation!,
                              width: 36,
                              height: 36,
                              child: const Icon(Icons.location_on,
                                  color: AppColors.red, size: 36)),
                        ]),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Units
              Text('UNITS REQUIRED', style: AppTextStyles.label()),
              const SizedBox(height: 8),
              TextField(
                controller: _unitsCtrl,
                keyboardType: TextInputType.number,
                style: AppTextStyles.body(size: 14),
                decoration: InputDecoration(
                    hintText: 'Number of blood bags needed...',
                    hintStyle:
                        AppTextStyles.body(size: 14, color: AppColors.white40),
                    prefixIcon: const Icon(Icons.bloodtype_outlined,
                        color: AppColors.red, size: 20)),
              ),
              const SizedBox(height: 32),

              // Submit button
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.water_drop_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Submit Blood Request',
                        style: TextStyle(fontSize: 15)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _waitingScreen() => Scaffold(
        appBar: const ResQAppBar(title: 'Finding Donors', showBack: false),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(alignment: Alignment.center, children: [
                Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                        color: AppColors.redDim,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.redMid, width: 2))),
                const CircularProgressIndicator(
                    color: AppColors.red, strokeWidth: 3),
                const Icon(Icons.water_drop_rounded,
                    color: AppColors.red, size: 36),
              ]),
              const SizedBox(height: 32),
              Text('Searching for $_bloodGroup donors...',
                  style: AppTextStyles.heading(18),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('We\'ll notify you as soon as a donor accepts',
                  style: AppTextStyles.body(size: 13, color: AppColors.white40),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: AppDecorations.card,
                child: Column(children: [
                  _infoRow(Icons.water_drop_rounded, 'Blood Type', _bloodGroup),
                  const Divider(color: AppColors.white08, height: 20),
                  _infoRow(Icons.local_hospital_outlined, 'Location',
                      _hospitalCtrl.text),
                  const Divider(color: AppColors.white08, height: 20),
                  _infoRow(Icons.priority_high_rounded, 'Priority', _priority),
                ]),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: _reset,
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
                child: const Text('Cancel Request'),
              ),
            ],
          ),
        ),
      );

  Widget _matchedScreen() => Scaffold(
        appBar: const ResQAppBar(title: 'Donor Matched', showBack: false),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const SizedBox(height: 20),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border:
                    Border.all(color: AppColors.green.withValues(alpha: 0.4)),
              ),
              child: const Icon(Icons.volunteer_activism,
                  color: AppColors.green, size: 40),
            ),
            const SizedBox(height: 16),
            Text('Donor Found!',
                style: AppTextStyles.heading(24, color: AppColors.green)),
            const SizedBox(height: 8),
            Text('A donor has accepted your request and is on the way.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body(size: 14, color: AppColors.white40)),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: AppDecorations.card,
              child: Row(children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.redDim,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.redMid),
                  ),
                  child: Center(
                      child: Text(_bloodGroup,
                          style: AppTextStyles.bodyMedium(
                              size: 13, color: AppColors.red))),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _matchedDonorName.isNotEmpty
                            ? _matchedDonorName
                            : 'Donor',
                        style: AppTextStyles.bodyMedium(size: 15),
                      ),
                      Text(
                        'On the way to your location',
                        style: AppTextStyles.body(
                            size: 13, color: AppColors.white40),
                      ),
                    ],
                  ),
                ),
                // Clickable phone
                Semantics(
                  label: 'Call donor',
                  button: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    splashColor: AppColors.redDim,
                    onTap: () async {
                      Haptics.light();
                      final uri = Uri.parse('tel:$_matchedDonorPhone');
                      if (_matchedDonorPhone.isEmpty)
                        return; // don't call if no phone
                      if (await canLaunchUrl(uri)) launchUrl(uri);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppColors.white08,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.phone_outlined,
                          color: AppColors.red, size: 18),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            // ── REAL MAP: donor location preview ──
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 130,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(_latitude, _longitude),
                    initialZoom: 14,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.resqlink.app',
                    ),
                    MarkerLayer(
                      markers: [
                        // Patient location
                        Marker(
                          point: LatLng(_latitude, _longitude),
                          width: 36,
                          height: 36,
                          child: const Icon(Icons.location_on,
                              color: AppColors.red, size: 32),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            AnimatedPressButton(
              onTap: () {
                Haptics.heavy();
                _complete();
              },
              child: ElevatedButton(
                onPressed: () {
                  Haptics.heavy();
                  _complete();
                },
                child: const Text('Mark as Received'),
              ),
            ),
          ]),
        ),
      );

  Widget _completedScreen() => Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const SizedBox(height: 40),
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: AppColors.redDim,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.redMid, width: 2),
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: AppColors.red, size: 52),
              ),
              const SizedBox(height: 20),
              Text('Donation Received', style: AppTextStyles.heading(24)),
              const SizedBox(height: 8),
              Text('Thank you. Your request has been fulfilled.',
                  textAlign: TextAlign.center,
                  style:
                      AppTextStyles.body(size: 14, color: AppColors.white40)),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.redDim,
                  borderRadius: BorderRadius.circular(12),
                  border: const Border(
                      left: BorderSide(color: AppColors.red, width: 3)),
                ),
                child: Text(
                    '"Every donation is a beacon of hope for someone in urgent need."',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(size: 13, color: AppColors.red)
                        .copyWith(fontStyle: FontStyle.italic)),
              ),
              const SizedBox(height: 28),
              AnimatedPressButton(
                onTap: () => setState(() {
                  _step = _BloodStep.form;
                  _hospitalCtrl.clear();
                  _unitsCtrl.clear();
                }),
                child: ElevatedButton(
                  onPressed: () => setState(() {
                    _step = _BloodStep.form;
                    _hospitalCtrl.clear();
                    _unitsCtrl.clear();
                  }),
                  child: const Text('Back to Home'),
                ),
              ),
            ]),
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// PROFILE TAB
// ══════════════════════════════════════════════════════════════════════════════

class CustomerProfileTab extends StatefulWidget {
  final AppUser user;
  final Map<String, dynamic>? customerRow;
  const CustomerProfileTab({super.key, required this.user, this.customerRow});
  @override
  State<CustomerProfileTab> createState() => _CustomerProfileTabState();
}

class _CustomerProfileTabState extends State<CustomerProfileTab> {
  static final _sb = Supabase.instance.client;

  bool _notifications = true, _shareLocation = true;
  bool _loading = false;
  bool _initialLoading = true;
  bool _editMode = false;
  bool _uploadingPhoto = false;
  String? _avatarUrl;

  Map<String, dynamic>? _profileData;
  Map<String, dynamic>? _customerData;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _addressCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _phoneCtrl, _emailCtrl, _addressCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final authUser = _sb.auth.currentUser;
      if (authUser == null) {
        if (mounted) setState(() => _initialLoading = false);
        return;
      }

      // 1. Fetch profiles row
      final profile =
          await _sb.from('profiles').select().eq('id', authUser.id).single();

      // 2. Fetch customer_data row (profiles.id = customer_data.customer_id)
      final customerData = await _sb
          .from('customer_data')
          .select()
          .eq('customer_id', authUser.id)
          .maybeSingle();

      if (!mounted) return;
      setState(() {
        _profileData = profile;
        _avatarUrl = profile['avatar_url'] as String?;
        _customerData = customerData;
        _nameCtrl.text = profile['name'] as String? ?? widget.user.name;
        _phoneCtrl.text = profile['phone'] as String? ?? widget.user.phone;
        _emailCtrl.text = profile['email'] as String? ?? widget.user.email;
        _addressCtrl.text =
            customerData?['address'] as String? ?? widget.user.location ?? '';
        _initialLoading = false;
      });
    } catch (e) {
      debugPrint('[CustomerProfile] _loadProfile error: $e');
      if (mounted) {
        _nameCtrl.text = widget.user.name;
        _phoneCtrl.text = widget.user.phone;
        _emailCtrl.text = widget.user.email;
        _addressCtrl.text = widget.user.location ?? '';
        setState(() => _initialLoading = false);
      }
    }
  }

  Future<void> _save() async {
    Haptics.heavy();
    setState(() => _loading = true);
    try {
      final userId = _sb.auth.currentUser?.id ?? widget.user.id;

      // Update profiles table — email is read-only, never sent
      await _sb.from('profiles').update({
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
      }).eq('id', userId);

      // Upsert customer_data table for address
      await _sb.from('customer_data').upsert({
        'customer_id': userId,
        'address': _addressCtrl.text.trim(),
      }, onConflict: 'customer_id');

      if (mounted) showSuccessSnack(context, 'Profile updated!');
    } catch (e) {
      if (mounted) showErrorSnack(context, 'Save failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changePhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;
    setState(() => _uploadingPhoto = true);
    try {
      final userId = _sb.auth.currentUser?.id ?? widget.user.id;
      final url = await StorageService.uploadAvatar(userId, File(picked.path));
      final freshUrl = '$url?t=${DateTime.now().millisecondsSinceEpoch}';
      if (mounted) {
        setState(() => _avatarUrl = freshUrl);
        showSuccessSnack(context, 'Photo updated!');
      }
    } catch (e) {
      if (mounted) showErrorSnack(context, 'Upload failed: $e');
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _logout() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Sign Out?',
      message: 'You will be returned to the login screen.',
      confirmLabel: 'Sign Out',
      cancelLabel: 'Cancel',
      danger: true,
    );
    if (ok == true) {
      await AuthService.logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
            context, fadeRoute(const LoginScreen()), (_) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoading) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: const Center(
            child: CircularProgressIndicator(
                color: AppColors.red, strokeWidth: 2)),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          // ── Hero header ──────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: AppColors.bg,
            automaticallyImplyLeading: false,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: IconButton(
                  onPressed: () {
                    Haptics.light();
                    setState(() => _editMode = !_editMode);
                  },
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      _editMode ? Icons.check_rounded : Icons.edit_outlined,
                      key: ValueKey(_editMode),
                      color: _editMode ? AppColors.green : AppColors.white,
                    ),
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surface2,
                    shape: const CircleBorder(),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF0A1A2A), AppColors.bg],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    GestureDetector(
                      onTap: _uploadingPhoto ? null : _changePhoto,
                      child: Stack(alignment: Alignment.bottomRight, children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: AppColors.red, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.red.withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 52,
                            backgroundColor: AppColors.surface2,
                            backgroundImage: _avatarUrl != null
                                ? NetworkImage(_avatarUrl!)
                                : null,
                            child: _avatarUrl == null
                                ? const Icon(Icons.person_rounded,
                                    color: AppColors.white40, size: 48)
                                : null,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.bg, width: 2),
                          ),
                          child: _uploadingPhoto
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.camera_alt,
                                  size: 14, color: Colors.white),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 10),
                    Text(widget.user.name,
                        style: AppTextStyles.bodyMedium(size: 18)),
                    const SizedBox(height: 2),
                    Text(widget.user.email,
                        style: AppTextStyles.body(
                            size: 12, color: AppColors.white40)),
                  ],
                ),
              ),
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Notification toggles as compact cards
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Haptics.light();
                        setState(() => _notifications = !_notifications);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _notifications
                              ? AppColors.green.withOpacity(0.10)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _notifications
                                ? AppColors.green.withOpacity(0.4)
                                : AppColors.white08,
                          ),
                        ),
                        child: Column(children: [
                          Icon(
                            _notifications
                                ? Icons.notifications_active
                                : Icons.notifications_off_outlined,
                            color: _notifications
                                ? AppColors.green
                                : AppColors.white40,
                            size: 22,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _notifications ? 'ALERTS ON' : 'ALERTS OFF',
                            style: AppTextStyles.label(
                              color: _notifications
                                  ? AppColors.green
                                  : AppColors.white40,
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Haptics.light();
                        setState(() => _shareLocation = !_shareLocation);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _shareLocation
                              ? AppColors.red.withOpacity(0.10)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _shareLocation
                                ? AppColors.red.withOpacity(0.4)
                                : AppColors.white08,
                          ),
                        ),
                        child: Column(children: [
                          Icon(
                            _shareLocation
                                ? Icons.location_on_rounded
                                : Icons.location_off_outlined,
                            color: _shareLocation
                                ? AppColors.red
                                : AppColors.white40,
                            size: 22,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _shareLocation ? 'LOCATION ON' : 'LOCATION OFF',
                            style: AppTextStyles.label(
                              color: _shareLocation
                                  ? AppColors.red
                                  : AppColors.white40,
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 20),

                Text('PROFILE DETAILS',
                    style: AppTextStyles.label(color: AppColors.white40)),
                const SizedBox(height: 12),

                _profileField(Icons.person_outline, 'Full Name', _nameCtrl,
                    editable: _editMode),
                const SizedBox(height: 10),
                _profileField(Icons.phone_outlined, 'Phone', _phoneCtrl,
                    editable: _editMode, keyboardType: TextInputType.phone),
                const SizedBox(height: 10),
                _profileField(Icons.email_outlined, 'Email', _emailCtrl,
                    editable: false),
                const SizedBox(height: 10),
                _profileField(Icons.home_outlined, 'Home Address', _addressCtrl,
                    editable: _editMode),
                const SizedBox(height: 24),

                if (_editMode) ...[
                  AnimatedPressButton(
                    onTap: _loading
                        ? null
                        : () async {
                            await _save();
                            if (mounted) setState(() => _editMode = false);
                          },
                    child: ElevatedButton(
                      onPressed: _loading
                          ? null
                          : () async {
                              await _save();
                              if (mounted) setState(() => _editMode = false);
                            },
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text('Save Changes'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => setState(() => _editMode = false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(height: 16),
                ],

                TextButton.icon(
                  onPressed: _logout,
                  icon:
                      const Icon(Icons.logout, color: AppColors.red, size: 18),
                  label: Text('Sign Out',
                      style: AppTextStyles.bodyMedium(
                          size: 14, color: AppColors.red)),
                ),
                const SizedBox(height: 16),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileField(
    IconData icon,
    String label,
    TextEditingController ctrl, {
    bool editable = true,
    TextInputType keyboardType = TextInputType.text,
  }) =>
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: editable ? AppColors.surface2 : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: editable ? AppColors.white15 : AppColors.white08,
          ),
        ),
        child: Row(children: [
          Icon(icon,
              color: editable ? AppColors.red : AppColors.white40, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: AppTextStyles.label(color: AppColors.white40)),
              const SizedBox(height: 2),
              editable
                  ? TextField(
                      controller: ctrl,
                      keyboardType: keyboardType,
                      style: AppTextStyles.body(size: 14),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                      ),
                    )
                  : Text(ctrl.text,
                      style: AppTextStyles.body(
                          size: 14, color: AppColors.white70)),
            ]),
          ),
          if (!editable && label != 'Email')
            const Icon(Icons.lock_outline, color: AppColors.white40, size: 14),
        ]),
      );
}

class _FullscreenMapScreen extends StatelessWidget {
  final double lat, lng;
  final double? dropLat, dropLng;
  final String dropName;

  const _FullscreenMapScreen({
    required this.lat,
    required this.lng,
    this.dropLat,
    this.dropLng,
    this.dropName = '',
  });

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: const Text('Map View'), backgroundColor: AppColors.bg),
        body: FlutterMap(
          options: MapOptions(
            initialCenter: LatLng(lat, lng),
            initialZoom: 14,
            interactionOptions:
                const InteractionOptions(flags: InteractiveFlag.all),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.resqlink.app',
              maxNativeZoom: 18,
              keepBuffer: 4,
            ),
            if (dropLat != null && dropLng != null)
              PolylineLayer(polylines: [
                Polyline(
                  points: [LatLng(lat, lng), LatLng(dropLat!, dropLng!)],
                  strokeWidth: 3,
                  color: AppColors.red.withOpacity(0.7),
                ),
              ]),
            MarkerLayer(markers: [
              Marker(
                  point: LatLng(lat, lng),
                  width: 44,
                  height: 44,
                  child: const Icon(Icons.my_location,
                      color: AppColors.red, size: 36)),
              if (dropLat != null && dropLng != null)
                Marker(
                  point: LatLng(dropLat!, dropLng!),
                  width: 120,
                  height: 60,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                          color: const Color(0xFF2196F3),
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        dropName.isNotEmpty
                            ? dropName.split(',').first
                            : 'Hospital',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.local_hospital_rounded,
                        color: Color(0xFF2196F3), size: 28),
                  ]),
                ),
            ]),
          ],
        ),
      );
}
