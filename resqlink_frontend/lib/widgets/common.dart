// widgets/common.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/location_service.dart'; // Real GPS reverse-geocoding

// ─────────────────────────────────────────────────────────────────────────────
// ROUTES
// ─────────────────────────────────────────────────────────────────────────────

Route<T> slideRoute<T>(Widget page) => PageRouteBuilder<T>(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, a, __, child) => SlideTransition(
        position: Tween(begin: const Offset(1, 0), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeInOutCubic))
            .animate(a),
        child: FadeTransition(opacity: a, child: child),
      ),
      transitionDuration: const Duration(milliseconds: 300),
    );

Route<T> fadeRoute<T>(Widget page) => PageRouteBuilder<T>(
      pageBuilder: (_, __, ___) => page,
      opaque: false,
      transitionsBuilder: (_, a, __, child) =>
          FadeTransition(opacity: a, child: child),
      transitionDuration: const Duration(milliseconds: 240),
    );

// ─────────────────────────────────────────────────────────────────────────────
// APP BAR
// ─────────────────────────────────────────────────────────────────────────────

class ResQAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBack;
  final List<Widget>? actions;
  final VoidCallback? onBack;

  const ResQAppBar({
    super.key,
    required this.title,
    this.showBack = true,
    this.actions,
    this.onBack,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) => AppBar(
        leading: showBack
            ? IconButton(
                icon: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.white08,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: const Icon(Icons.arrow_back, size: 18),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  (onBack ?? () => Navigator.pop(context))();
                },
              )
            : null,
        automaticallyImplyLeading: false,
        title: Text(title),
        actions: actions,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM NAV
// ─────────────────────────────────────────────────────────────────────────────

class ResQBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<BottomNavigationBarItem> items;

  const ResQBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.white08)),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            splashFactory: NoSplash.splashFactory,
            highlightColor: Colors.transparent,
          ),
          child: BottomNavigationBar(
            currentIndex: currentIndex,
            onTap: (i) {
              HapticFeedback.lightImpact();
              onTap(i);
            },
            items: items,
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION LABELS
// ─────────────────────────────────────────────────────────────────────────────

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
        child: Text(text, style: AppTextStyles.label(color: AppColors.white40)),
      );
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: AppTextStyles.label(color: AppColors.white40)),
            if (actionLabel != null)
              InkWell(
                borderRadius: BorderRadius.circular(6),
                splashColor: AppColors.redDim,
                onTap: () {
                  HapticFeedback.lightImpact();
                  onAction?.call();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(actionLabel!,
                      style: AppTextStyles.body(size: 12, color: AppColors.red)),
                ),
              ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// STAT CARD
// ─────────────────────────────────────────────────────────────────────────────

class StatCard extends StatelessWidget {
  final String label, value;

  const StatCard({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black45, offset: Offset(0, 3), blurRadius: 8),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.label()),
              const SizedBox(height: 5),
              Text(value,
                  style: AppTextStyles.heading(24, color: AppColors.red)),
            ],
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// ALERT BANNER
// ─────────────────────────────────────────────────────────────────────────────

class AlertBanner extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? color;

  const AlertBanner({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.red;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        Icon(Icons.warning_amber_rounded, color: c, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message,
              style: AppTextStyles.body(size: 13),
              overflow: TextOverflow.ellipsis,
              maxLines: 2),
        ),
        if (actionLabel != null) ...[
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              splashColor: AppColors.white15,
              onTap: () {
                HapticFeedback.lightImpact();
                onAction?.call();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration:
                    BoxDecoration(color: c, borderRadius: BorderRadius.circular(6)),
                child: Text(actionLabel!,
                    style: AppTextStyles.bodyMedium(size: 12)),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DONATION HISTORY TILE
// ─────────────────────────────────────────────────────────────────────────────

class DonationHistoryTile extends StatelessWidget {
  final String date, name, type, time;

  const DonationHistoryTile({
    super.key,
    required this.date,
    required this.name,
    required this.type,
    required this.time,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
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
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.redDim,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(date,
                style:
                    AppTextStyles.bodyMedium(size: 11, color: AppColors.red)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: AppTextStyles.bodyMedium(size: 13),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.water_drop, size: 11, color: AppColors.red),
                  const SizedBox(width: 4),
                  Text(type,
                      style: AppTextStyles.body(
                          size: 11, color: AppColors.white40)),
                ]),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.check_circle_rounded,
                    size: 11, color: AppColors.green),
                const SizedBox(width: 3),
                Text('Done',
                    style:
                        AppTextStyles.body(size: 10, color: AppColors.green)),
              ]),
              const SizedBox(height: 2),
              Text(time,
                  style:
                      AppTextStyles.body(size: 10, color: AppColors.white40)),
            ],
          ),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// PROFILE FIELD
