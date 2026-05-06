// modules/driver/driver_shell.dart
// Changes in this version:
//  1. Offline driver → request panel hidden entirely (not just "no requests")
//  2. Decline → writes driver_id=null + status stays 'waiting' but snoozes that
//     request ID for 30 min locally so it doesn't bounce back immediately
//  3. Recent Trips on Home → real DB data (last 2 completed trips for driver)
//  4. TRIPS TODAY stat card → real count from DB
//  5. KM THIS WEEK / AVG TIME stats on TripsTab → computed from real DB rows
//  6. Live map upgraded: InDrive/Careem-style animated dashed polyline,
//     moving driver marker, distance + ETA chips on map, pickup & drop pins
//driver file

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' show sin, cos, sqrt, atan2, pi, Random;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/haptics.dart';
import '../../widgets/shimmer_widgets.dart';
import '../../widgets/animated_press_button.dart';
import '../../models/app_models.dart';
import '../../services/app_service.dart';
import '../../services/hospital_location_service.dart';
import '../auth/auth_screens.dart';
import 'package:http/http.dart' as http;

// ══════════════════════════════════════════════════════════════════════════════
// DRIVER SHELL
// ══════════════════════════════════════════════════════════════════════════════

class DriverShell extends StatefulWidget {
  const DriverShell({super.key});
  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  int _index = 0;
  AppUser? _user;
  Map<String, dynamic>? _driverRow;
  bool _loading = true;
  bool _onDuty = false;
  bool _loadingDuty = false;
  final _tripsKey = GlobalKey<_DriverTripsTabState>();
  Map<String, dynamic>? _activeRequest;

  static final _sb = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadDriver();
  }

  Future<void> _loadDriver() async {
    final authUser = _sb.auth.currentUser;
    if (authUser == null) return;
    try {
      final profile =
          await _sb.from('profiles').select().eq('id', authUser.id).single();
      final driverRow = await _sb
          .from('drivers')
          .select()
          .eq('user_id', authUser.id)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _user =
              AppUser.fromProfile(profile, authUser.id, authUser.email ?? '');
          if (driverRow != null) {
            _driverRow = driverRow;
            _onDuty = driverRow['is_on_duty'] ?? false;
          }
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setOnDuty(bool value) async {
    setState(() => _loadingDuty = true);
    try {
      await _sb.from('drivers').update({'is_on_duty': value}).eq(
          'user_id', _sb.auth.currentUser!.id);
      if (_driverRow != null) {
        await _sb.from('ambulances').update(
          {'status': value ? 'available' : 'busy'},
        ).eq('driver_id', _driverRow!['id']);
      }
      if (mounted) setState(() => _onDuty = value);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingDuty = false);
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
    final user = _user ?? AppUser.mockDriver();
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(index: _index, children: [
        DriverHomeTab(
          user: user,
          driverRow: _driverRow,
          onDispatch: () => _goTab(1),
          onDuty: _onDuty,
          loadingDuty: _loadingDuty,
          onDutyChanged: _setOnDuty,
          onSeeAllTap: () => _goTab(2),
          onRequestAccepted: (req) {
            setState(() => _activeRequest = req);
            _goTab(1);
          },
        ),
        DriverRideFlow(
          user: user,
          activeRequest: _activeRequest,
          onComplete: () {
            setState(() => _activeRequest = null);
            _goTab(2);
            // FIX: trigger trip reload after delay for DB to commit
            Future.delayed(const Duration(milliseconds: 1500), () {
              _tripsKey.currentState?._refresh();
            });
          },
        ),
        DriverTripsTab(key: _tripsKey, user: user, driverRow: _driverRow),
        DriverProfileTab(
            user: user,
            onDuty: _onDuty,
            loadingDuty: _loadingDuty,
            onDutyChanged: _setOnDuty),
      ]),
      bottomNavigationBar: ResQBottomNav(
        currentIndex: _index,
        onTap: _goTab,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.map_rounded), label: 'Live Map'),
          BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_rounded), label: 'Trips'),
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

class DriverHomeTab extends StatefulWidget {
  final AppUser user;
  final Map<String, dynamic>? driverRow;
  final VoidCallback onDispatch;
  final bool onDuty;
  final bool loadingDuty;
  final Future<void> Function(bool) onDutyChanged;
  final VoidCallback onSeeAllTap;
  final void Function(Map<String, dynamic>) onRequestAccepted;

  const DriverHomeTab({
    super.key,
    required this.user,
    this.driverRow,
    required this.onDispatch,
    required this.onDuty,
    required this.loadingDuty,
    required this.onDutyChanged,
    required this.onSeeAllTap,
    required this.onRequestAccepted,
  });

  @override
  State<DriverHomeTab> createState() => _DriverHomeTabState();
}

