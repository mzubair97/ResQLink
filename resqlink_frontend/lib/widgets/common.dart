// ─────────────────────────────────────────────────────────────────────────────
// widgets/common.dart
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ── Route helpers ─────────────────────────────────────────────────────────────

Route<T> slideRoute<T>(Widget page) => PageRouteBuilder<T>(
  pageBuilder: (_, __, ___) => page,
  transitionsBuilder: (_, a, __, child) => SlideTransition(
    position: Tween(begin: const Offset(1, 0), end: Offset.zero)
        .chain(CurveTween(curve: Curves.easeInOutCubic)).animate(a),
    child: FadeTransition(opacity: a, child: child),
  ),
  transitionDuration: const Duration(milliseconds: 380),
);

Route<T> fadeRoute<T>(Widget page) => PageRouteBuilder<T>(
  pageBuilder: (_, __, ___) => page,
  transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
  transitionDuration: const Duration(milliseconds: 320),
);

// ── ResQAppBar ────────────────────────────────────────────────────────────────

class ResQAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBack;
  final List<Widget>? actions;
  final VoidCallback? onBack;

  const ResQAppBar({super.key, required this.title, this.showBack = true, this.actions, this.onBack});

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: showBack
          ? IconButton(
              icon: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: AppColors.white08, borderRadius: BorderRadius.circular(50)),
                child: const Icon(Icons.arrow_back, size: 18),
              ),
              onPressed: onBack ?? () => Navigator.pop(context),
            )
          : null,
      automaticallyImplyLeading: false,
      title: Text(title),
      actions: actions,
    );
  }
}

// ── ResQBottomNav ─────────────────────────────────────────────────────────────

class ResQBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<BottomNavigationBarItem> items;

  const ResQBottomNav({super.key, required this.currentIndex, required this.onTap, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.white08))),
      child: BottomNavigationBar(currentIndex: currentIndex, onTap: onTap, items: items),
    );
  }
}

// ── SectionLabel ──────────────────────────────────────────────────────────────

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
    child: Text(text, style: AppTextStyles.label(color: AppColors.white40)),
  );
}

// ── StatCard ──────────────────────────────────────────────────────────────────

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  const StatCard({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppTextStyles.label()),
        const SizedBox(height: 5),
        Text(value, style: AppTextStyles.heading(24, color: AppColors.red)),
      ]),
    ),
  );
}

// ── AlertBanner ───────────────────────────────────────────────────────────────

class AlertBanner extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? color;

  const AlertBanner({super.key, required this.message, this.actionLabel, this.onAction, this.color});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 20),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: (color ?? AppColors.red).withOpacity(0.12),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: (color ?? AppColors.red).withOpacity(0.35)),
    ),
    child: Row(children: [
      Icon(Icons.warning_amber_rounded, color: color ?? AppColors.red, size: 20),
      const SizedBox(width: 10),
      Expanded(child: Text(message, style: AppTextStyles.body(size: 13), overflow: TextOverflow.ellipsis, maxLines: 2)),
      if (actionLabel != null) ...[
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onAction,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: color ?? AppColors.red, borderRadius: BorderRadius.circular(6)),
            child: Text(actionLabel!, style: AppTextStyles.bodyMedium(size: 12)),
          ),
        ),
      ],
    ]),
  );
}

// ── DonationHistoryTile ───────────────────────────────────────────────────────

class DonationHistoryTile extends StatelessWidget {
  final String date, name, type, time;
  const DonationHistoryTile({super.key, required this.date, required this.name, required this.type, required this.time});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(color: AppColors.redDim, borderRadius: BorderRadius.circular(8)),
        child: Text(date, style: AppTextStyles.bodyMedium(size: 11, color: AppColors.red)),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, style: AppTextStyles.bodyMedium(size: 13), overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Row(children: [
          const Icon(Icons.water_drop, size: 11, color: AppColors.red),
          const SizedBox(width: 4),
          Text(type, style: AppTextStyles.body(size: 11, color: AppColors.white40)),
        ]),
      ])),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.check_circle_rounded, size: 11, color: AppColors.green),
          const SizedBox(width: 3),
          Text('Done', style: AppTextStyles.body(size: 10, color: AppColors.green)),
        ]),
        const SizedBox(height: 2),
        Text(time, style: AppTextStyles.body(size: 10, color: AppColors.white40)),
      ]),
    ]),
  );
}

// ── ProfileFieldTile ──────────────────────────────────────────────────────────

class ProfileField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController? controller;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final TextInputType keyboardType;
  final bool obscure;

  const ProfileField({
    super.key, required this.label, required this.hint,
    this.controller, this.prefixIcon, this.suffixIcon,
    this.keyboardType = TextInputType.text, this.obscure = false,
  });

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: AppTextStyles.label()),
    const SizedBox(height: 7),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.white08),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        style: AppTextStyles.body(size: 14, color: AppColors.white70),
        decoration: InputDecoration(
          border: InputBorder.none, hintText: hint, filled: false,
          contentPadding: EdgeInsets.zero,
          hintStyle: AppTextStyles.body(size: 14, color: AppColors.white40),
          prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: AppColors.white40, size: 18) : null,
          suffixIcon: suffixIcon != null ? Icon(suffixIcon, color: suffixIcon == Icons.my_location ? AppColors.red : AppColors.white40, size: 18) : null,
        ),
      ),
    ),
  ]);
}

// ── SectionHeader (label + See All) ──────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const SectionHeader({super.key, required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(title, style: AppTextStyles.label(color: AppColors.white40)),
      if (actionLabel != null)
        GestureDetector(
          onTap: onAction,
          child: Text(actionLabel!, style: AppTextStyles.body(size: 12, color: AppColors.red)),
        ),
    ]),
  );
}

// ── LoadingOverlay ────────────────────────────────────────────────────────────

class LoadingOverlay extends StatelessWidget {
  final String? message;
  const LoadingOverlay({super.key, this.message});

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.bg.withOpacity(0.85),
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const CircularProgressIndicator(color: AppColors.red, strokeWidth: 2.5),
      if (message != null) ...[
        const SizedBox(height: 16),
        Text(message!, style: AppTextStyles.body(size: 14, color: AppColors.white70)),
      ],
    ])),
  );
}

// ── SnackBar helpers ──────────────────────────────────────────────────────────

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

// ── MapGridPainter (shared) ───────────────────────────────────────────────────

class MapGridPainter extends CustomPainter {
  final double opacity;
  const MapGridPainter({this.opacity = 0.07});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFF111111));
    final road = Paint()..color = const Color(0xFF1E1E1E)..strokeWidth = 22..strokeCap = StrokeCap.round;
    final grid = Paint()..color = AppColors.red.withOpacity(opacity * 0.8)..strokeWidth = 0.5;
    const step = 28.0;
    for (double x = 0; x < size.width; x += step) canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    for (double y = 0; y < size.height; y += step) canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    canvas.drawLine(Offset(size.width * 0.3, 0), Offset(size.width * 0.45, size.height), road);
    canvas.drawLine(Offset(0, size.height * 0.45), Offset(size.width, size.height * 0.52), road);
    canvas.drawLine(Offset(size.width * 0.62, 0), Offset(size.width * 0.75, size.height), road);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
