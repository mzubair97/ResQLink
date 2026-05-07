// modules/donor/donor_shell.dart
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
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

// ══════════════════════════════════════════════════════════════════════════════
// DONOR SHELL
// ══════════════════════════════════════════════════════════════════════════════

class DonorShell extends StatefulWidget {
  const DonorShell({super.key});
  @override
  State<DonorShell> createState() => _DonorShellState();
}

class _DonorShellState extends State<DonorShell> {
  int _index = 0;
  AppUser? _user;
  Map<String, dynamic>? _donorRow;
  bool _loading = true;
  final _availabilityNotifier = ValueNotifier<bool>(true);

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
      final donorRow = await _sb
          .from('donor_data')
          .select()
          .eq('donor_id', authUser.id)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _user =
              AppUser.fromProfile(profile, authUser.id, authUser.email ?? '');
          if (donorRow != null) {
            _user = AppUser(
              id: _user!.id,
              name: _user!.name,
              email: _user!.email,
              phone: _user!.phone,
              role: _user!.role,
              bloodType: donorRow['blood_type'] as String?,
              avatarUrl: _user!.avatarUrl,
              location: _user!.location,
            );
            _availabilityNotifier.value =
                donorRow['is_available'] as bool? ?? true;
          }
          _donorRow = donorRow;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _user = AppUser(
            id: authUser.id,
            name: 'Donor',
            email: authUser.email ?? '',
            phone: '',
            role: UserRole.donor,
          );
          _loading = false;
        });
      }
    }
  }

  void _goTab(int i) => setState(() => _index = i);

  @override
  void dispose() {
    _availabilityNotifier.dispose();
    super.dispose();
  }

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
          name: 'Donor',
          email: '',
          phone: '',
          role: UserRole.donor,
        );
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(index: _index, children: [
        DonorHomeTab(
          user: user,
          onRequestsTap: () => _goTab(1),
          onHistoryTap: () => _goTab(2),
          availabilityNotifier: _availabilityNotifier,
        ),
        DonorRequestsTab(
          user: user,
          availabilityNotifier: _availabilityNotifier,
        ),
        DonorHistoryTab(user: user),
        DonorProfileTab(
            user: user,
            donorRow: _donorRow,
            availabilityNotifier: _availabilityNotifier),
      ]),
      bottomNavigationBar: ResQBottomNav(
        currentIndex: _index,
        onTap: _goTab,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.water_drop), label: 'Requests'),
          BottomNavigationBarItem(
              icon: Icon(Icons.history_rounded), label: 'History'),
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

class DonorHomeTab extends StatefulWidget {
  final AppUser user;
  final VoidCallback onRequestsTap;
  final VoidCallback onHistoryTap;
  final ValueNotifier<bool> availabilityNotifier;

  const DonorHomeTab({
    super.key,
    required this.user,
    required this.onRequestsTap,
    required this.onHistoryTap,
    required this.availabilityNotifier,
  });

  @override
  State<DonorHomeTab> createState() => _DonorHomeTabState();
}