class _DriverHomeTabState extends State<DriverHomeTab>
    with SingleTickerProviderStateMixin {
  late AnimationController _listCtrl;

  // ── state ──────────────────────────────────────────────────────────────────
  Map<String, dynamic>? _pendingRequest;
  bool _loadingRequest = true;
  Timer? _refreshTimer;

  // Real recent trips (last 2 completed)
  List<Trip> _recentTrips = [];
  bool _loadingTrips = true;

  // Trips today count (real)
  int _tripsToday = 0;

  // Snoozed request IDs (declined locally this session)
  final Set<String> _snoozedIds = {};

  // Network connectivity
  bool _isOnline = true;
  StreamSubscription? _connectivitySub;

  static final _sb = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _listCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
    _fetchPendingRequest();
    _fetchRecentTrips();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (widget.onDuty && _pendingRequest == null && _isOnline) {
        _fetchPendingRequest();
      }
    });
    // Monitor connectivity
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (mounted && online != _isOnline) {
        setState(() => _isOnline = online);
        if (online && widget.onDuty) _fetchPendingRequest();
      }
    });
    Connectivity().checkConnectivity().then((results) {
      if (mounted) {
        setState(
            () => _isOnline = results.any((r) => r != ConnectivityResult.none));
      }
    });
  }

  @override
  void didUpdateWidget(DriverHomeTab old) {
    super.didUpdateWidget(old);
    // When driver flips back to on duty, re-fetch immediately
    if (!old.onDuty && widget.onDuty) {
      _snoozedIds.clear();
      _fetchPendingRequest();
    }
    // When going offline, clear the displayed request
    if (old.onDuty && !widget.onDuty) {
      setState(() {
        _pendingRequest = null;
        _loadingRequest = false;
      });
    }
  }

  @override
  void dispose() {
    _listCtrl.dispose();
    _refreshTimer?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }

  // ── Fetch the oldest unassigned waiting request ────────────────────────────
  Future<void> _fetchPendingRequest() async {
    if (!widget.onDuty) {
      if (mounted) setState(() => _loadingRequest = false);
      return;
    }
    try {
      final List<dynamic> requests = await _sb
          .from('ambulance_requests')
          .select('*, profiles!ambulance_requests_customer_id_fkey(phone)')
          .eq('status', 'waiting')
          .filter('driver_id', 'is', 'null')
          // FIX: filter out requests where the customer closed the app
          // (completed_at being set on a 'waiting' row is the signal)
          .filter('completed_at', 'is', 'null')
          .order('created_at')
          .limit(10);

      if (mounted) {
        setState(() {
          final available = requests
              .where((r) => !_snoozedIds.contains(r['id']?.toString()))
              .toList();

          if (available.isEmpty) {
            _pendingRequest = null;
          } else {
            final row = Map<String, dynamic>.from(available.first as Map);
            final profile = row['profiles'] as Map?;
            row['customer_phone'] = profile?['phone'] as String?;
            _pendingRequest = row;
          }
          _loadingRequest = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingRequest = false);
    }
  }

  // ── Fetch last 2 completed trips for this driver (real data) ───────────────
  Future<void> _fetchRecentTrips() async {
    final driverId = widget.driverRow?['id']?.toString();
    if (driverId == null) {
      if (mounted) setState(() => _loadingTrips = false);
      return;
    }
    try {
      final res = await _sb
          .from('ambulance_requests')
          .select()
          .eq('driver_id', driverId)
          .eq('status', 'completed')
          .order('created_at', ascending: false)
          .limit(2);

      // FIX: Use UTC midnight so the gte filter works correctly across timezones
      // e.g. PKT (UTC+5): local midnight 2 May = 2025-05-01T19:00:00Z in UTC
      // So we must send UTC date string, not local
      final nowUtc = DateTime.now().toUtc();
      final todayStartUtc =
          DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day).toIso8601String();

      final todayRes = await _sb
          .from('ambulance_requests')
          .select('id')
          .eq('driver_id', driverId)
          .eq('status', 'completed')
          .gte('created_at', todayStartUtc);

      // Use TripService for address resolution (reverse geocoding + label)
      final trips = await Future.wait(
        (res as List).map((r) => TripService.buildTripFromRow(r)).toList(),
      );

      if (mounted) {
        setState(() {
          _recentTrips = trips;
          _tripsToday = (todayRes as List).length;
          _loadingTrips = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingTrips = false);
    }
  }

  // ── Accept ─────────────────────────────────────────────────────────────────
  Future<void> _acceptRequest(String requestId) async {
    try {
      final driverRow = widget.driverRow;
      final driverId = driverRow?['id'];
      final ambRes = driverId != null
          ? await _sb
              .from('ambulances')
              .select('id')
              .eq('driver_id', driverId)
              .maybeSingle()
          : null;

      // Write accepted status + accepted_at
      await _sb.from('ambulance_requests').update({
        'driver_id': driverId,
        'ambulance_id': ambRes?['id'],
        'status': 'accepted',
        'accepted_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', requestId);

      final accepted = Map<String, dynamic>.from(_pendingRequest!);

      // Clear pending request immediately
      if (mounted)
        setState(() {
          _pendingRequest = null;
          _loadingRequest = false;
        });

      // Get pickup coords from accepted request
      final pickupLat = (accepted['pickup_lat'] as num?)?.toDouble() ?? 24.8607;
      final pickupLng = (accepted['pickup_lng'] as num?)?.toDouble() ?? 67.0011;

      // Navigate to hospital picker BEFORE going to live map
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HospitalPickerScreen(
              pickupLat: pickupLat,
              pickupLng: pickupLng,
              requestId: requestId,
              driverId: driverId?.toString() ?? '',
              onHospitalSelected: () async {
                Navigator.pop(context); // close picker
                // Fetch fresh request row with drop_lat/lng now populated
                try {
                  final fresh = await _sb
                      .from('ambulance_requests')
                      .select('*')
                      .eq('id', requestId)
                      .single();
                  widget.onRequestAccepted(fresh as Map<String, dynamic>);
                } catch (_) {
                  widget.onRequestAccepted(accepted); // fallback
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) showErrorSnack(context, 'Failed to accept: $e');
    }
  }

  // ── Decline: snooze locally so it won't bounce back ───────────────────────
  void _declineRequest(String requestId) {
    setState(() {
      _snoozedIds.add(requestId);
      _pendingRequest = null;
    });
    // Immediately try to find the next non-snoozed request
    _fetchPendingRequest();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text('Driver Portal', style: AppTextStyles.heading(18)),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Offline banner ───────────────────────────────────────
              if (!_isOnline)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A1500),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.wifi_off_rounded,
                        color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No internet connection — requests paused',
                        style:
                            AppTextStyles.body(size: 12, color: Colors.orange),
                      ),
                    ),
                  ]),
                ),
              // ── Driver header card ────────────────────────────────────────
              Container(
                margin: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                padding: const EdgeInsets.all(16),
                decoration: AppDecorations.card,
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.user.name,
                            style: AppTextStyles.bodyMedium(size: 16),
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Text(
                            'License: ${widget.user.licenseNumber ?? widget.driverRow?["license_number"] ?? "—"}',
                            style: AppTextStyles.body(
                                size: 12, color: AppColors.red),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  if (widget.loadingDuty)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  Semantics(
                    label: widget.onDuty
                        ? 'Switch to off duty'
                        : 'Switch to on duty',
                    child: Switch(
                      value: widget.onDuty,
                      onChanged: (v) {
                        Haptics.medium();
                        widget.onDutyChanged(v);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: widget.onDuty
                          ? AppColors.green.withValues(alpha: 0.15)
                          : AppColors.white08,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: widget.onDuty
                              ? AppColors.green.withValues(alpha: 0.4)
                              : Colors.transparent),
                    ),
                    child: Text(widget.onDuty ? 'ON DUTY' : 'OFF DUTY',
                        style: AppTextStyles.bodyMedium(
                            size: 11,
                            color: widget.onDuty
                                ? AppColors.green
                                : AppColors.white40)),
                  ),
                ]),
              ),

              // ── Stat cards ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  StatCard(label: 'TRIPS TODAY', value: _tripsToday.toString()),
                  const SizedBox(width: 12),
                  StatCard(
                      label: 'STATUS',
                      value: widget.onDuty ? 'LIVE' : 'OFFLINE'),
                ]),
              ),
              const SizedBox(height: 14),

              // ── Request panel — ONLY shown when ON DUTY ───────────────────
              if (!widget.onDuty)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(14),
                  decoration: AppDecorations.alertBox,
                  child: Row(children: [
                    const Icon(Icons.wifi_off_rounded,
                        color: AppColors.white40, size: 18),
                    const SizedBox(width: 8),
                    Text('Go on duty to see incoming requests',
                        style: AppTextStyles.body(
                            size: 13, color: AppColors.white40)),
                  ]),
                )
              else if (_loadingRequest)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Center(
                      child: CircularProgressIndicator(
                          color: AppColors.red, strokeWidth: 2)),
                )
              else if (_pendingRequest == null)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(14),
                  decoration: AppDecorations.alertBox,
                  child: Row(children: [
                    const Icon(Icons.check_circle_outline,
                        color: AppColors.green, size: 18),
                    const SizedBox(width: 8),
                    Text('No pending requests right now',
                        style: AppTextStyles.body(
                            size: 13, color: AppColors.white70)),
                  ]),
                )
              else
                _RequestCard(
                  request: _pendingRequest!,
                  onAccept: () =>
                      _acceptRequest(_pendingRequest!['id'].toString()),
                  onDecline: () =>
                      _declineRequest(_pendingRequest!['id'].toString()),
                ),

              const SizedBox(height: 20),

              // ── Recent trips (real data) ───────────────────────────────────
              SectionHeader(
                  title: 'RECENT TRIPS',
                  actionLabel: 'See all',
                  onAction: widget.onSeeAllTap),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _loadingTrips
                    ? const ShimmerList(itemCount: 2, itemHeight: 70)
                    : _recentTrips.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(14),
                            decoration: AppDecorations.alertBox,
                            child: Text('No trips yet',
                                style: AppTextStyles.body(
                                    size: 13, color: AppColors.white40)),
                          )
                        : Column(
                            children: staggeredItems(
                              _recentTrips
                                  .map((t) => _TripPreviewTile(
                                        date: t.date,
                                        route: '${t.from} → ${t.to}',
                                        meta: t.duration == '—'
                                            ? t.caseId
                                            : '${t.duration}  •  ${t.distance}',
                                        caseId: t.caseId,
                                      ))
                                  .toList(),
                              controller: _listCtrl,
                            ),
                          ),
              ),
            ],
          ),
        ),
      );
}

// ── Request card extracted as widget for clarity ───────────────────────────
class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _RequestCard({
    required this.request,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(14),
        decoration: AppDecorations.alertBox,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.local_shipping_rounded,
                  color: AppColors.red, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${request["emergency_type"] ?? "Emergency"} • ${(request["severity"] ?? "medium").toString().toUpperCase()}',
                  style: AppTextStyles.bodyMedium(size: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
            const SizedBox(height: 6),
            Text(request['pickup_location'] ?? 'Location not provided',
                style: AppTextStyles.body(size: 12, color: AppColors.white70),
                overflow: TextOverflow.ellipsis),
            if (request['drop_location'] != null &&
                (request['drop_location'] as String).isNotEmpty) ...[
              const SizedBox(height: 2),
              Text('→ ${request['drop_location']}',
                  style: AppTextStyles.body(size: 12, color: AppColors.white40),
                  overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: AnimatedPressButton(
                  onTap: onAccept,
                  child: ElevatedButton(
                    onPressed: onAccept,
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(42)),
                    child: const Text('Accept & Navigate'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: onDecline,
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(42)),
                  child: const Text('Decline'),
                ),
              ),
            ]),
          ],
        ),
      );
}

class _TripPreviewTile extends StatelessWidget {
  final String date, route, meta, caseId;

  const _TripPreviewTile({
    required this.date,
    required this.route,
    required this.meta,
    required this.caseId,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          splashColor: AppColors.redDim,
          onTap: () => Haptics.light(),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.white08),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
                decoration: BoxDecoration(
                    color: AppColors.redDim,
                    borderRadius: BorderRadius.circular(7)),
                child: Text(date,
                    style: AppTextStyles.bodyMedium(
                        size: 10, color: AppColors.red)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(route,
                        style: AppTextStyles.bodyMedium(size: 12),
                        overflow: TextOverflow.ellipsis),
                    Text(meta,
                        style: AppTextStyles.body(
                            size: 11, color: AppColors.white40)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: AppColors.white40, size: 16),
            ]),
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// RIDE FLOW  — InDrive/Careem-style live map
// ══════════════════════════════════════════════════════════════════════════════

class DriverRideFlow extends StatefulWidget {
  final AppUser user;
  final Map<String, dynamic>? activeRequest;
  final VoidCallback onComplete;

  const DriverRideFlow({
    super.key,
    required this.user,
    this.activeRequest,
    required this.onComplete,
  });