// ─────────────────────────────────────────────────────────────────────────────

class ProfileField extends StatelessWidget {
  final String label, hint;
  final TextEditingController? controller;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final TextInputType keyboardType;
  final bool obscure, readOnly;
  final String? errorText;
  final VoidCallback? onLocationFetch;
  final ValueChanged<String>? onChanged;

  const ProfileField({
    super.key,
    required this.label,
    required this.hint,
    this.controller,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType = TextInputType.text,
    this.obscure = false,
    this.readOnly = false,
    this.errorText,
    this.onLocationFetch,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppTextStyles.label()),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscure,
          readOnly: readOnly,
          onChanged: onChanged,
          style: AppTextStyles.body(
            size: 14,
            color: readOnly ? AppColors.white40 : AppColors.white70,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.body(size: 14, color: AppColors.white40),
            errorText: errorText,
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: AppColors.white40, size: 18)
                : null,
            suffixIcon: suffixIcon != null
                ? InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: suffixIcon == Icons.my_location
                        ? onLocationFetch
                        : null,
                    child: Icon(
                      suffixIcon,
                      color: suffixIcon == Icons.my_location
                          ? AppColors.red
                          : AppColors.white40,
                      size: 20,
                    ),
                  )
                : null,
          ),
        ),
      ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// LOCATION FIELD
// ─────────────────────────────────────────────────────────────────────────────

class LocationField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final String hint;

  const LocationField({
    super.key,
    required this.label,
    required this.controller,
    this.hint = 'Enter or detect location...',
  });

  @override
  State<LocationField> createState() => _LocationFieldState();
}

class _LocationFieldState extends State<LocationField> {
  bool _detecting = false;

  Future<void> _detect() async {
    HapticFeedback.lightImpact();
    setState(() => _detecting = true);
    final loc = await fetchLocation();
    if (mounted) {
      widget.controller.text = loc;
      setState(() => _detecting = false);
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.label, style: AppTextStyles.label()),
        const SizedBox(height: 7),
        TextField(
          controller: widget.controller,
          style: AppTextStyles.body(size: 14, color: AppColors.white70),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle:
                AppTextStyles.body(size: 14, color: AppColors.white40),
            prefixIcon: const Icon(Icons.location_on_outlined,
                color: AppColors.white40, size: 18),
            suffixIcon: _detecting
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: AppColors.red, strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.my_location,
                        color: AppColors.red, size: 20),
                    tooltip: 'Detect my location',
                    onPressed: _detect,
                  ),
          ),
        ),
      ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// LOADING OVERLAY
// ─────────────────────────────────────────────────────────────────────────────

class LoadingOverlay extends StatelessWidget {
  final String? message;

  const LoadingOverlay({super.key, this.message});

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.bg.withValues(alpha: 0.85),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(
                color: AppColors.red, strokeWidth: 2.5),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(message!,
                  style: AppTextStyles.body(
                      size: 14, color: AppColors.white70)),
            ],
          ]),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// SNACK BARS
// ─────────────────────────────────────────────────────────────────────────────

void showSuccessSnack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..removeCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg, style: AppTextStyles.body()),
      backgroundColor: AppColors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ));
}

void showErrorSnack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..removeCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg, style: AppTextStyles.body()),
      backgroundColor: AppColors.redDark,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(milliseconds: 1800),
    ));
}

// ─────────────────────────────────────────────────────────────────────────────
// CONFIRMATION DIALOG
// ─────────────────────────────────────────────────────────────────────────────