class _DonorHomeTabState extends State<DonorHomeTab>
    with SingleTickerProviderStateMixin {
  late AnimationController _listCtrl;

  @override
  void initState() {
    super.initState();
    _listCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
  }

  @override
  void dispose() {
    _listCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('RESQLINK',
                            style: AppTextStyles.label(color: AppColors.red)
                                .copyWith(letterSpacing: 2, fontSize: 12)),
                        Text('Donor Portal', style: AppTextStyles.heading(22)),
                      ]),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: AppDecorations.card,
              child: ValueListenableBuilder<bool>(
                valueListenable: widget.availabilityNotifier,
                builder: (_, available, __) => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.user.name,
                              style: AppTextStyles.bodyMedium(size: 16),
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 3),
                          Text(
                            '${widget.user.bloodType ?? "—"} Blood Type',
                            style: AppTextStyles.body(
                                size: 13, color: AppColors.red),
                          ),
                        ],
                      ),
                    ),
                    Column(children: [
                      Text('AVAILABLE',
                          style: AppTextStyles.label(color: AppColors.white40)),
                      const SizedBox(height: 4),
                      Switch(
                        value: available,
                        onChanged: (v) {
                          Haptics.medium();
                          widget.availabilityNotifier.value = v;
                        },
                      ),
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            FutureBuilder<int>(
              future: ProfileService.fetchPendingBloodRequestCount(),
              builder: (_, snap) {
                final count = snap.data ?? 0;
                return AlertBanner(
                  message: count > 0
                      ? '$count Urgent Request${count == 1 ? '' : 's'} Nearby'
                      : 'No urgent requests nearby right now',
                  actionLabel: count > 0 ? 'VIEW' : null,
                  onAction: count > 0 ? widget.onRequestsTap : null,
                  color: count > 0 ? AppColors.red : AppColors.green,
                );
              },
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'QUICK ACTIONS'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                _quickBtn(Icons.map_outlined, 'History', widget.onHistoryTap),
                const SizedBox(width: 10),
                _quickBtn(Icons.water_drop, 'Requests', widget.onRequestsTap),
              ]),
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'RECENT ACTIVITY'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: FutureBuilder<List<DonationRecord>>(
                future: DonationService.fetchDonationHistory(widget.user.id),
                builder: (_, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const ShimmerList(itemCount: 3, itemHeight: 72);
                  }
                  final records = snap.data ?? [];
                  if (records.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text('No donations yet',
                            style: AppTextStyles.body(
                                size: 13, color: AppColors.white40)),
                      ),
                    );
                  }
                  final recent = records.take(3).toList();
                  return Column(
                    children: staggeredItems(
                      recent
                          .map((r) => DonationHistoryTile(
                                date: r.date,
                                name: r.hospital,
                                type: r.type,
                                time: r.time,
                              ))
                          .toList(),
                      controller: _listCtrl,
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
      );

  Widget _quickBtn(IconData icon, String label, VoidCallback? onTap) =>
      Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            splashColor: AppColors.redDim,
            onTap: () {
              Haptics.light();
              onTap?.call();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(children: [
                Icon(icon, color: AppColors.red, size: 22),
                const SizedBox(height: 5),
                Text(label, style: AppTextStyles.body(size: 11)),
              ]),
            ),
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// REQUESTS TAB
// ══════════════════════════════════════════════════════════════════════════════

class DonorRequestsTab extends StatefulWidget {
  final AppUser user;
  final ValueNotifier<bool> availabilityNotifier;
  const DonorRequestsTab({
    super.key,
    required this.user,
    required this.availabilityNotifier,
  });
  @override
  State<DonorRequestsTab> createState() => _DonorRequestsTabState();
}

Key _requestsKey = UniqueKey();

class _DonorRequestsTabState extends State<DonorRequestsTab>
    with SingleTickerProviderStateMixin {
  BloodRequest? _selected;
  bool _accepted = false, _donating = false, _done = false;
  late AnimationController _listCtrl;

  @override
  void initState() {
    super.initState();
    _listCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
  }

  @override
  void dispose() {
    _listCtrl.dispose();
    super.dispose();
  }

  Future<List<BloodRequest>> _checkConnectivityAndFetch() async {
    final result = await Connectivity().checkConnectivity();
    if (result == ConnectivityResult.none) {
      throw Exception('offline');
    }
    try {
      return await RequestService.fetchNearbyBloodRequests();
    } catch (e) {
      // If Supabase fetch fails (network issue), treat as offline
      throw Exception('offline');
    }
  }

  void _reset() {
    _listCtrl.reset();
    _listCtrl.forward();
    setState(() {
      _selected = null;
      _accepted = false;
      _donating = false;
      _done = false;
      _requestsKey = UniqueKey();
    });
  }

  bool _canDonate(String? donorType, String requestType) {
    if (donorType == null) return true;
    final d = donorType.trim().toUpperCase();
    final r = requestType.trim().toUpperCase();
    if (d == 'O-') return true; // universal donor
    return d == r;
  }

  Future<bool> _isInCoolingPeriod() async {
    try {
      // ✅ Use Supabase.instance.client directly
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser!.id;

      print('🔍 Checking cooling period for donor: $userId');

      // Check for accepted (in-progress) donations first
      final acceptedRes = await client
          .from('donations')
          .select('id, status, completed_at')
          .eq('donor_id', userId)
          .eq('status', 'accepted') // ✅ Check for accepted donations
          .limit(1)
          .maybeSingle();

      // If donor has any accepted donations, they're in cooling period
      if (acceptedRes != null) {
        print('🔴 Donor has accepted donation - in cooling period');
        return true;
      }

      // Check for completed donations within 56 days
      final completedRes = await client
          .from('donations')
          .select('id, status, completed_at')
          .eq('donor_id', userId)
          .eq('status', 'completed')
          .not('completed_at', 'is', null) // ✅ Only check non-null completed_at
          .order('completed_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (completedRes == null) {
        print('✅ No donations found - donor is eligible');
        return false;
      }

      final completedAtStr = completedRes['completed_at'];
      if (completedAtStr == null) {
        print('✅ completed_at is null - donor is eligible');
        return false;
      }

      final completedAt = DateTime.parse(completedAtStr).toLocal();
      final nextEligible = completedAt.add(const Duration(days: 56));
      final isInCooling = DateTime.now().isBefore(nextEligible);

      print(' Completed at: $completedAt');
      print('🕐 Next eligible: $nextEligible');
      print('🔴 In cooling period: $isInCooling');

      return isInCooling;
    } catch (e) {
      print('❌ Cooling check error: $e');
      return false; // Safe fallback: allow donation if check fails
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return _completionScreen();
    if (_donating) return _donationScreen();
    if (_accepted && _selected != null)
      return _detailScreen(_selected!, accepted: true);
    if (_selected != null) return _detailScreen(_selected!, accepted: false);
    return _listScreen();
  }

  // ── List ──────────────────────────────────────────────────────────────────
  Widget _listScreen() => Scaffold(
        appBar: const ResQAppBar(title: 'Nearby Requests', showBack: false),
        body: ValueListenableBuilder<bool>(
          valueListenable: widget.availabilityNotifier,
          builder: (_, available, __) {
            if (!available) {
              return const EmptyState(
                icon: Icons.do_not_disturb_alt_rounded,
                title: 'You are Unavailable',
                subtitle: 'Turn on availability from Home tab to see requests.',
              );
            }
            return FutureBuilder<List<BloodRequest>>(
              key: _requestsKey,
              future: _checkConnectivityAndFetch(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const ShimmerList(itemCount: 4, itemHeight: 130);
                }
                if (snap.hasError) {
                  return const EmptyState(
                    icon: Icons.wifi_off_rounded,
                    title: 'No Internet Connection',
                    subtitle:
                        'Please check your internet connectivity and try again.',
                    retryLabel: 'Retry',
                    // onRetry stays as setState(() {})
                  );
                }
                final requests = snap.data ?? [];
                if (requests.isEmpty) {
                  return EmptyState(
                    icon: Icons.water_drop_outlined,
                    title: 'No Requests Nearby',
                    subtitle: 'Check back later or expand your search area.',
                    retryLabel: 'Refresh',
                    onRetry: () => setState(() {}),
                  );
                }
                return RefreshIndicator(
                  color: AppColors.red,
                  backgroundColor: AppColors.surface2,
                  onRefresh: () async {
                    Haptics.light();
                    await Future<void>.delayed(
                        const Duration(milliseconds: 800));
                    setState(() {});
                  },
                  child: ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    itemCount: requests.length,
                    itemBuilder: (_, i) {
                      final card = _RequestCard(
                        key: ValueKey(requests[i].id),
                        req: requests[i],
                        donorBloodType: widget.user.bloodType,
                        onAccept: () async {
                          // 🔴 CHECK BLOOD TYPE MATCH FIRST
                          final donorBT =
                              widget.user.bloodType?.trim().toUpperCase();
                          final reqBT =
                              requests[i].bloodType.trim().toUpperCase();
                          if (donorBT != null && !_canDonate(donorBT, reqBT)) {
                            if (mounted) {
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  backgroundColor: AppColors.surface,
                                  title: Text('Blood Type Mismatch',
                                      style:
                                          AppTextStyles.bodyMedium(size: 16)),
                                  content: Text(
                                    'This request requires $reqBT blood. Your blood type is $donorBT.',
                                    style: AppTextStyles.body(
                                        size: 13, color: AppColors.white40),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('OK',
                                          style:
                                              TextStyle(color: AppColors.red)),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return;
                          }
                          // 🔴 CHECK COOLING PERIOD FIRST
                          // 🔴 CHECK COOLING PERIOD FIRST
                          final inCooling = await _isInCoolingPeriod();
                          if (inCooling) {
                            if (mounted) {
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  backgroundColor: AppColors.surface,
                                  title: Text('Cooling Period Active',
                                      style:
                                          AppTextStyles.bodyMedium(size: 16)),
                                  content: Text(
                                      'You cannot donate yet. Please wait until your 56-day cooling period is complete. Check your History tab for details.',
                                      style: AppTextStyles.body(
                                          size: 13, color: AppColors.white40)),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('OK',
                                          style:
                                              TextStyle(color: AppColors.red)),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return; // 🔴 Stop here - don't accept request
                          }

                          // ✅ Cooling period passed - proceed with accept
                          final ok = await showConfirmDialog(
                            context,
                            title: 'Accept Donation Request?',
                            message:
                                'You are confirming availability to donate ${requests[i].bloodType} blood at ${requests[i].hospital}.',
                            confirmLabel: 'Accept',
                            cancelLabel: 'Cancel',
                          );
                          if (ok == true) {
                            Haptics.heavy();
                            setState(() {
                              _selected = requests[i];
                              _accepted = true;
                            });
                          }
                        },
                        onView: () => setState(() => _selected = requests[i]),
                      );
                      final interval = CurvedAnimation(
                        parent: _listCtrl,
                        curve: Interval((i * 0.1).clamp(0.0, 0.8), 1.0,
                            curve: Curves.easeOut),
                      );
                      return FadeTransition(
                        opacity: interval,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.1),
                            end: Offset.zero,
                          ).animate(interval),
                          child: card,
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      );

  // ── Detail ────────────────────────────────────────────────────────────────
  Widget _detailScreen(BloodRequest req, {required bool accepted}) {
    // Fix blood group display: "AB+" → letter="AB", sign="Positive"
    final bt = req.bloodType;
    final String letter;
    final String sign;
    if (bt.endsWith('+') || bt.endsWith('-')) {
      letter = bt.substring(0, bt.length - 1);
      sign = bt.endsWith('+') ? 'Positive' : 'Negative';
    } else {
      letter = bt;
      sign = '';
    }

    // Only show urgency text when actually urgent
    final urgency = req.urgencyLevel.toUpperCase();
    final isUrgent = urgency == 'URGENT' || urgency == 'CRITICAL';

    return Scaffold(
      appBar: ResQAppBar(
        title: 'Request Details',
        onBack: _reset,
        actions: [
          IconButton(
              icon: const Icon(Icons.share_outlined),
              onPressed: () => Haptics.light()),
          IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => Haptics.light()),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.redDim,
              border: Border.all(color: AppColors.redMid),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('⚠ EMERGENCY REQUEST',
                style: AppTextStyles.label(color: AppColors.red)
                    .copyWith(letterSpacing: 1)),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: AppColors.red,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(children: [
              Text('BLOOD GROUP REQUIRED',
                  style: AppTextStyles.label(color: Colors.white54)),
              const SizedBox(height: 8),
              // Show full blood group letters (AB, A, O, B etc)
              Text(letter, style: AppTextStyles.heading(72)),
              if (sign.isNotEmpty) Text(sign, style: AppTextStyles.heading(32)),
              const SizedBox(height: 8),
              // Only show if urgency is actually URGENT/CRITICAL
              if (isUrgent)
                Text('🕒 Urgent — respond quickly',
                    style: AppTextStyles.body(size: 12, color: Colors.white70)),
            ]),
          ),
          const SizedBox(height: 14),
          _infoRow(
            Icons.health_and_safety_rounded,
            'Donor Requirements',
            '18-65 yrs • 50kg+ • Hydrated',
          ),
          const SizedBox(height: 8),
          _infoRow(Icons.water_drop, '${req.units} Units Required',
              'Approximately ${req.units * 450}ml total'),
          const SizedBox(height: 8),
          _infoRow(
              Icons.location_on_outlined,
              req.address.isNotEmpty && req.address != req.hospital
                  ? req.address
                  : 'Karachi, Pakistan',
              'Urgency: ${req.urgencyLevel}'),
          const SizedBox(height: 28),
          if (!accepted) ...[
            AnimatedPressButton(
              onTap: () async {
                final ok = await showConfirmDialog(
                  context,
                  title: 'Accept Donation Request?',
                  message:
                      'Confirm availability to donate ${req.bloodType} at ${req.hospital}.',
                  confirmLabel: 'Accept',
                  cancelLabel: 'Cancel',
                );
                if (ok == true) {
                  Haptics.heavy();
                  setState(() {
                    _selected = req;
                    _accepted = true;
                  });
                }
              },
              child: ElevatedButton(
                onPressed: () async {
                  // 🔴 CHECK BLOOD TYPE MATCH FIRST
                  final donorBT = widget.user.bloodType?.trim().toUpperCase();
                  final reqBT = req.bloodType.trim().toUpperCase();
                  if (donorBT != null && !_canDonate(donorBT, reqBT)) {
                    if (mounted) {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          backgroundColor: AppColors.surface,
                          title: Text('Blood Type Mismatch',
                              style: AppTextStyles.bodyMedium(size: 16)),
                          content: Text(
                            'This request requires $reqBT blood. Your blood type is $donorBT.',
                            style: AppTextStyles.body(
                                size: 13, color: AppColors.white40),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('OK',
                                  style: TextStyle(color: AppColors.red)),
                            ),
                          ],
                        ),
                      );
                    }
                    return;
                  }
                  // 🔴 CHECK COOLING PERIOD FIRST
                  final inCooling = await _isInCoolingPeriod();
                  if (inCooling) {
                    if (mounted) {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          backgroundColor: AppColors.surface,
                          title: Text('Cooling Period Active',
                              style: AppTextStyles.bodyMedium(size: 16)),
                          content: Text(
                              'You cannot donate yet. Please wait until your 56-day cooling period is complete.',
                              style: AppTextStyles.body(
                                  size: 13, color: AppColors.white40)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('OK',
                                  style: TextStyle(color: AppColors.red)),
                            ),
                          ],
                        ),
                      );
                    }
                    return; // 🔴 Stop here
                  }

                  // ✅ Cooling period passed - proceed with accept
                  final ok = await showConfirmDialog(
                    context,
                    title: 'Accept Donation Request?',
                    message:
                        'Confirm availability to donate ${req.bloodType} at ${req.hospital}.',
                    confirmLabel: 'Accept',
                    cancelLabel: 'Cancel',
                  );
                  if (ok == true) {
                    Haptics.heavy();
                    setState(() {
                      _selected = req;
                      _accepted = true;
                    });
                  }
                },
                child: Row(mainAxisSize: MainAxisSize.min, children: const [
                  Icon(Icons.volunteer_activism, size: 18),
                  SizedBox(width: 8),
                  Text('Accept Donation'),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
                onPressed: _reset, child: const Text('Decline Request')),
          ] else ...[
            AnimatedPressButton(
              onTap: () {
                Haptics.medium();
                setState(() => _donating = true);
              },
              child: ElevatedButton(
                onPressed: () {
                  Haptics.medium();
                  setState(() => _donating = true);
                },
                child: Row(mainAxisSize: MainAxisSize.min, children: const [
                  Icon(Icons.water_drop_rounded, size: 18),
                  SizedBox(width: 8),
                  Text('Start Donation Process'),
                ]),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _infoRow(IconData icon, String title, String sub) => Container(
        padding: const EdgeInsets.all(13),
        decoration: AppDecorations.card,
        child: Row(children: [
          Icon(icon, color: AppColors.red, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.bodyMedium(size: 13),
                    overflow: TextOverflow.ellipsis),
                Text(sub,
                    style:
                        AppTextStyles.body(size: 11, color: AppColors.white40),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ]),
      );

  Widget _checkItem(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.redDim,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.red, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: AppTextStyles.body(size: 13, color: AppColors.white70)),
          ),
        ]),
      );
  // ── Donation Process ──────────────────────────────────────────────────────
  Widget _donationScreen() {
    final req = _selected;
    return Scaffold(
      appBar: ResQAppBar(
        title: 'Donation in Progress',
        onBack: () => setState(() => _donating = false),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          const SizedBox(height: 8),

          // Map with expand
          _DonationMapWidget(req: req),
          const SizedBox(height: 16),

          // Real request details from DB
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppDecorations.card,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('REQUEST DETAILS',
                  style: AppTextStyles.label(color: AppColors.red)),
              const SizedBox(height: 12),
              _detailRow(Icons.water_drop, 'Blood Type', req?.bloodType ?? '—'),
              const SizedBox(height: 8),
              _detailRow(Icons.local_hospital_rounded, 'Hospital',
                  req?.hospital ?? '—'),
              const SizedBox(height: 8),
              _detailRow(Icons.inventory_2_outlined, 'Units',
                  '${req?.units ?? 0} bag(s)'),
              const SizedBox(height: 8),
              _detailRow(Icons.warning_amber_rounded, 'Urgency',
                  req?.urgencyLevel ?? '—'),
            ]),
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppDecorations.card,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('WHAT TO BRING',
                  style: AppTextStyles.label(color: AppColors.red)),
              const SizedBox(height: 14),
              _checkItem(Icons.badge_outlined, 'Your CNIC / National ID Card'),
              _checkItem(Icons.phone_android_outlined,
                  'This app open (show request ID: ${req?.id ?? "—"})'),
              _checkItem(Icons.restaurant_outlined,
                  'Have a light meal before donating'),
              _checkItem(Icons.water_drop_outlined,
                  'Stay hydrated — drink water beforehand'),
              _checkItem(
                  Icons.watch_later_outlined, 'Allow 30 minutes of your time'),
            ]),
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(14),
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
                  .copyWith(fontStyle: FontStyle.italic),
            ),
          ),
          const SizedBox(height: 24),

          AnimatedPressButton(
            onTap: () async {
              Haptics.heavy();
              try {
                await DonationService.acceptDonationRequest(
                    _selected?.id ?? '', widget.user.id);
                if (mounted) setState(() => _done = true);
              } catch (e) {
                if (mounted && !_done) {
                  showErrorSnack(
                      context, e.toString().replaceFirst('Exception: ', ''));
                }
              }
            },
            child: ElevatedButton(
              onPressed: () async {
                Haptics.heavy();
                try {
                  await DonationService.acceptDonationRequest(
                      _selected?.id ?? '', widget.user.id);
                  if (mounted) setState(() => _done = true);
                } catch (e) {
                  if (mounted && !_done) {
                    showErrorSnack(
                        context, e.toString().replaceFirst('Exception: ', ''));
                  }
                }
              },
              child: Row(mainAxisSize: MainAxisSize.min, children: const [
                Icon(Icons.check_circle_outline, size: 18),
                SizedBox(width: 8),
                Text('Mark Donation Complete'),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) =>
      Row(children: [
        Icon(icon, color: AppColors.red, size: 16),
        const SizedBox(width: 8),
        Text('$label  ', style: AppTextStyles.label()),
        Expanded(
          child: Text(value,
              style: AppTextStyles.bodyMedium(size: 13),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end),
        ),
      ]);

  Widget _step(String num, String text, bool done) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? AppColors.green : AppColors.surface3,
            ),
            child: Center(
              child: done
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : Text(num,
                      style: AppTextStyles.body(
                          size: 11, color: AppColors.white40)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: AppTextStyles.body(
                    size: 13,
                    color: done ? AppColors.white70 : AppColors.white40)),
          ),
        ]),
      );

  // ── Completion ────────────────────────────────────────────────────────────
  Widget _completionScreen() => Scaffold(
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
              Text('Donation Accepted', style: AppTextStyles.heading(24)),
              const SizedBox(height: 8),
              Text(
                'Your contribution is being processed to save lives.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body(size: 14, color: AppColors.white40),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: AppDecorations.card,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('HOSPITAL DETAILS',
                          style: AppTextStyles.label(color: AppColors.red)),
                      const SizedBox(height: 6),
                      Text(_selected?.hospital ?? 'Hospital',
                          style: AppTextStyles.bodyMedium(size: 17)),
                      const SizedBox(height: 12),
                      Row(children: [
                        _detailCol('UNIT ID', _selected?.id ?? '—'),
                        const SizedBox(width: 32),
                        _detailCol('STATUS', 'Verified', isStatus: true),
                      ]),
                      const SizedBox(height: 12),
                      Text('LOCATION', style: AppTextStyles.label()),
                      const SizedBox(height: 3),
                      Text(_selected?.address ?? '—',
                          style: AppTextStyles.body(size: 13),
                          overflow: TextOverflow.ellipsis),
                    ]),
              ),
              const SizedBox(height: 28),
              AnimatedPressButton(
                onTap: _reset,
                child: ElevatedButton(
                  onPressed: _reset,
                  child: Row(mainAxisSize: MainAxisSize.min, children: const [
                    Icon(Icons.dashboard_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Back to Requests'),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      );

  Widget _detailCol(String label, String value, {bool isStatus = false}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppTextStyles.label()),
        const SizedBox(height: 3),
        Text(value,
            style: AppTextStyles.bodyMedium(
                size: 13, color: isStatus ? AppColors.green : AppColors.white)),
      ]);
}

// ══════════════════════════════════════════════════════════════════════════════
// MAP WIDGET
// ══════════════════════════════════════════════════════════════════════════════

/// ══════════════════════════════════════════════════════════════════════════════
// MAP WIDGET — Simple, Web-Compatible (like your old working code)
// ══════════════════════════════════════════════════════════════════════════════
class _DonationMapWidget extends StatefulWidget {
  final BloodRequest? req;
  const _DonationMapWidget({this.req});
  @override
  State<_DonationMapWidget> createState() => _DonationMapWidgetState();
}

class _DonationMapWidgetState extends State<_DonationMapWidget> {
  LatLng? _donorLocation;
  LatLng? _hospitalLocation;
  String _distanceText = 'Calculating...';
  String _driveTime = '';
  bool _locationLoading = true;
  static const _karachiCentre = LatLng(24.8607, 67.0011);

  @override
  void initState() {
    super.initState();
    _initLocations();
  }

  Future<void> _initLocations() async {
    // ── 1. Get donor GPS ──────────────────────────────────────────────────
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm == LocationPermission.whileInUse ||
            perm == LocationPermission.always) {
          final pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high);
          _donorLocation = LatLng(pos.latitude, pos.longitude);
        }
      }
    } catch (_) {}
    _donorLocation ??= _karachiCentre;

    // ── 2. Resolve hospital/customer location — 3-priority chain ─────────
    //
    //  Priority 1 ▸ Coordinates stored directly on the blood_requests row.
    //               Zero extra network calls — fastest and most accurate.
    //
    //  Priority 2 ▸ customer_data table lookup (for the customer_id on the
    //               request).  Used when the blood_request was created before
    //               lat/lng columns were added, or when the request row's
    //               coordinates are missing.
    //
    //  Priority 3 ▸ Nominatim reverse-geocoding of the address string.
    //               Pure fallback — only fires when both DB sources fail.
    //
    //  _karachiCentre is set only after all three sources have been tried.
    //
    final req = widget.req;
    if (req != null) {
      // ── Priority 1: coords already on the blood_requests row ───────────
      if (req.latitude != null && req.longitude != null) {
        _hospitalLocation = LatLng(req.latitude!, req.longitude!);
        debugPrint('[Map] ✅ Using blood_request stored coordinates');
      }

      // ── Priority 2: customer_data table ────────────────────────────────
      if (_hospitalLocation == null && req.customerId != null) {
        try {
          final locData =
              await DonationService.fetchCustomerLocation(req.customerId!);
          final lat = locData?['latitude'];
          final lng = locData?['longitude'];
          if (lat != null && lng != null) {
            _hospitalLocation = LatLng(lat, lng);
            debugPrint('[Map] ✅ Using customer_data coordinates');
          }
        } catch (e) {
          debugPrint('[Map] customer_data lookup failed: $e');
        }
      }

      // ── Priority 3: Nominatim geocoding (last resort) ──────────────────
      if (_hospitalLocation == null && req.address.isNotEmpty) {
        try {
          final query = '${req.address}, Karachi, Pakistan';
          final geoUri = Uri.parse(
            'https://nominatim.openstreetmap.org/search'
            '?q=${Uri.encodeComponent(query)}'
            '&format=json&limit=1',
          );
          final geoRes = await http.get(
            geoUri,
            headers: {'User-Agent': 'ResQLink/1.0'},
          );
          if (geoRes.statusCode == 200) {
            final results = jsonDecode(geoRes.body) as List;
            if (results.isNotEmpty) {
              final lat = double.parse(results[0]['lat']);
              final lon = double.parse(results[0]['lon']);
              _hospitalLocation = LatLng(lat, lon);
              debugPrint('[Map] ✅ Using Nominatim geocoded coordinates');
            }
          }
        } catch (e) {
          debugPrint('[Map] Nominatim geocoding error: $e');
        }
      }
    }

    // All three sources failed — use centre of Karachi as last-resort fallback
    if (_hospitalLocation == null) {
      debugPrint(
          '[Map] ⚠️  All location sources failed — defaulting to Karachi centre');
    }
    _hospitalLocation ??= _karachiCentre;

    // ── 3. Calculate distance & drive time ────────────────────────────────
    final distMetres = const Distance().as(
      LengthUnit.Meter,
      _donorLocation!,
      _hospitalLocation!,
    );
    final straightKm = distMetres / 1000;
    // Apply 1.3× road factor — straight-line is always shorter than road distance
    final roadKm = straightKm * 1.3;
    // City driving average 25 km/h with traffic
    final driveMinutes = (roadKm / 25 * 60).round();

    // Only update state once — prevents the map from snapping to _karachiCentre
    // before the async resolution above completes.
    if (mounted) {
      setState(() {
        _distanceText = '~${roadKm.toStringAsFixed(1)} km to hospital';
        _driveTime = '~$driveMinutes min drive';
        _locationLoading = false; // ← map renders ONLY after resolution is done
      });
    }
  }

  void _openFullScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenMapPage(
          donorLocation: _donorLocation ?? _karachiCentre,
          hospitalLocation: _hospitalLocation ?? _karachiCentre,
          hospitalName: widget.req?.hospital ?? 'Hospital',
          distanceText: _distanceText,
          driveTime: _driveTime,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_locationLoading) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.white08),
        ),
        child: const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(color: AppColors.red, strokeWidth: 2),
            SizedBox(height: 10),
            Text('Getting location...',
                style: TextStyle(color: AppColors.white40, fontSize: 12)),
          ]),
        ),
      );
    }

    final donor = _donorLocation ?? _karachiCentre;
    final hospital = _hospitalLocation ?? _karachiCentre;
    final centre = LatLng(
      (donor.latitude + hospital.latitude) / 2,
      (donor.longitude + hospital.longitude) / 2,
    );

    return Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 200,
          child: Stack(children: [
            // ✅ Simple FlutterMap - no GestureDetector wrapper
            FlutterMap(
              options: MapOptions(
                initialCenter: centre,
                initialZoom: 13,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag
                      .none, // preview only, tap Expand to interact
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.resqlink.app',
                ),
                PolylineLayer(polylines: [
                  Polyline(
                    points: [donor, hospital],
                    color: Colors.green,
                    strokeWidth: 4,
                  ),
                ]),
                MarkerLayer(markers: [
                  Marker(
                    point: donor,
                    width: 44,
                    height: 44,
                    child: const _DonorMarker(),
                  ),
                  Marker(
                    point: hospital,
                    width: 44,
                    height: 44,
                    child: const _HospitalMarker(),
                  ),
                ]),
              ],
            ),
            // ✅ Expand button using InkWell (web-safe)
            Positioned(
              top: 10,
              right: 10,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _openFullScreen,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.72),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.fullscreen, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text('Expand',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.white08),
        ),
        child: Row(children: [
          const Icon(Icons.directions_car_rounded,
              color: AppColors.green, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Text(_distanceText,
                  style: AppTextStyles.bodyMedium(size: 13))),
          Text(_driveTime,
              style: AppTextStyles.body(size: 12, color: AppColors.white40)),
        ]),
      ),
    ]);
  }
}