  @override
  State<DriverRideFlow> createState() => _DriverRideFlowState();
}

class _DriverRideFlowState extends State<DriverRideFlow>
    with TickerProviderStateMixin {
  RidePhase _phase = RidePhase.dispatched;
  bool _showSummary = false;
  bool _isAdvancing = false;

  // ── Current driver position (animates toward patient)
  double _driverLat = 24.8607;
  double _driverLng = 67.0011;

  // ── Pickup / drop positions from the active request
  double? _pickupLat;
  double? _pickupLng;
  double? _dropLat;
  double? _dropLng;

  bool _locationFetched = false;
  late MapController _mapController;
  Timer? _moveTimer;

  // For animated dashed-line effect we use an offset ticker
  late AnimationController _dashAnim;
  int _dashOffset = 0;

  // Simulated driver movement interpolation
  int _moveStep = 0;
  static const int _totalSteps = 60;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _dashAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..addListener(() {
        // increment dash offset for animation
      })
      ..repeat();

    // Animate dashes every 80 ms
    Timer.periodic(const Duration(milliseconds: 80), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _dashOffset = (_dashOffset + 1) % 20);
    });

    _initPositions();
  }

  // Add this method in _DriverRideFlowState
  // Add this method in _DriverRideFlowState class
  Future<void> _updateDriverLocation() async {
    try {
      final driverRow = widget.user.id; // or get from driverRow if available
      if (driverRow != null) {
        await Supabase.instance.client.from('drivers').update({
          'current_lat': _driverLat,
          'current_lng': _driverLng,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', driverRow);
      }
    } catch (e) {
      debugPrint('[_updateDriverLocation] Failed: $e');
    }
  }

// Call this periodically in _startDriverAnimation or with Timer

  Future<void> _initPositions() async {
    // 1. Read pickup/drop from the active request
    final req = widget.activeRequest;
    if (req != null) {
      _pickupLat = _toDouble(req['pickup_lat']);
      _pickupLng = _toDouble(req['pickup_lng']);
      _dropLat = _toDouble(req['drop_lat']);
      _dropLng = _toDouble(req['drop_lng']);
    }

    // 2. Get actual driver GPS
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm != LocationPermission.deniedForever &&
          perm != LocationPermission.denied) {
        final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);
        if (!mounted) return;
        setState(() {
          _driverLat = pos.latitude;
          _driverLng = pos.longitude;
          _locationFetched = true;
        });
      }
    } catch (_) {}

    // 3. If no pickup coords in request, offset from driver
    _pickupLat ??= _driverLat + 0.010;
    _pickupLng ??= _driverLng + 0.008;
    _dropLat ??= _driverLat + 0.022;
    _dropLng ??= _driverLng + 0.016;

    _startDriverAnimation();
    _centerMap();
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  void _centerMap() {
    if (!mounted) return;
    final targetLat = (_driverLat + _pickupLat!) / 2;
    final targetLng = (_driverLng + _pickupLng!) / 2;
    try {
      _mapController.move(LatLng(targetLat, targetLng), 14);
    } catch (_) {}
  }

  /// Smoothly animate driver marker toward pickup (simulated movement)
  void _startDriverAnimation() {
    _moveTimer?.cancel();
    _moveStep = 0;

    // Update location every 5 seconds while animating
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted || _moveStep >= _totalSteps) {
        timer.cancel();
        return;
      }
      _updateDriverLocation(); // ← ADD THIS LINE
    });

    _moveTimer = Timer.periodic(const Duration(milliseconds: 1500), (t) {
      if (!mounted || _moveStep >= _totalSteps) {
        t.cancel();
        return;
      }
      final progress = _moveStep / _totalSteps;
      setState(() {
        _driverLat = _lerp(_driverLat, _pickupLat!, progress + 1 / _totalSteps);
        _driverLng = _lerp(_driverLng, _pickupLng!, progress + 1 / _totalSteps);
        _moveStep++;
      });
    });
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t.clamp(0, 1);

  /// Haversine distance in km between two lat/lng points
  double _distanceKm(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLng = _deg2rad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2);
    cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) => deg * pi / 180;

  String get _etaText {
    if (_pickupLat == null) return '—';
    final dist = _distanceKm(_driverLat, _driverLng, _pickupLat!, _pickupLng!);
    final mins = (dist / 0.5 * 1).round(); // assume 30 km/h avg = 0.5 km/min
    return '${mins < 1 ? 1 : mins} MIN';
  }

  String get _distanceText {
    if (_pickupLat == null) return '—';
    final dist = _distanceKm(_driverLat, _driverLng, _pickupLat!, _pickupLng!);
    return '${dist.toStringAsFixed(1)} km';
  }

  String get _phaseLabel {
    switch (_phase) {
      case RidePhase.dispatched:
        return 'DISPATCH RECEIVED';
      case RidePhase.enRoute:
        return 'EN ROUTE TO SCENE';
      case RidePhase.arrivedAtScene:
        return 'ARRIVED AT SCENE';
      case RidePhase.enRouteToHospital:
        return 'EN ROUTE TO HOSPITAL';
      case RidePhase.delivered:
        return 'DELIVERED';
    }
  }

  String get _btnLabel {
    switch (_phase) {
      case RidePhase.dispatched:
        return 'Start Navigation';
      case RidePhase.enRoute:
        return 'Arrived at Scene';
      case RidePhase.arrivedAtScene:
        return 'Pickup Patient — Start Ride';
      case RidePhase.enRouteToHospital:
        return 'Mark Delivered';
      case RidePhase.delivered:
        return 'View Trip Summary';
    }
  }

  IconData get _btnIcon {
    switch (_phase) {
      case RidePhase.dispatched:
        return Icons.navigation_rounded;
      case RidePhase.enRoute:
        return Icons.where_to_vote_outlined;
      case RidePhase.arrivedAtScene:
        return Icons.person_pin_circle_rounded;
      case RidePhase.enRouteToHospital:
        return Icons.local_hospital_rounded;
      case RidePhase.delivered:
        return Icons.receipt_long_rounded;
    }
  }

  // Advancing from enRouteToHospital → delivered writes 'completed' to DB
  // so TripService.fetchTripHistory() can find it immediately.
  Future<void> _advance() async {
    if (_isAdvancing) return; // prevent double-tap
    if (_phase == RidePhase.delivered) {
      setState(() => _showSummary = true);
      return;
    }
    setState(() => _isAdvancing = true);
    Haptics.medium();
    final nextPhase = RidePhase.values[_phase.index + 1];

    if (nextPhase == RidePhase.delivered) {
      final requestId = widget.activeRequest?['id']?.toString();
      if (requestId != null) {
        try {
          final completedAt = DateTime.now().toUtc().toIso8601String();
          await Supabase.instance.client.from('ambulance_requests').update({
            'status': 'completed',
            'completed_at': completedAt,
          }).eq('id', requestId);
          debugPrint(
              '[_advance] wrote completed_at=$completedAt for $requestId');
        } catch (e) {
          debugPrint('[_advance] DB error: $e');
          if (mounted) showErrorSnack(context, 'DB error: $e');
        }
      }
    }
    if (mounted)
      setState(() {
        _phase = nextPhase;
        _isAdvancing = false;
      });
  }

  void _resetPhase() {
    setState(() {
      _phase = RidePhase.dispatched;
      _showSummary = false;
      _moveStep = 0;
      _isAdvancing = false;
    });
  }

  @override
  void didUpdateWidget(DriverRideFlow old) {
    super.didUpdateWidget(old);
    if (old.activeRequest != null && widget.activeRequest == null) {
      // Ride completed — full reset
      setState(() {
        _phase = RidePhase.dispatched;
        _showSummary = false;
        _moveStep = 0;
        _isAdvancing = false;
        _pickupLat = null;
        _pickupLng = null;
        _dropLat = null;
        _dropLng = null;
      });
      _moveTimer?.cancel();
    }
    if (widget.activeRequest != null &&
        old.activeRequest?['id'] != widget.activeRequest?['id']) {
      setState(() {
        _phase = RidePhase.dispatched;
        _showSummary = false;
        _moveStep = 0;
        _isAdvancing = false;
      });
      _initPositions();
    }
  }

  @override
  void dispose() {
    _dashAnim.dispose();
    _moveTimer?.cancel();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (widget.activeRequest == null && !_showSummary) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                  color: AppColors.redDim,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.redMid)),
              child: const Icon(Icons.map_outlined,
                  color: AppColors.red, size: 36),
            ),
            const SizedBox(height: 20),
            Text('No Active Ride', style: AppTextStyles.heading(20)),
            const SizedBox(height: 8),
            Text('Accept a request from Home to start navigation',
                textAlign: TextAlign.center,
                style: AppTextStyles.body(size: 13, color: AppColors.white40)),
          ]),
        ),
      );
    }

    if (_showSummary) return _summaryScreen();

    final pickup = LatLng(
        _pickupLat ?? _driverLat + 0.01, _pickupLng ?? _driverLng + 0.008);
    final drop =
        LatLng(_dropLat ?? _driverLat + 0.022, _dropLng ?? _driverLng + 0.016);
    final driver = LatLng(_driverLat, _driverLng);

    // Which polyline to show depends on phase:
    // dispatched/enRoute → driver→pickup (dashed animated red)
    // arrivedAtScene/enRouteToHospital → pickup→drop (solid blue)
    final bool toPickup = _phase.index <= RidePhase.enRoute.index;
    final List<LatLng> routePoints =
        toPickup ? [driver, pickup] : [pickup, drop];
    final Color routeColor = toPickup ? AppColors.red : const Color(0xFF2196F3);

    return Scaffold(
      body: Stack(children: [
        // ── FULL-SCREEN LIVE MAP ──────────────────────────────────────────
        RepaintBoundary(
          child: SizedBox.expand(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: driver,
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
                PolylineLayer(
                  polylines: _buildDashedPolyline(
                    routePoints,
                    color: routeColor,
                    strokeWidth: 5.0,
                    dashLength: 12,
                    gapLength: 8,
                    offset: _dashOffset,
                  ),
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      strokeWidth: 2,
                      color: routeColor.withValues(alpha: 0.25),
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: driver,
                      width: 52,
                      height: 52,
                      child: _AmbulanceMarker(),
                    ),
                    Marker(
                      point: pickup,
                      width: 44,
                      height: 72,
                      child: _MapPin(
                        color: AppColors.red,
                        icon: Icons.person_pin_rounded,
                        label: 'Pickup',
                      ),
                    ),
                    if (_phase.index >= RidePhase.arrivedAtScene.index)
                      Marker(
                        point: drop,
                        width: 44,
                        height: 72,
                        child: _MapPin(
                          color: const Color(0xFF2196F3),
                          icon: Icons.local_hospital_rounded,
                          label: 'Hospital',
                        ),
                      ),
                    if (toPickup)
                      Marker(
                        point: LatLng(
                          (driver.latitude + pickup.latitude) / 2,
                          (driver.longitude + pickup.longitude) / 2,
                        ),
                        width: 90,
                        height: 36,
                        child: _RouteChip(
                          text: '$_distanceText  ·  $_etaText',
                          color: AppColors.red,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // ↑ RepaintBoundary closes here
        Positioned(
          top: MediaQuery.of(context).padding.top + 104 + 48,
          right: 12,
          child: GestureDetector(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _DriverFullscreenMap(
                    driverLat: _driverLat,
                    driverLng: _driverLng,
                    pickupLat: _pickupLat ?? _driverLat + 0.01,
                    pickupLng: _pickupLng ?? _driverLng + 0.008,
                    dropLat: _dropLat,
                    dropLng: _dropLng,
                    phase: _phase,
                  ),
                )),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8)),
              child:
                  const Icon(Icons.fullscreen, color: Colors.white, size: 22),
            ),
          ),
        ),

        // ── TOP ETA CARD ─────────────────────────────────────────────────
        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF2D2222),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.white08),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: AppColors.red,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.emergency,
                    color: AppColors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('ETA TO PICKUP',
                        style: AppTextStyles.label(color: AppColors.white40)),
                    Text(_etaText, style: AppTextStyles.heading(20)),
                  ],
                ),
              ),
              // Call patient
              Semantics(
                label: 'Call patient',
                button: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () async {
                    Haptics.light();
                    final phone =
                        widget.activeRequest?['customer_phone'] as String?;
                    if (phone == null || phone.isEmpty) {
                      if (mounted)
                        showErrorSnack(context, 'Customer phone not available');
                      return;
                    }
                    final uri = Uri.parse('tel:$phone');
                    if (await canLaunchUrl(uri)) launchUrl(uri);
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                        color: AppColors.white08, shape: BoxShape.circle),
                    child: const Icon(Icons.phone_outlined,
                        color: AppColors.red, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('DIST',
                    style: AppTextStyles.label(color: AppColors.white40)),
                Text(_distanceText,
                    style: AppTextStyles.heading(16, color: AppColors.red)),
              ]),
            ]),
          ),
        ),

        // ── PHASE BADGE ──────────────────────────────────────────────────
        Positioned(
          top: MediaQuery.of(context).padding.top + 104,
          left: 0,
          right: 0,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              child: Container(
                key: ValueKey(_phaseLabel),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.redDim,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.redMid),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                        color: AppColors.red, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 7),
                  Text(_phaseLabel,
                      style: AppTextStyles.label(color: AppColors.red)),
                ]),
              ),
            ),
          ),
        ),

        // ── BOTTOM ACTION SHEET ───────────────────────────────────────────
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
                22, 14, 22, MediaQuery.of(context).padding.bottom + 16),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1212),
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            ),
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
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '• SEVERITY: ${((widget.activeRequest?['severity'] ?? 'MEDIUM') as String).toUpperCase()}',
                  style: AppTextStyles.label(color: AppColors.red),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.activeRequest?['pickup_location'] ?? '—',
                              style: AppTextStyles.heading(17),
                              overflow: TextOverflow.ellipsis),
                          if (widget.activeRequest?['drop_location'] != null &&
                              (widget.activeRequest!['drop_location'] as String)
                                  .isNotEmpty)
                            Text(
                              '→ ${widget.activeRequest!['drop_location']}',
                              style: AppTextStyles.body(
                                  size: 12, color: AppColors.white40),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(children: [
                  _infoPill('DISTANCE', _distanceText),
                  const SizedBox(width: 10),
                  _infoPill('ETA', _etaText, color: AppColors.green),
                ]),
                const SizedBox(height: 14),
                AnimatedPressButton(
                  onTap: _isAdvancing ? null : () => _advance(),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _isAdvancing ? null : () => _advance(),
                    icon: _isAdvancing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Icon(_btnIcon, size: 20),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(_btnLabel,
                          style: AppTextStyles.bodyMedium(size: 14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  // ── Dashed polyline builder ────────────────────────────────────────────────
  /// Splits [points] into alternating dash/gap segments.
  /// [offset] shifts which segments are visible to animate the dashes.
  List<Polyline> _buildDashedPolyline(
    List<LatLng> points, {
    required Color color,
    required double strokeWidth,
    required int dashLength,
    required int gapLength,
    required int offset,
  }) {
    if (points.length < 2) return [];
    final List<Polyline> result = [];
    final period = dashLength + gapLength;

    // We convert to a "pixel-like" representation by treating each segment
    // as a fraction of total path and drawing short polylines.
    // Since flutter_map doesn't have native dashed lines we fake it with
    // multiple 2-point polylines at fixed distance intervals.

    // Total great-circle distance
    double totalDist = 0;
    for (int i = 0; i < points.length - 1; i++) {
      totalDist += _distanceKm(points[i].latitude, points[i].longitude,
          points[i + 1].latitude, points[i + 1].longitude);
    }
    if (totalDist == 0) return [];

    // Sample every ~0.05 km along the route
    const sampleKm = 0.05;
    int numSamples = (totalDist / sampleKm).ceil();
    if (numSamples < 2) numSamples = 2;

    final List<LatLng> sampled = [];
    for (int s = 0; s <= numSamples; s++) {
      double target = s * totalDist / numSamples;
      double cumDist = 0;
      for (int i = 0; i < points.length - 1; i++) {
        final segDist = _distanceKm(points[i].latitude, points[i].longitude,
            points[i + 1].latitude, points[i + 1].longitude);
        if (cumDist + segDist >= target) {
          final t = (target - cumDist) / segDist;
          sampled.add(LatLng(
            points[i].latitude +
                t * (points[i + 1].latitude - points[i].latitude),
            points[i].longitude +
                t * (points[i + 1].longitude - points[i].longitude),
          ));
          break;
        }
        cumDist += segDist;
        if (i == points.length - 2) sampled.add(points.last);
      }
    }

    // Build dash segments
    List<LatLng> dashBuf = [];
    for (int i = 0; i < sampled.length; i++) {
      final pos = (i + offset) % period;
      if (pos < dashLength) {
        dashBuf.add(sampled[i]);
      } else {
        if (dashBuf.length >= 2) {
          result.add(Polyline(
            points: List.from(dashBuf),
            strokeWidth: strokeWidth,
            color: color,
          ));
        }
        dashBuf = [];
      }
    }
    if (dashBuf.length >= 2) {
      result.add(Polyline(
        points: dashBuf,
        strokeWidth: strokeWidth,
        color: color,
      ));
    }
    return result;
  }

  Widget _infoPill(String label, String value,
          {Color color = AppColors.white}) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
              color: AppColors.white08,
              borderRadius: BorderRadius.circular(10)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.label()),
              const SizedBox(height: 3),
              Text(value, style: AppTextStyles.heading(16, color: color)),
            ],
          ),
        ),
      );

  // ────────────────────────────────────────────────────────────────────────────
  // SUMMARY SCREEN — fixed overflow, handles null coords via Nominatim geocode
  // ────────────────────────────────────────────────────────────────────────────
  Widget _summaryScreen() {
    return _SummaryScreen(
      activeRequest: widget.activeRequest,
      driverLat: _driverLat,
      driverLng: _driverLng,
      pickupLat: _pickupLat,
      pickupLng: _pickupLng,
      dropLat: _dropLat,
      dropLng: _dropLng,
      onDone: () {
        Haptics.heavy();
        _resetPhase();
        widget.onComplete();
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SUMMARY SCREEN — separate StatefulWidget so it can geocode asynchronously
// ══════════════════════════════════════════════════════════════════════════════

class _SummaryScreen extends StatefulWidget {
  final Map<String, dynamic>? activeRequest;
  final double driverLat;
  final double driverLng;
  final double? pickupLat;
  final double? pickupLng;
  final double? dropLat;
  final double? dropLng;
  final VoidCallback onDone;

  const _SummaryScreen({
    required this.activeRequest,
    required this.driverLat,
    required this.driverLng,
    this.pickupLat,
    this.pickupLng,
    this.dropLat,
    this.dropLng,
    required this.onDone,
  });

  @override
  State<_SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<_SummaryScreen> {
  LatLng? _resolvedPickup;
  LatLng? _resolvedDrop;
  bool _geocoding = false;

  @override
  void initState() {
    super.initState();
    _resolveCoords();
  }

  Future<void> _resolveCoords() async {
    if (widget.pickupLat != null &&
        widget.pickupLng != null &&
        widget.dropLat != null &&
        widget.dropLng != null) {
      setState(() {
        _resolvedPickup = LatLng(widget.pickupLat!, widget.pickupLng!);
        _resolvedDrop = LatLng(widget.dropLat!, widget.dropLng!);
      });
      return;
    }

    final pickup = (widget.pickupLat != null && widget.pickupLng != null)
        ? LatLng(widget.pickupLat!, widget.pickupLng!)
        : LatLng(widget.driverLat, widget.driverLng);

    setState(() {
      _resolvedPickup = pickup;
      _geocoding = widget.dropLat == null;
    });

    if (widget.dropLat != null && widget.dropLng != null) {
      setState(() => _resolvedDrop = LatLng(widget.dropLat!, widget.dropLng!));
      return;
    }

    // FIX: Use http package instead of dart:io HttpClient
    final dropText = widget.activeRequest?['drop_location'] as String?;
    if (dropText != null && dropText.trim().isNotEmpty) {
      try {
        final encoded = Uri.encodeComponent(dropText.trim());
        final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=$encoded&format=json&limit=1',
        );
        final response = await http.get(uri, headers: {
          'User-Agent': 'ResQLink/1.0',
          'Accept-Language': 'en',
        }).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final jsonList = jsonDecode(response.body) as List;
          if (jsonList.isNotEmpty) {
            final lat = double.tryParse(jsonList[0]['lat'] as String? ?? '');
            final lng = double.tryParse(jsonList[0]['lon'] as String? ?? '');
            if (lat != null && lng != null && mounted) {
              setState(() {
                _resolvedDrop = LatLng(lat, lng);
                _geocoding = false;
              });
              return;
            }
          }
        }
      } catch (e) {
        debugPrint('[_SummaryScreen] geocode error: $e');
      }
    }

    // Fallback: offset from pickup slightly
    if (mounted) {
      setState(() {
        _resolvedDrop =
            LatLng(pickup.latitude + 0.012, pickup.longitude + 0.009);
        _geocoding = false;
      });
    }
  }

  double _distKm(LatLng a, LatLng b) {
    const R = 6371.0;
    final dLat = (b.latitude - a.latitude) * pi / 180;
    final dLng = (b.longitude - a.longitude) * pi / 180;
    final x = sin(dLat / 2) * sin(dLat / 2) +
        cos(a.latitude * pi / 180) *
            cos(b.latitude * pi / 180) *
            sin(dLng / 2) *
            sin(dLng / 2);
    return R * 2 * atan2(sqrt(x), sqrt(1 - x));
  }

  @override
  Widget build(BuildContext context) {
    final pickup = _resolvedPickup;
    final drop = _resolvedDrop;

    final String distText = (pickup != null && drop != null)
        ? '${_distKm(pickup, drop).toStringAsFixed(1)} km'
        : '—';

    final String caseId = widget.activeRequest != null
        ? '#${(widget.activeRequest!['id']?.toString() ?? '').substring(0, 6).toUpperCase()}'
        : '—';

    return Scaffold(
      appBar: ResQAppBar(title: 'Trip Summary', onBack: () {}),
      body: SingleChildScrollView(
        // ← fixes overflow
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Check circle ──────────────────────────────────────────────
            Center(
              child: Stack(alignment: Alignment.center, children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.redMid, width: 1.5),
                  ),
                ),
                Container(
                  width: 88,
                  height: 88,
                  decoration: const BoxDecoration(
                      color: AppColors.red, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded,
                      color: AppColors.white, size: 48),
                ),
              ]),
            ),
            const SizedBox(height: 22),

            Text('Emergency Transport\nCompleted',
                textAlign: TextAlign.center, style: AppTextStyles.heading(24)),
            const SizedBox(height: 8),
            Text('Mission Successful  •  $caseId',
                textAlign: TextAlign.center,
                style: AppTextStyles.body(size: 13, color: AppColors.white40)),
            const SizedBox(height: 28),

            // ── Stat boxes ────────────────────────────────────────────────
            Row(children: [
              _statBox('DISTANCE', distText),
              const SizedBox(width: 14),
              _statBox('STATUS', 'DELIVERED'),
            ]),
            const SizedBox(height: 20),

            // ── Map ───────────────────────────────────────────────────────
            if (_geocoding)
              Container(
                height: 160,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                          color: AppColors.red, strokeWidth: 2),
                      SizedBox(height: 10),
                      Text('Locating hospital…',
                          style: TextStyle(
                              color: AppColors.white40, fontSize: 12)),
                    ],
                  ),
                ),
              )
            else if (pickup != null && drop != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 200, // ← taller so map breathes
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(
                        (pickup.latitude + drop.latitude) / 2,
                        (pickup.longitude + drop.longitude) / 2,
                      ),
                      initialZoom: 13,
                      interactionOptions:
                          const InteractionOptions(flags: InteractiveFlag.none),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.resqlink.app',
                      ),
                      PolylineLayer(polylines: [
                        Polyline(
                          points: [pickup, drop],
                          strokeWidth: 4,
                          color: AppColors.green.withValues(alpha: 0.9),
                        ),
                      ]),
                      MarkerLayer(markers: [
                        Marker(
                          point: pickup,
                          width: 28,
                          height: 28,
                          child: Container(
                            decoration: const BoxDecoration(
                                color: AppColors.white40,
                                shape: BoxShape.circle),
                            child: const Icon(Icons.circle,
                                color: AppColors.white, size: 10),
                          ),
                        ),
                        Marker(
                          point: drop,
                          width: 28,
                          height: 28,
                          child: const Icon(Icons.local_hospital_rounded,
                              color: AppColors.red, size: 24),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(7),
                  border:
                      Border.all(color: AppColors.green.withValues(alpha: 0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.green, size: 11),
                  const SizedBox(width: 4),
                  Text('Route complete',
                      style:
                          AppTextStyles.body(size: 10, color: AppColors.green)),
                ]),
              ),
            ),
            const SizedBox(height: 28),

            // ── CTA ───────────────────────────────────────────────────────
            AnimatedPressButton(
              onTap: widget.onDone,
              child: ElevatedButton(
                onPressed: widget.onDone,
                child: Row(mainAxisSize: MainAxisSize.min, children: const [
                  Icon(Icons.wifi_tethering_rounded, size: 18),
                  SizedBox(width: 8),
                  Text('Go Back Online'),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statBox(String label, String value) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
            color: AppColors.redDim,
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: AppTextStyles.label()),
            const SizedBox(height: 5),
            Text(value, style: AppTextStyles.heading(22, color: AppColors.red)),
          ]),
        ),
      );
}