/// Shows a modal confirmation with a title, body, and Confirm/Cancel CTA.
/// Returns `true` if the user confirmed, `false` / null otherwise.
Future<bool?> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool danger = false,
}) {
  HapticFeedback.mediumImpact();
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(title, style: AppTextStyles.bodyMedium(size: 17)),
      content: Text(message,
          style: AppTextStyles.body(size: 14, color: AppColors.white60)),
      actions: [
        TextButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(ctx, false);
          },
          child: Text(cancelLabel,
              style:
                  AppTextStyles.body(size: 14, color: AppColors.white40)),
        ),
        TextButton(
          onPressed: () {
            HapticFeedback.heavyImpact();
            Navigator.pop(ctx, true);
          },
          child: Text(
            confirmLabel,
            style: AppTextStyles.bodyMedium(
              size: 14,
              color: danger ? AppColors.red : AppColors.green,
            ),
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// FILE PICKER DIALOG
// ─────────────────────────────────────────────────────────────────────────────

Future<void> showFilePicker(BuildContext context,
    {required String title}) async {
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title, style: AppTextStyles.bodyMedium(size: 16)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        _fileOption(ctx, Icons.folder_open_rounded, 'Browse Files'),
        const SizedBox(height: 10),
        _fileOption(ctx, Icons.camera_alt_outlined, 'Open Camera'),
        const SizedBox(height: 10),
        _fileOption(ctx, Icons.image_outlined, 'Photo Library'),
      ]),
    ),
  );
}

Widget _fileOption(BuildContext ctx, IconData icon, String label) => InkWell(
      borderRadius: BorderRadius.circular(10),
      splashColor: AppColors.redDim,
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.pop(ctx);
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.white08),
        ),
        child: Row(children: [
          Icon(icon, color: AppColors.red, size: 20),
          const SizedBox(width: 12),
          Text(label, style: AppTextStyles.body(size: 14)),
        ]),
      ),
    );

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? retryLabel;
  final VoidCallback? onRetry;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.retryLabel,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.white08,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.white40, size: 38),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: AppTextStyles.bodyMedium(size: 18),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle,
                style: AppTextStyles.body(
                    size: 14, color: AppColors.white40),
                textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size(140, 44)),
                child: Text(
                  retryLabel ?? 'Retry',
                  style: AppTextStyles.body(size: 14),
                ),
              ),
            ],
          ]),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// STAGGERED LIST HELPER
// Wraps a list of widgets with per-item FadeTransition + SlideTransition.
// [controller] must be forwarded by the parent State's AnimationController.
// ─────────────────────────────────────────────────────────────────────────────

List<Widget> staggeredItems(
  List<Widget> children, {
  required AnimationController controller,
  Duration itemDelay = const Duration(milliseconds: 60),
  Offset slideBegin = const Offset(0, 0.15),
}) {
  return List.generate(children.length, (i) {
    final start = (i * itemDelay.inMilliseconds) /
        (controller.duration?.inMilliseconds ?? 1000);
    final end = (start + 0.4).clamp(0.0, 1.0);
    final interval = CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: Curves.easeOut),
    );
    return FadeTransition(
      opacity: interval,
      child: SlideTransition(
        position: Tween<Offset>(begin: slideBegin, end: Offset.zero)
            .animate(interval),
        child: children[i],
      ),
    );
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// UTILITIES
// ─────────────────────────────────────────────────────────────────────────────

/// Uses real GPS via LocationService; falls back to a placeholder on error.
Future<String> fetchLocation() async {
  try {
    final result = await LocationService.getCurrentLocationWithAddress();
    return result.address;
  } catch (e) {
    // Return a safe placeholder rather than crashing the UI
    return 'Location unavailable';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAP GRID PAINTER
// Wrapped in RepaintBoundary by callers to avoid overdraw.
// ─────────────────────────────────────────────────────────────────────────────

class MapGridPainter extends CustomPainter {
  final double opacity;
  const MapGridPainter({this.opacity = 0.07});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF111111),
    );
    final road = Paint()
      ..color = const Color(0xFF1E1E1E)
      ..strokeWidth = 22
      ..strokeCap = StrokeCap.round;
    final grid = Paint()
      ..color = AppColors.red.withValues(alpha: opacity * 0.8)
      ..strokeWidth = 0.5;
    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    canvas.drawLine(
        Offset(size.width * 0.3, 0), Offset(size.width * 0.45, size.height), road);
    canvas.drawLine(
        Offset(0, size.height * 0.45), Offset(size.width, size.height * 0.52), road);
    canvas.drawLine(
        Offset(size.width * 0.62, 0), Offset(size.width * 0.75, size.height), road);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