// ── Full Screen Map ───────────────────────────────────────────────────────────
class _FullScreenMapPage extends StatelessWidget {
  final LatLng donorLocation;
  final LatLng hospitalLocation;
  final String hospitalName;
  final String distanceText;
  final String driveTime;

  const _FullScreenMapPage({
    required this.donorLocation,
    required this.hospitalLocation,
    required this.hospitalName,
    required this.distanceText,
    required this.driveTime,
  });

  @override
  Widget build(BuildContext context) {
    final centre = LatLng(
      (donorLocation.latitude + hospitalLocation.latitude) / 2,
      (donorLocation.longitude + hospitalLocation.longitude) / 2,
    );
    final latDiff = (donorLocation.latitude - hospitalLocation.latitude).abs();
    final lngDiff =
        (donorLocation.longitude - hospitalLocation.longitude).abs();
    final maxDiff = math.max(latDiff, lngDiff);
    final zoom = maxDiff < 0.01
        ? 15.0
        : maxDiff < 0.05
            ? 13.0
            : maxDiff < 0.1
                ? 12.0
                : 11.0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Route to $hospitalName',
            style: AppTextStyles.bodyMedium(size: 15)),
      ),
      // ── Use Scaffold body directly — gives FlutterMap a proper bounded box
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand, // ← forces Stack to fill Expanded
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: centre,
                    initialZoom: zoom,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.resqlink.app',
                    ),
                    PolylineLayer(polylines: [
                      Polyline(
                        points: [donorLocation, hospitalLocation],
                        color: Colors.green,
                        strokeWidth: 5,
                      ),
                    ]),
                    MarkerLayer(markers: [
                      Marker(
                        point: donorLocation,
                        width: 52,
                        height: 52,
                        child: const _DonorMarker(),
                      ),
                      Marker(
                        point: hospitalLocation,
                        width: 52,
                        height: 52,
                        child: const _HospitalMarker(),
                      ),
                    ]),
                  ],
                ),
                // Legend — IgnorePointer so map stays interactive
                Positioned(
                  top: 12,
                  right: 12,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _legendItem(Colors.blue, 'Your location'),
                          const SizedBox(height: 6),
                          _legendItem(AppColors.red, 'Hospital'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Bottom bar — outside Expanded so it has a natural height
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.green,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.directions_car_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(distanceText,
                            style: AppTextStyles.bodyMedium(size: 15)),
                        Text(driveTime,
                            style: AppTextStyles.body(
                                size: 12, color: AppColors.white40)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // ── NAVIGATE button with fixed width — fixes infinite width error
                  SizedBox(
                    width: 120,
                    child: ElevatedButton(
                      onPressed: () async {
                        final url = Uri.parse(
                            'https://www.google.com/maps/dir/?api=1'
                            '&origin=${donorLocation.latitude},${donorLocation.longitude}'
                            '&destination=${hospitalLocation.latitude},${hospitalLocation.longitude}'
                            '&travelmode=driving');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.green,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('NAVIGATE',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 11)),
        ],
      );
}
// ── Markers ───────────────────────────────────────────────────────────────────

class _DonorMarker extends StatelessWidget {
  const _DonorMarker();
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
                color: Colors.blue.withOpacity(0.4),
                blurRadius: 8,
                spreadRadius: 2)
          ],
        ),
        child: const Icon(Icons.person_pin_circle_rounded,
            color: Colors.white, size: 22),
      );
}