// ── Custom map marker widgets ──────────────────────────────────────────────

class _AmbulanceMarker extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.red,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: AppColors.red.withValues(alpha: 0.5),
                blurRadius: 12,
                spreadRadius: 2),
          ],
        ),
        child: const Icon(Icons.local_shipping_rounded,
            color: AppColors.white, size: 26),
      );
}

class _MapPin extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;

  const _MapPin({required this.color, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment:
            MainAxisAlignment.end, // FIX: anchor to bottom of marker box
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 8,
                    spreadRadius: 1),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 16), // FIX: 20→16
          ),
          Container(width: 2, height: 8, color: color), // FIX: 10→8
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8, // FIX: 9→8
                    fontWeight: FontWeight.w600)),
          ),
        ],
      );
}

class _RouteChip extends StatelessWidget {
  final String text;
  final Color color;

  const _RouteChip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6),
          ],
        ),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// TRIPS TAB  — real stats from DB
// ══════════════════════════════════════════════════════════════════════════════

class DriverTripsTab extends StatefulWidget {
  final AppUser user;
  final Map<String, dynamic>? driverRow;
  const DriverTripsTab({super.key, required this.user, this.driverRow});

  @override
  State<DriverTripsTab> createState() => _DriverTripsTabState();
}

class _DriverTripsTabState extends State<DriverTripsTab> {
  List<Trip> _trips = [];
  bool _loading = true;

  // Summary stats
  int _totalTrips = 0;
  String _kmThisWeek = '0.0';
  String _avgTime = '—';

  bool _hasLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload every time this tab becomes active
    if (!_hasLoaded || !_loading) {
      _hasLoaded = true;
      // Small delay so DB write from _advance() has time to commit
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _refresh();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final driverId = widget.driverRow?['id']?.toString() ?? widget.user.id;
    final trips = await TripService.fetchTripHistory(driverId);

    // ── KM this week ─────────────────────────────────────────────────────────
    final now = DateTime.now();
    final weekMonday = now.subtract(Duration(days: now.weekday - 1));
    final weekStart =
        DateTime(weekMonday.year, weekMonday.month, weekMonday.day);
    final weekStartUtc = weekStart.toUtc().toIso8601String();

    double kmThisWeek = 0;
    try {
      final weekRes = await Supabase.instance.client
          .from('ambulance_requests')
          .select('pickup_lat, pickup_lng, drop_lat, drop_lng')
          .eq('driver_id', driverId)
          .eq('status', 'completed')
          .gte('created_at', weekStartUtc);

      for (final row in weekRes as List) {
        final pLat = (row['pickup_lat'] as num?)?.toDouble();
        final pLng = (row['pickup_lng'] as num?)?.toDouble();
        final dLat = (row['drop_lat'] as num?)?.toDouble();
        final dLng = (row['drop_lng'] as num?)?.toDouble();
        if (pLat != null && pLng != null && dLat != null && dLng != null) {
          const R = 6371.0;
          final dLatR = (dLat - pLat) * pi / 180;
          final dLngR = (dLng - pLng) * pi / 180;
          final a = sin(dLatR / 2) * sin(dLatR / 2) +
              cos(pLat * pi / 180) *
                  cos(dLat * pi / 180) *
                  sin(dLngR / 2) *
                  sin(dLngR / 2);
          final c = 2 * atan2(sqrt(a), sqrt(1 - a));
          final dist = R * c;
          if (dist > 0.1) kmThisWeek += dist;
        }
      }
    } catch (_) {}

    // ── Average trip duration ─────────────────────────────────────────────────
    final avgMins = TripService.avgDurationMinutes(trips);
    final String avgTimeStr;
    if (avgMins == null) {
      avgTimeStr = '—';
    } else if (avgMins >= 60) {
      avgTimeStr = '${(avgMins / 60).toStringAsFixed(1)}h';
    } else {
      avgTimeStr = '${avgMins.toStringAsFixed(0)} min';
    }

    if (mounted) {
      setState(() {
        _trips = trips;
        _totalTrips = trips.length;
        _kmThisWeek =
            kmThisWeek > 0 ? '${kmThisWeek.toStringAsFixed(1)} km' : '0.0 km';
        _avgTime = avgTimeStr;
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const ResQAppBar(title: 'Trip History', showBack: false),
        body: _loading
            ? const ShimmerList(itemCount: 5, itemHeight: 120)
            : Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                  child: Row(children: [
                    StatCard(
                        label: 'TOTAL TRIPS', value: _totalTrips.toString()),
                    const SizedBox(width: 10),
                    StatCard(label: 'KM THIS WEEK', value: _kmThisWeek),
                    const SizedBox(width: 10),
                    StatCard(label: 'AVG TIME', value: _avgTime),
                  ]),
                ),
                Expanded(
                  child: _trips.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.receipt_long_outlined,
                                  color: AppColors.white40, size: 56),
                              const SizedBox(height: 12),
                              Text('No trips yet',
                                  style: AppTextStyles.bodyMedium(
                                      size: 16, color: AppColors.white40)),
                              const SizedBox(height: 4),
                              Text('Completed trips will appear here',
                                  style: AppTextStyles.body(
                                      size: 13, color: AppColors.white40)),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          color: AppColors.red,
                          backgroundColor: AppColors.surface2,
                          onRefresh: () async {
                            Haptics.light();
                            await _refresh();
                          },
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                            itemCount: _trips.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) => _TripTile(
                                key: ValueKey(_trips[i].id), trip: _trips[i]),
                          ),
                        ),
                ),
              ]),
      );
}