class _HospitalMarker extends StatelessWidget {
  const _HospitalMarker();
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.red,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
                color: AppColors.red.withOpacity(0.4),
                blurRadius: 8,
                spreadRadius: 2)
          ],
        ),
        child: const Icon(Icons.local_hospital_rounded,
            color: Colors.white, size: 22),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// REQUEST CARD
// ══════════════════════════════════════════════════════════════════════════════

class _RequestCard extends StatelessWidget {
  final BloodRequest req;
  final VoidCallback onAccept, onView;
  final String? donorBloodType;

  const _RequestCard({
    super.key,
    required this.req,
    required this.onAccept,
    required this.onView,
    this.donorBloodType,
  });

  Color get _urgColor {
    if (req.urgencyLevel == 'CRITICAL') return AppColors.red;
    if (req.urgencyLevel == 'URGENT') return AppColors.orange;
    return AppColors.white40;
  }

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          splashColor: AppColors.redDim,
          onTap: onView,
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.white08),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black38, offset: Offset(0, 2), blurRadius: 8),
              ],
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                      color: (donorBloodType == null ||
                              donorBloodType!.trim().toUpperCase() == 'O-' ||
                              req.bloodType.trim().toUpperCase() ==
                                  donorBloodType!.trim().toUpperCase())
                          ? AppColors.red
                          : AppColors.surface,
                      shape: BoxShape.circle),
                  child: Center(
                      child: Text(req.bloodType,
                          style: AppTextStyles.bodyMedium(size: 13))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: _urgColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(req.urgencyLevel,
                              style: AppTextStyles.label(color: _urgColor)),
                        ),
                        const SizedBox(height: 3),
                        Text(req.hospital,
                            style: AppTextStyles.bodyMedium(size: 14),
                            overflow: TextOverflow.ellipsis),
                      ]),
                ),
                if (req.distance != 'N/A' && req.distance.isNotEmpty)
                  Text('${req.distance}\nDIST',
                      textAlign: TextAlign.right,
                      style: AppTextStyles.body(
                          size: 10, color: AppColors.white40)),
              ]),
              if (req.address.isNotEmpty &&
                  req.address.toLowerCase() != req.hospital.toLowerCase())
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(req.address,
                      style: AppTextStyles.body(
                          size: 12, color: AppColors.white40),
                      overflow: TextOverflow.ellipsis),
                )
              else
                const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: Builder(builder: (context) {
                    final bool match = donorBloodType == null ||
                        donorBloodType!.trim().toUpperCase() == 'O-' ||
                        req.bloodType.trim().toUpperCase() ==
                            donorBloodType!.trim().toUpperCase();
                    if (match) {
                      return AnimatedPressButton(
                        onTap: onAccept,
                        child: ElevatedButton(
                          onPressed: onAccept,
                          style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(42)),
                          child: const Text('Accept'),
                        ),
                      );
                    }
                    return Tooltip(
                      message:
                          'Your blood type ($donorBloodType) does not match this request (${req.bloodType})',
                      child: ElevatedButton(
                        onPressed: null,
                        style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(42)),
                        child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.lock_outline, size: 14),
                              SizedBox(width: 6),
                              Text('Accept'),
                            ]),
                      ),
                    );
                  }),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Haptics.light();
                      onView();
                    },
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(42)),
                    child: const Text('Details'),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      );
}
// ══════════════════════════════════════════════════════════════════════════════
// HISTORY TAB WITH COOLING PERIOD
// ══════════════════════════════════════════════════════════════════════════════