class _TripTile extends StatelessWidget {
  final Trip trip;
  const _TripTile({super.key, required this.trip});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          splashColor: AppColors.redDim,
          onTap: () {
            Haptics.light();
            // FIX: Navigate to trip summary detail screen
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _TripDetailScreen(trip: trip),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.white08),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                      color: AppColors.redDim,
                      borderRadius: BorderRadius.circular(7)),
                  child: Text(trip.date,
                      style: AppTextStyles.bodyMedium(
                          size: 10, color: AppColors.red)),
                ),
                const SizedBox(width: 8),
                Text(trip.caseId,
                    style:
                        AppTextStyles.body(size: 11, color: AppColors.white40)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.check_circle_rounded,
                        size: 10, color: AppColors.green),
                    const SizedBox(width: 3),
                    Text(trip.status,
                        style: AppTextStyles.body(
                            size: 10, color: AppColors.green)),
                  ]),
                ),
              ]),
              const SizedBox(height: 10),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Column(children: [
                  Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                          color: AppColors.white40, shape: BoxShape.circle)),
                  Container(width: 1, height: 22, color: AppColors.white15),
                  Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                          color: AppColors.red, shape: BoxShape.circle)),
                ]),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(trip.from,
                          style: AppTextStyles.body(
                              size: 12, color: AppColors.white70),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 12),
                      Text(
                        trip.to == '—' ? 'Hospital (no drop coords)' : trip.to,
                        style: AppTextStyles.bodyMedium(size: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                    color: AppColors.white08,
                    borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  const Icon(Icons.timer_outlined,
                      size: 13, color: AppColors.white40),
                  const SizedBox(width: 4),
                  Text(trip.duration,
                      style: AppTextStyles.body(
                          size: 11, color: AppColors.white70)),
                  const SizedBox(width: 14),
                  const Icon(Icons.straighten_rounded,
                      size: 13, color: AppColors.white40),
                  const SizedBox(width: 4),
                  Text(trip.distance,
                      style: AppTextStyles.body(
                          size: 11, color: AppColors.white70)),
                  const Spacer(),
                  Text('View Summary →',
                      style:
                          AppTextStyles.body(size: 10, color: AppColors.red)),
                ]),
              ),
            ]),
          ),
        ),
      );
}

// ══════════════════════════
// This is the screen that "View Summary" now navigates to
// ═══════════════════════════════════════════════════════════════════════════
class _TripDetailScreen extends StatelessWidget {
  final Trip trip;
  const _TripDetailScreen({required this.trip});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: ResQAppBar(
            title: 'Trip Summary', onBack: () => Navigator.pop(context)),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Stack(alignment: Alignment.center, children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.redMid, width: 1.5),
                    ),
                  ),
                  Container(
                    width: 88,
                    height: 88,
                    decoration: const BoxDecoration(
                        color: AppColors.red, shape: BoxShape.circle),
                    child: const Icon(Icons.check_rounded,
                        color: AppColors.white, size: 48),
                  ),
                ]),
              ),
              const SizedBox(height: 22),
              Text('Emergency Transport\nCompleted',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.heading(24)),
              const SizedBox(height: 8),
              Text('${trip.date}  •  ${trip.caseId}',
                  textAlign: TextAlign.center,
                  style:
                      AppTextStyles.body(size: 13, color: AppColors.white40)),
              const SizedBox(height: 28),
              Row(children: [
                _statBox(context, 'DISTANCE', trip.distance),
                const SizedBox(width: 14),
                _statBox(context, 'DURATION', trip.duration),
              ]),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.white08),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ROUTE', style: AppTextStyles.label()),
                    const SizedBox(height: 12),
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(children: [
                            Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                    color: AppColors.white40,
                                    shape: BoxShape.circle)),
                            Container(
                                width: 1, height: 30, color: AppColors.white15),
                            Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                    color: AppColors.red,
                                    shape: BoxShape.circle)),
                          ]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(trip.from,
                                    style: AppTextStyles.body(
                                        size: 13, color: AppColors.white70)),
                                const SizedBox(height: 22),
                                Text(
                                  trip.to == '—'
                                      ? 'Drop location not recorded'
                                      : trip.to,
                                  style: AppTextStyles.bodyMedium(size: 13),
                                ),
                              ],
                            ),
                          ),
                        ]),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back to Trips'),
              ),
            ],
          ),
        ),
      );

  Widget _statBox(BuildContext context, String label, String value) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
            color: AppColors.redDim,
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: AppTextStyles.label()),
            const SizedBox(height: 5),
            Text(value == '—' ? '—' : value,
                style: AppTextStyles.heading(20, color: AppColors.red)),
          ]),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// PROFILE TAB  — unchanged from your original (real data already)
// ══════════════════════════════════════════════════════════════════════════════

class DriverProfileTab extends StatefulWidget {
  final AppUser user;
  final bool onDuty;
  final bool loadingDuty;
  final Future<void> Function(bool) onDutyChanged;

  const DriverProfileTab({
    super.key,
    required this.user,
    required this.onDuty,
    required this.loadingDuty,
    required this.onDutyChanged,
  });

  @override
  State<DriverProfileTab> createState() => _DriverProfileTabState();
}

class _DriverProfileTabState extends State<DriverProfileTab> {
  static final _sb = Supabase.instance.client;

  bool _loading = false;
  bool _initialLoading = true;
  bool _editMode = false;
  String? _avatarUrl;
  String _vehicleType = 'Ambulance Type II';
  static const _vehicleTypes = [
    'Ambulance Type I',
    'Ambulance Type II',
    'Ambulance Type III',
    'Mobile ICU',
    'Patient Transport',
  ];

  Map<String, dynamic>? _profileData;
  Map<String, dynamic>? _driverData;
  Map<String, dynamic>? _ambulanceData;
  List<Map<String, dynamic>> _certifications = [];
  bool _certLoading = true;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _licenseCtrl;
  late final TextEditingController _expiryCtrl;
  late final TextEditingController _plateCtrl;
  late final TextEditingController _locationCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _licenseCtrl = TextEditingController();
    _expiryCtrl = TextEditingController();
    _plateCtrl = TextEditingController();
    _locationCtrl = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _phoneCtrl,
      _emailCtrl,
      _licenseCtrl,
      _expiryCtrl,
      _plateCtrl,
      _locationCtrl,
    ]) {
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
      final profile =
          await _sb.from('profiles').select().eq('id', authUser.id).single();
      final driverRow = await _sb
          .from('drivers')
          .select()
          .eq('user_id', authUser.id)
          .maybeSingle();

      Map<String, dynamic>? ambulanceRow;
      if (driverRow != null) {
        ambulanceRow = await _sb
            .from('ambulances')
            .select()
            .eq('driver_id', driverRow['id'])
            .maybeSingle();
      }

      if (!mounted) return;

      final dbVehicleType = ambulanceRow?['vehicle_type'] as String? ??
          driverRow?['vehicle_type'] as String? ??
          profile['vehicle_type'] as String?;
      final resolvedVehicleType = _vehicleTypes.contains(dbVehicleType)
          ? dbVehicleType!
          : 'Ambulance Type II';

      List<dynamic> certifications = [];
      if (driverRow != null) {
        certifications = await _sb
            .from('driver_certifications')
            .select()
            .eq('driver_id', driverRow['id']);
      }

      setState(() {
        _avatarUrl = profile['avatar_url'] as String?;
        _profileData = profile;
        _driverData = driverRow;
        _ambulanceData = ambulanceRow;
        _vehicleType = resolvedVehicleType;
        _certifications = List<Map<String, dynamic>>.from(certifications);
        _certLoading = false;
        _nameCtrl.text = profile['name'] as String? ?? widget.user.name;
        _phoneCtrl.text = profile['phone'] as String? ?? widget.user.phone;
        _emailCtrl.text = profile['email'] as String? ?? widget.user.email;
        _locationCtrl.text =
            profile['location'] as String? ?? widget.user.location;
        _licenseCtrl.text = driverRow?['license_number'] as String? ??
            widget.user.licenseNumber ??
            '';
        _expiryCtrl.text = driverRow?['license_expiry'] as String? ?? '';
        _plateCtrl.text = ambulanceRow?['vehicle_number'] as String? ??
            widget.user.vehiclePlate ??
            '';
        _initialLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _initialLoading = false);
    }
  }

  Future<void> _save() async {
    Haptics.heavy();
    setState(() => _loading = true);
    try {
      final userId = _sb.auth.currentUser?.id ?? widget.user.id;
      await _sb.from('profiles').update({
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
      }).eq('id', userId);
      if (_driverData != null) {
        await _sb.from('drivers').update({
          'license_number': _licenseCtrl.text.trim(),
          'license_expiry': _expiryCtrl.text.trim(),
          'base_location': _locationCtrl.text.trim(),
        }).eq('id', _driverData!['id']);
      }
      if (_ambulanceData != null) {
        await _sb.from('ambulances').update({
          'vehicle_type': _vehicleType,
          'vehicle_number': _plateCtrl.text.trim(),
        }).eq('id', _ambulanceData!['id']);
      }
      if (mounted) showSuccessSnack(context, 'Profile updated!');
    } catch (e) {
      if (mounted) showErrorSnack(context, 'Save failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
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

  Future<void> _changePhoto() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null || !mounted) return;
    setState(() => _loading = true);
    try {
      final userId = _sb.auth.currentUser?.id ?? widget.user.id;
      final url = await StorageService.uploadAvatar(userId, File(picked.path));
      if (mounted) setState(() => _avatarUrl = url);
      if (mounted) showSuccessSnack(context, 'Photo updated!');
    } catch (e) {
      if (mounted) showErrorSnack(context, 'Upload failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoading) {
      return Scaffold(
        appBar: const ResQAppBar(title: 'My Profile', showBack: false),
        backgroundColor: AppColors.bg,
        body: const Center(
          child:
              CircularProgressIndicator(color: AppColors.red, strokeWidth: 2),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('My Profile', style: AppTextStyles.heading(18)),
        actions: [
          if (!_editMode)
            IconButton(
              icon: const Icon(Icons.edit_rounded, color: AppColors.red),
              tooltip: 'Edit profile',
              onPressed: () => setState(() => _editMode = true),
            )
          else
            TextButton(
              onPressed: _loading
                  ? null
                  : () async {
                      await _save();
                      if (mounted) setState(() => _editMode = false);
                    },
              child: Text('Save',
                  style:
                      AppTextStyles.bodyMedium(size: 14, color: AppColors.red)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(children: [
          const SizedBox(height: 20),
          Semantics(
            label: 'Change profile photo',
            button: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(60),
              onTap: _changePhoto,
              child: Stack(alignment: Alignment.bottomRight, children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.red, width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 46,
                    backgroundColor: AppColors.surface2,
                    backgroundImage:
                        _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                    child: _avatarUrl == null
                        ? const Icon(Icons.person_rounded,
                            color: AppColors.white40, size: 42)
                        : null,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: const BoxDecoration(
                      color: AppColors.red, shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt,
                      size: 15, color: AppColors.white),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: _changePhoto,
            child: Text('Change Photo',
                style: AppTextStyles.body(size: 12, color: AppColors.red)),
          ),
          const SizedBox(height: 20),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: widget.onDuty
                  ? AppColors.green.withValues(alpha: 0.06)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.white08),
            ),
            child: Row(children: [
              const Icon(Icons.local_shipping_rounded,
                  color: AppColors.red, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('On Duty Status',
                        style: AppTextStyles.bodyMedium(size: 13)),
                    Text(
                      widget.onDuty
                          ? 'Accepting dispatch requests'
                          : 'Not accepting requests',
                      style: AppTextStyles.body(
                          size: 11, color: AppColors.white40),
                    ),
                  ],
                ),
              ),
              if (widget.loadingDuty)
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
              else
                Semantics(
                  label: widget.onDuty ? 'Set off duty' : 'Set on duty',
                  child: Switch(
                    value: widget.onDuty,
                    onChanged: (v) {
                      Haptics.medium();
                      widget.onDutyChanged(v);
                    },
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 16),
          ProfileField(
            label: 'FULL NAME',
            hint: 'Name',
            controller: _nameCtrl,
            readOnly: !_editMode,
          ),
          const SizedBox(height: 12),
          ProfileField(
              label: 'PHONE',
              hint: 'Phone',
              controller: _phoneCtrl,
              readOnly: !_editMode,
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone),
          const SizedBox(height: 12),
          ProfileField(
              label: 'EMAIL',
              hint: 'Email',
              controller: _emailCtrl,
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              readOnly: true),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('DRIVER CREDENTIALS',
                style: AppTextStyles.label(color: AppColors.red)),
          ),
          const SizedBox(height: 10),
          ProfileField(
              label: 'LICENSE NUMBER',
              hint: 'DL-12345-XYZ',
              controller: _licenseCtrl,
              readOnly: !_editMode,
              prefixIcon: Icons.badge_outlined),
          const SizedBox(height: 12),
          ProfileField(
              label: 'LICENSE EXPIRY',
              hint: 'Dec 2026',
              controller: _expiryCtrl,
              readOnly: !_editMode,
              prefixIcon: Icons.calendar_today_outlined),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('VEHICLE TYPE', style: AppTextStyles.label()),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _vehicleType,
            dropdownColor: AppColors.surface2,
            style: AppTextStyles.body(size: 13),
            decoration: const InputDecoration(),
            icon:
                const Icon(Icons.keyboard_arrow_down, color: AppColors.white40),
            items: _vehicleTypes
                .map((v) => DropdownMenuItem(
                    value: v,
                    child: Text(v, style: AppTextStyles.body(size: 13))))
                .toList(),
            onChanged: _editMode
                ? (v) {
                    if (v != null) {
                      Haptics.light();
                      setState(() => _vehicleType = v);
                    }
                  }
                : null,
          ),
          const SizedBox(height: 12),
          ProfileField(
              label: 'VEHICLE PLATE',
              hint: 'AMB-4521',
              controller: _plateCtrl,
              prefixIcon: Icons.directions_car_outlined,
              readOnly: !_editMode),
          const SizedBox(height: 12),
          LocationField(label: 'BASE LOCATION', controller: _locationCtrl),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: AppDecorations.cardSmall,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.verified_rounded,
                      color: AppColors.green, size: 16),
                  const SizedBox(width: 7),
                  Text('CERTIFICATIONS',
                      style: AppTextStyles.label(color: AppColors.green)),
                ]),
                const SizedBox(height: 10),
                _certLoading
                    ? const CircularProgressIndicator()
                    : _certifications.isEmpty
                        ? Text('No certifications on file',
                            style: AppTextStyles.body(
                                size: 12, color: AppColors.white40))
                        : Column(
                            children: _certifications.map((cert) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 5),
                                child: _certRow(
                                  cert['certification_name'] ?? '',
                                  cert['is_verified'] ?? false,
                                ),
                              );
                            }).toList(),
                          ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: AppColors.red, size: 18),
            label: Text('Sign Out',
                style:
                    AppTextStyles.bodyMedium(size: 14, color: AppColors.red)),
          ),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  Widget _certRow(String label, bool valid) => Row(children: [
        Icon(
          valid ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          color: valid ? AppColors.green : AppColors.white40,
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(label,
            style: AppTextStyles.body(
                size: 13,
                color: valid ? AppColors.white70 : AppColors.white40)),
      ]);
}

class _DriverFullscreenMap extends StatelessWidget {
  final double driverLat, driverLng, pickupLat, pickupLng;
  final double? dropLat, dropLng;
  final RidePhase phase;

  const _DriverFullscreenMap({
    required this.driverLat,
    required this.driverLng,
    required this.pickupLat,
    required this.pickupLng,
    this.dropLat,
    this.dropLng,
    required this.phase,
  });

  @override
  Widget build(BuildContext context) {
    final driver = LatLng(driverLat, driverLng);
    final pickup = LatLng(pickupLat, pickupLng);
    final toPickup = phase.index <= RidePhase.enRoute.index;
    return Scaffold(
      appBar:
          AppBar(title: const Text('Live Map'), backgroundColor: AppColors.bg),
      body: FlutterMap(
        options: MapOptions(
          initialCenter:
              LatLng((driverLat + pickupLat) / 2, (driverLng + pickupLng) / 2),
          initialZoom: 13,
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
          PolylineLayer(polylines: [
            Polyline(
              points: toPickup
                  ? [driver, pickup]
                  : (dropLat != null
                      ? [pickup, LatLng(dropLat!, dropLng!)]
                      : [driver, pickup]),
              strokeWidth: 4,
              color: toPickup ? AppColors.red : const Color(0xFF2196F3),
            ),
          ]),
          MarkerLayer(markers: [
            Marker(
                point: driver,
                width: 52,
                height: 52,
                child: Container(
                  decoration: BoxDecoration(
                      color: AppColors.red,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.red.withOpacity(0.5),
                            blurRadius: 12)
                      ]),
                  child: const Icon(Icons.local_shipping_rounded,
                      color: Colors.white, size: 26),
                )),
            Marker(
                point: pickup,
                width: 44,
                height: 60,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: AppColors.red, shape: BoxShape.circle),
                      child: const Icon(Icons.person_pin_rounded,
                          color: Colors.white, size: 18)),
                  Container(width: 2, height: 8, color: AppColors.red),
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                          color: AppColors.red,
                          borderRadius: BorderRadius.circular(4)),
                      child: const Text('Pickup',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold))),
                ])),
            if (dropLat != null && dropLng != null)
              Marker(
                  point: LatLng(dropLat!, dropLng!),
                  width: 44,
                  height: 60,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                            color: Color(0xFF2196F3), shape: BoxShape.circle),
                        child: const Icon(Icons.local_hospital_rounded,
                            color: Colors.white, size: 18)),
                    Container(
                        width: 2, height: 8, color: const Color(0xFF2196F3)),
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                            color: const Color(0xFF2196F3),
                            borderRadius: BorderRadius.circular(4)),
                        child: const Text('Hospital',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold))),
                  ])),
          ]),
        ],
      ),
    );
  }
}