class DonorHistoryTab extends StatefulWidget {
  final AppUser user;
  const DonorHistoryTab({super.key, required this.user});
  @override
  State<DonorHistoryTab> createState() => _DonorHistoryTabState();
}

class _DonorHistoryTabState extends State<DonorHistoryTab> {
  // ── Cooling period logic ───────────────────────────────────────────────────
  int _coolingDays(String bloodType) {
    // Whole blood donation = 56 days cooling period (standard)
    return 56;
  }

  DateTime _nextEligible(DateTime completedAt, String bloodType) =>
      completedAt.add(Duration(days: _coolingDays(bloodType)));

  int _daysRemaining(DateTime completedAt, String bloodType) {
    final next = _nextEligible(completedAt, bloodType);
    final diff = next.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  bool _isEligible(DateTime completedAt, String bloodType) =>
      DateTime.now().isAfter(_nextEligible(completedAt, bloodType));

  double _coolingProgress(DateTime completedAt, String bloodType) {
    final total = _coolingDays(bloodType);
    final elapsed = DateTime.now().difference(completedAt).inDays;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: ResQAppBar(
        title: 'Donation History',
        showBack: false,
        actions: [
          IconButton(
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.white08,
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(Icons.filter_list, size: 18),
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: FutureBuilder<List<DonationRecord>>(
        future: DonationService.fetchDonationHistory(widget.user.id),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(
                    color: AppColors.red, strokeWidth: 2));
          }
          if (snap.hasError) {
            return Center(
                child: Text('Error: ${snap.error}',
                    style: AppTextStyles.body(color: AppColors.white40)));
          }

          final records = snap.data ?? [];

          // ── Stats ───────────────────────────────────────────────────────
          final totalDonations = records.length;
          final livesImpacted = totalDonations * 3;

          // Most recent completed donation for eligibility banner
          DonationRecord? latest = records.isNotEmpty ? records.first : null;

          // ── Group by year ─────────────────────────────────────────────────
          final Map<String, List<DonationRecord>> byYear = {};
          for (final r in records) {
            byYear.putIfAbsent(r.year, () => []).add(r);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Eligibility Banner ──────────────────────────────────────
                if (latest != null) _eligibilityBanner(latest),

                // ── Stats Row ───────────────────────────────────────────────
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      _statCard('TOTAL DONATIONS',
                          totalDonations.toString().padLeft(2, '0')),
                      const SizedBox(width: 10),
                      _statCard('LIVES IMPACTED',
                          livesImpacted.toString().padLeft(2, '0')),
                      const SizedBox(width: 10),
                      _nextDonationCard(latest),
                    ],
                  ),
                ),

                // ── Grouped History ─────────────────────────────────────────
                if (records.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                        child: Text('No donations yet',
                            style:
                                AppTextStyles.body(color: AppColors.white40))),
                  )
                else
                  ...byYear.entries.map((entry) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Text('${entry.key} CONTRIBUTIONS',
                                style: AppTextStyles.label(
                                    color: AppColors.white40)),
                          ),
                          ...entry.value.map((r) => _donationCard(r)).toList(),
                        ],
                      )),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Eligibility Banner ─────────────────────────────────────────────────────
  Widget _eligibilityBanner(DonationRecord latest) {
    final eligible = _isEligible(latest.completedAtDate, latest.type);
    final days = _daysRemaining(latest.completedAtDate, latest.type);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: eligible
            ? const Color(0xFF0D2B1A) // dark green tint
            : const Color(0xFF2B0D0D), // dark red tint
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: eligible
              ? const Color(0xFF22C55E).withOpacity(0.4)
              : AppColors.red.withOpacity(0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            eligible
                ? Icons.check_circle_rounded
                : Icons.hourglass_bottom_rounded,
            color: eligible ? const Color(0xFF22C55E) : AppColors.red,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: eligible
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('You are eligible to donate!',
                          style: AppTextStyles.bodyMedium(size: 13)
                              .copyWith(color: const Color(0xFF22C55E))),
                      Text('Your body has fully recovered. Thank you!',
                          style: AppTextStyles.body(
                              size: 11, color: AppColors.white40)),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cooling period active — $days days left',
                          style: AppTextStyles.bodyMedium(size: 13)
                              .copyWith(color: AppColors.red)),
                      Text(
                          'Next eligible: ${_formatDate(_nextEligible(latest.completedAtDate, latest.type))}',
                          style: AppTextStyles.body(
                              size: 11, color: AppColors.white40)),
                    ],
                  ),
          ),
          if (eligible)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: const Color(0xFF22C55E).withOpacity(0.4)),
              ),
              child: Text('DONATE',
                  style: AppTextStyles.label(color: const Color(0xFF22C55E))),
            ),
        ],
      ),
    );
  }

  // ── Stat Card ──────────────────────────────────────────────────────────────
  Widget _statCard(String label, String value) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: AppDecorations.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: AppTextStyles.label(color: AppColors.white40)
                      .copyWith(fontSize: 9)),
              const SizedBox(height: 6),
              Text(value,
                  style:
                      AppTextStyles.heading(26).copyWith(color: AppColors.red)),
            ],
          ),
        ),
      );

  // ── Next Donation Card ─────────────────────────────────────────────────────
  Widget _nextDonationCard(DonationRecord? latest) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: AppDecorations.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('NEXT DONATION',
                  style: AppTextStyles.label(color: AppColors.white40)
                      .copyWith(fontSize: 9)),
              const SizedBox(height: 6),
              if (latest == null)
                Text('N/A',
                    style: AppTextStyles.heading(18)
                        .copyWith(color: AppColors.white40))
              else if (_isEligible(latest.completedAtDate, latest.type))
                Text('Now ✓',
                    style: AppTextStyles.heading(18)
                        .copyWith(color: const Color(0xFF22C55E)))
              else
                Text(
                  '${_daysRemaining(latest.completedAtDate, latest.type)}d left',
                  style:
                      AppTextStyles.heading(18).copyWith(color: AppColors.red),
                ),
            ],
          ),
        ),
      );

  // ── Donation Card ──────────────────────────────────────────────────────────
  Widget _donationCard(DonationRecord r) {
    final eligible = _isEligible(r.completedAtDate, r.type);
    final progress = _coolingProgress(r.completedAtDate, r.type);
    final days = _daysRemaining(r.completedAtDate, r.type);
    final nextDate = _nextEligible(r.completedAtDate, r.type);
    final cooling = _coolingDays(r.type);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(color: AppColors.red, width: 3), // red left accent
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row ──────────────────────────────────────────────────
            Row(
              children: [
                // Date pill
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.redDim,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(r.date,
                      style: AppTextStyles.label(color: AppColors.red)
                          .copyWith(fontSize: 11)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.hospital,
                          style: AppTextStyles.bodyMedium(size: 13),
                          overflow: TextOverflow.ellipsis),
                      Row(
                        children: [
                          const Icon(Icons.water_drop,
                              color: AppColors.red, size: 11),
                          const SizedBox(width: 4),
                          Text(r.type,
                              style: AppTextStyles.body(
                                  size: 11, color: AppColors.red)),
                        ],
                      ),
                    ],
                  ),
                ),
                // Status badge
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: Color(0xFF22C55E), size: 13),
                        const SizedBox(width: 4),
                        Text('Done',
                            style: AppTextStyles.body(
                                size: 12, color: const Color(0xFF22C55E))),
                      ],
                    ),
                    Text(r.time,
                        style: AppTextStyles.body(
                            size: 11, color: AppColors.white40)),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Cooling period progress bar ───────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  eligible ? 'Cooling complete' : '$days days remaining',
                  style: AppTextStyles.body(
                      size: 10,
                      color: eligible
                          ? const Color(0xFF22C55E)
                          : AppColors.white40),
                ),
                Text(
                  eligible
                      ? '✓ Eligible now'
                      : 'Next: ${_formatDate(nextDate)}',
                  style: AppTextStyles.body(
                      size: 10,
                      color: eligible
                          ? const Color(0xFF22C55E)
                          : AppColors.white40),
                ),
              ],
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: AppColors.white08,
                valueColor: AlwaysStoppedAnimation<Color>(
                  eligible
                      ? const Color(0xFF22C55E)
                      : progress > 0.6
                          ? AppColors.red
                          : Colors.orange,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              eligible
                  ? '56-day cooling period complete'
                  : '${(progress * 100).toInt()}% of 56-day cooling period done',
              style: AppTextStyles.body(size: 9, color: AppColors.white40),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PROFILE TAB
// ══════════════════════════════════════════════════════════════════════════════

class DonorProfileTab extends StatefulWidget {
  final AppUser user;
  final Map<String, dynamic>? donorRow;
  final ValueNotifier<bool> availabilityNotifier;

  const DonorProfileTab({
    super.key,
    required this.user,
    this.donorRow,
    required this.availabilityNotifier,
  });

  @override
  State<DonorProfileTab> createState() => _DonorProfileTabState();
}

class _DonorProfileTabState extends State<DonorProfileTab> {
  static final _sb = Supabase.instance.client;
  bool _loading = false;
  bool _initialLoading = true;
  bool _uploadingPhoto = false;
  String? _avatarUrl;
  Map<String, dynamic>? _donorData;

  String get _bloodGroup =>
      _donorData?['blood_type'] as String? ??
      widget.user.bloodType ??
      'Not Set';

  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _locationCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _locationCtrl = TextEditingController();
    _avatarUrl = widget.user.avatarUrl;
    _loadProfile();
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
      final donorData = await _sb
          .from('donor_data')
          .select()
          .eq('donor_id', authUser.id)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _donorData = donorData;
        _avatarUrl = profile['avatar_url'] as String?;
        _nameCtrl.text = profile['name'] as String? ?? widget.user.name;
        _phoneCtrl.text = profile['phone'] as String? ?? widget.user.phone;
        _emailCtrl.text = profile['email'] as String? ?? widget.user.email;
        _locationCtrl.text =
            donorData?['address'] as String? ?? widget.user.location ?? '';
        if (donorData != null) {
          widget.availabilityNotifier.value =
              donorData['is_available'] as bool? ?? true;
        }
        _initialLoading = false;
      });
    } catch (e) {
      debugPrint('[DonorProfile] error: $e');
      if (mounted) {
        _nameCtrl.text = widget.user.name;
        _phoneCtrl.text = widget.user.phone;
        _emailCtrl.text = widget.user.email;
        _locationCtrl.text = widget.user.location ?? '';
        setState(() => _initialLoading = false);
      }
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
      await _sb.from('donor_data').upsert({
        'donor_id': userId,
        'is_available': widget.availabilityNotifier.value,
        'address': _locationCtrl.text.trim(),
      }, onConflict: 'donor_id');
      if (mounted) showSuccessSnack(context, 'Profile updated!');
    } catch (e) {
      if (mounted) showErrorSnack(context, 'Save failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    final ok = await showConfirmDialog(context,
        title: 'Sign Out?',
        message: 'You will be returned to the login screen.',
        confirmLabel: 'Sign Out',
        cancelLabel: 'Cancel',
        danger: true);
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
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;
    setState(() => _uploadingPhoto = true);
    try {
      final url = await StorageService.uploadAvatar(
        widget.user.id,
        File(picked.path),
      );
      // Add timestamp to bust cache and force image refresh
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
      appBar: const ResQAppBar(title: 'My Profile', showBack: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(children: [
          const SizedBox(height: 20),
          // ── Avatar ──────────────────────────────────────────────────────
          Semantics(
            label: 'Change profile photo',
            button: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(60),
              onTap: _uploadingPhoto ? null : _changePhoto,
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
                  child: _uploadingPhoto
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.camera_alt,
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
          const SizedBox(height: 22),

          // ── Availability toggle ─────────────────────────────────────────
          ValueListenableBuilder<bool>(
            valueListenable: widget.availabilityNotifier,
            builder: (_, available, __) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: available
                    ? AppColors.green.withValues(alpha: 0.06)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.white08),
              ),
              child: Row(children: [
                const Icon(Icons.notifications_active,
                    color: AppColors.red, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Available for Donations',
                          style: AppTextStyles.bodyMedium(size: 13)),
                      Text('Receive blood request alerts',
                          style: AppTextStyles.body(
                              size: 11, color: AppColors.white40)),
                    ],
                  ),
                ),
                Semantics(
                  label: available ? 'Mark unavailable' : 'Mark available',
                  child: Switch(
                    value: available,
                    onChanged: (v) {
                      Haptics.medium();
                      widget.availabilityNotifier.value = v;
                    },
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 18),

          // ── Fields ──────────────────────────────────────────────────────
          ProfileField(
              label: 'FULL NAME', hint: 'Your name', controller: _nameCtrl),
          const SizedBox(height: 12),
          ProfileField(
              label: 'PHONE',
              hint: 'Phone',
              controller: _phoneCtrl,
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
          const SizedBox(height: 12),
          // LocationField has built-in GPS detect button (my_location icon)
          LocationField(label: 'CURRENT LOCATION', controller: _locationCtrl),
          const SizedBox(height: 18),

          // ── Blood group (read-only) ────────────────────────────────────
          Align(
            alignment: Alignment.centerLeft,
            child: Text('BLOOD GROUP', style: AppTextStyles.label()),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.white08),
            ),
            child: Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                    color: AppColors.redDim, shape: BoxShape.circle),
                child: Center(
                    child: Text(_bloodGroup,
                        style: AppTextStyles.bodyMedium(
                            size: 15, color: AppColors.red))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_bloodGroup,
                        style: AppTextStyles.bodyMedium(size: 15)),
                    Text('Verified — read only',
                        style: AppTextStyles.body(
                            size: 11, color: AppColors.white40)),
                  ],
                ),
              ),
            ]),
          ),
          const SizedBox(height: 14),

          // ── Last donation ─────────────────────────────────────────────
          FutureBuilder<Map<String, dynamic>?>(
            future: ProfileService.fetchLastDonation(widget.user.id),
            builder: (_, snap) {
              String lastDonationText = 'No donations yet';
              if (snap.connectionState == ConnectionState.waiting) {
                lastDonationText = 'Loading...';
              } else if (snap.hasData && snap.data != null) {
                final d = snap.data!;
                final req = d['blood_requests'] as Map? ?? {};
                final hospital = req['hospital'] ?? 'Unknown Hospital';
                final rawDate = d['created_at'] ?? d['completed_at'];
                String dateStr = '';
                if (rawDate != null) {
                  final dt = DateTime.tryParse(rawDate.toString())?.toLocal();
                  if (dt != null) {
                    const months = [
                      'Jan',
                      'Feb',
                      'Mar',
                      'Apr',
                      'May',
                      'Jun',
                      'Jul',
                      'Aug',
                      'Sep',
                      'Oct',
                      'Nov',
                      'Dec'
                    ];
                    dateStr = '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
                  }
                }
                lastDonationText =
                    dateStr.isNotEmpty ? '$dateStr — $hospital' : hospital;
              }
              return Container(
                padding: const EdgeInsets.all(13),
                decoration: AppDecorations.cardSmall,
                child: Row(children: [
                  const Icon(Icons.history_rounded,
                      color: AppColors.red, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Last Donation', style: AppTextStyles.label()),
                        const SizedBox(height: 2),
                        Text(lastDonationText,
                            style: AppTextStyles.body(
                                size: 12, color: AppColors.white70),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ]),
              );
            },
          ),
          const SizedBox(height: 28),

          // ── Save ────────────────────────────────────────────────────────
          AnimatedPressButton(
            onTap: _loading ? null : _save,
            child: ElevatedButton(
              onPressed: _loading ? null : _save,
              style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30))),
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
}