class HospitalPickerScreen extends StatefulWidget {
  final double pickupLat;
  final double pickupLng;
  final String requestId;
  final String driverId;
  final VoidCallback onHospitalSelected;

  const HospitalPickerScreen({
    super.key,
    required this.pickupLat,
    required this.pickupLng,
    required this.requestId,
    required this.driverId,
    required this.onHospitalSelected,
  });

  @override
  State<HospitalPickerScreen> createState() => _HospitalPickerScreenState();
}

class _HospitalPickerScreenState extends State<HospitalPickerScreen> {
  List<Map<String, dynamic>> _hospitals = [];
  bool _loading = true;
  bool _selecting = false;
  int? _selectedIndex;

  static final _sb = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadHospitals();
  }

  Future<void> _loadHospitals() async {
    setState(() => _loading = true);
    try {
      // Search multiple queries in parallel for comprehensive results
      final futures = await Future.wait([
        HospitalLocationService.searchNearbyHospitals(
            widget.pickupLat, widget.pickupLng, 'hospital'),
        HospitalLocationService.searchNearbyHospitals(
            widget.pickupLat, widget.pickupLng, 'medical center'),
      ]);

      final all = <Map<String, dynamic>>[];
      for (final list in futures) {
        if (list != null) all.addAll(list);
      }

      // Deduplicate by name similarity + sort by distance
      final seen = <String>{};
      final unique = <Map<String, dynamic>>[];
      for (final h in all) {
        final key = (h['name'] as String)
            .toLowerCase()
            .substring(0, (h['name'] as String).length.clamp(0, 10));
        if (!seen.contains(key)) {
          seen.add(key);
          unique.add(h);
        }
      }
      unique
          .sort((a, b) => (a['dist'] as double).compareTo(b['dist'] as double));

      if (mounted) {
        setState(() {
          _hospitals = unique.take(8).toList(); // show top 8 nearest
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[HospitalPickerScreen] $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmSelection() async {
    if (_selectedIndex == null) {
      showErrorSnack(context, 'Please select a hospital');
      return;
    }
    setState(() => _selecting = true);
    final hospital = _hospitals[_selectedIndex!];
    try {
      // Write drop location to DB
      await _sb.from('ambulance_requests').update({
        'drop_location': hospital['name'],
        'drop_lat': hospital['lat'],
        'drop_lng': hospital['lng'],
      }).eq('id', widget.requestId);

      widget.onHospitalSelected();
    } catch (e) {
      if (mounted) showErrorSnack(context, 'Failed to set hospital: $e');
    } finally {
      if (mounted) setState(() => _selecting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text('Select Drop Hospital', style: AppTextStyles.heading(18)),
        ),
        body: Column(children: [
          // Info banner
          Container(
            margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.redDim,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.redMid),
            ),
            child: Row(children: [
              const Icon(Icons.local_hospital_rounded,
                  color: AppColors.red, size: 18),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(
                'Select the nearest hospital to drop the patient',
                style: AppTextStyles.body(size: 13, color: AppColors.white70),
              )),
            ]),
          ),
          const SizedBox(height: 12),

          // Hospital list
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.red, strokeWidth: 2))
                : _hospitals.isEmpty
                    ? Center(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.search_off,
                            color: AppColors.white40, size: 48),
                        const SizedBox(height: 12),
                        Text('No hospitals found nearby',
                            style: AppTextStyles.body(
                                size: 14, color: AppColors.white40)),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: _loadHospitals,
                          child: const Text('Retry'),
                        ),
                      ]))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                        itemCount: _hospitals.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final h = _hospitals[i];
                          final dist = h['dist'] as double;
                          final selected = _selectedIndex == i;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedIndex = i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.redDim
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected
                                      ? AppColors.red
                                      : AppColors.white08,
                                  width: selected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? AppColors.red
                                        : AppColors.white08,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.local_hospital_rounded,
                                    color: selected
                                        ? Colors.white
                                        : AppColors.white40,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(h['name'] as String,
                                        style:
                                            AppTextStyles.bodyMedium(size: 14),
                                        overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${dist.toStringAsFixed(1)} km away',
                                      style: AppTextStyles.body(
                                          size: 12,
                                          color: selected
                                              ? AppColors.red
                                              : AppColors.white40),
                                    ),
                                  ],
                                )),
                                if (selected)
                                  const Icon(Icons.check_circle_rounded,
                                      color: AppColors.red, size: 22),
                              ]),
                            ),
                          );
                        },
                      ),
          ),
        ]),

        // Confirm button
        bottomNavigationBar: Padding(
          padding: EdgeInsets.fromLTRB(
              20, 0, 20, MediaQuery.of(context).padding.bottom + 16),
          child: AnimatedPressButton(
            onTap: (_selecting || _selectedIndex == null)
                ? null
                : _confirmSelection,
            child: ElevatedButton.icon(
              onPressed: (_selecting || _selectedIndex == null)
                  ? null
                  : _confirmSelection,
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
              icon: _selecting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.local_hospital_rounded, size: 20),
              label: Text(_selecting
                  ? 'Setting hospital...'
                  : 'Confirm & Start Navigation'),
            ),
          ),
        ),
      );
}
