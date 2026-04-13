// ─────────────────────────────────────────────────────────────────────────────
// modules/auth/ — splash_screen, login_screen, role_selection_screen,
//                 signup_screen (multi-step: details → documents → OTP)
// All in one file for convenience; split per file in large teams.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../models/app_models.dart';
import '../../services/app_service.dart';
import '../customer/customer_shell.dart';
import '../donor/donor_shell.dart';
import '../driver/driver_shell.dart';

// ══════════════════════════════════════════════════════════════════════════════
// SPLASH SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade, _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.82, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _ctrl.forward();
    Timer(const Duration(seconds: 3), () {
      if (mounted) Navigator.pushReplacement(context, fadeRoute(const LoginScreen()));
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    body: Center(
      child: FadeTransition(opacity: _fade, child: ScaleTransition(scale: _scale,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(alignment: Alignment.center, children: [
            Container(width: 130, height: 130, decoration: BoxDecoration(
              shape: BoxShape.circle, border: Border.all(color: AppColors.redMid, width: 1.5))),
            Container(width: 100, height: 100, decoration: BoxDecoration(
              shape: BoxShape.circle, color: AppColors.redDim),
              child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.water_drop, color: AppColors.red, size: 36),
                Icon(Icons.emergency, color: AppColors.white, size: 18),
              ])),
          ]),
          const SizedBox(height: 28),
          Text.rich(TextSpan(children: [
            TextSpan(text: 'ResQ', style: AppTextStyles.heading(48, color: AppColors.white)),
            TextSpan(text: 'Link', style: AppTextStyles.heading(48, color: AppColors.red)),
          ])),
          const SizedBox(height: 8),
          Text('EMERGENCY HELP, INSTANTLY',
              style: AppTextStyles.label(color: AppColors.white40).copyWith(letterSpacing: 2)),
        ]),
      )),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// LOGIN SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscure = true, _loading = false;

  @override
  void dispose() { _emailCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  Future<void> _login() async {
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.trim().isEmpty) {
      showErrorSnack(context, 'Please enter email and password'); return;
    }
    setState(() => _loading = true);
    try {
      // Role is selected on next screen; here we just validate credentials.
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      Navigator.push(context, slideRoute(const RoleSelectionScreen()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Stack(children: [
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 60),
            Text('Welcome back', style: AppTextStyles.heading(32)),
            const SizedBox(height: 10),
            Text('Log in to access emergency services and blood donation requests.',
                style: AppTextStyles.body(size: 15, color: AppColors.white40)),
            const SizedBox(height: 40),
            Text('EMAIL ADDRESS', style: AppTextStyles.label()),
            const SizedBox(height: 8),
            TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress,
                style: AppTextStyles.body(), decoration: const InputDecoration(hintText: 'name@example.com')),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('PASSWORD', style: AppTextStyles.label()),
              Text('Forgot password?', style: AppTextStyles.body(size: 13, color: AppColors.red)),
            ]),
            const SizedBox(height: 8),
            TextField(controller: _passCtrl, obscureText: _obscure, style: AppTextStyles.body(),
                decoration: InputDecoration(hintText: 'Enter your password',
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: AppColors.white40, size: 20),
                    onPressed: () => setState(() => _obscure = !_obscure)))),
            const SizedBox(height: 28),
            ElevatedButton(onPressed: _loading ? null : _login,
                child: _loading ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Login →')),
            const SizedBox(height: 28),
            Center(child: Text('OR CONTINUE WITH', style: AppTextStyles.label(color: AppColors.white40))),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: _socialBtn(Icons.apple)),
              const SizedBox(width: 14),
              Expanded(child: _socialBtn(Icons.g_mobiledata)),
            ]),
            const SizedBox(height: 32),
            Center(child: GestureDetector(
              onTap: () => Navigator.push(context, slideRoute(const RoleSelectionScreen())),
              child: Text.rich(TextSpan(children: [
                TextSpan(text: "Don't have an account? ",
                    style: AppTextStyles.body(size: 14, color: AppColors.white40)),
                TextSpan(text: 'Sign up', style: AppTextStyles.bodyMedium(size: 14, color: AppColors.red)),
              ])),
            )),
            const SizedBox(height: 24),
          ]),
        ),
      ]),
    ),
  );

  Widget _socialBtn(IconData icon) => Container(height: 52,
    decoration: BoxDecoration(border: Border.all(color: AppColors.white15), borderRadius: BorderRadius.circular(12)),
    child: Center(child: Icon(icon, color: AppColors.white, size: 26)));
}

// ══════════════════════════════════════════════════════════════════════════════
// ROLE SELECTION SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});
  @override State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  UserRole _selected = UserRole.customer;

  static const _roles = [
    (role: UserRole.customer, title: 'Customer',         desc: 'I need emergency assistance', icon: Icons.emergency),
    (role: UserRole.donor,    title: 'Blood Donor',      desc: 'I want to donate blood',      icon: Icons.bloodtype),
    (role: UserRole.driver,   title: 'Ambulance Driver', desc: 'I am a registered driver',    icon: Icons.local_shipping),
  ];

  void _proceed() => Navigator.push(context,
      slideRoute(SignUpScreen(role: _selected)));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        icon: Container(width: 36, height: 36,
            decoration: BoxDecoration(color: AppColors.white08, borderRadius: BorderRadius.circular(50)),
            child: const Icon(Icons.arrow_back, size: 18)),
        onPressed: () => Navigator.pop(context)),
      title: Text('RESQLINK',
          style: AppTextStyles.heading(13, color: AppColors.red).copyWith(letterSpacing: 3)),
    ),
    body: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(children: [
        const SizedBox(height: 16),
        Align(alignment: Alignment.centerLeft,
            child: Text('Choose Your Role', style: AppTextStyles.heading(28))),
        const SizedBox(height: 10),
        Text('Select how you would like to use ResQLink to get started.',
            style: AppTextStyles.body(size: 14, color: AppColors.white40)),
        const SizedBox(height: 28),
        ..._roles.map((r) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _RoleCard(title: r.title, desc: r.desc, icon: r.icon,
              isSelected: _selected == r.role,
              onTap: () => setState(() => _selected = r.role)),
        )),
        const Spacer(),
        ElevatedButton(onPressed: _proceed, child: const Text('Continue →')),
        const SizedBox(height: 12),
        Text('STEP 1 OF 3 • REGISTRATION', style: AppTextStyles.label(color: AppColors.white40)),
        const SizedBox(height: 24),
      ]),
    ),
  );
}

class _RoleCard extends StatelessWidget {
  final String title, desc;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  const _RoleCard({required this.title, required this.desc, required this.icon,
      required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isSelected ? AppColors.red : AppColors.white08, width: 2)),
      child: Row(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.red : AppColors.surface3,
            borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: isSelected ? AppColors.white : AppColors.white40, size: 22)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: AppTextStyles.bodyMedium(size: 15,
              color: isSelected ? AppColors.white : AppColors.white70)),
          const SizedBox(height: 2),
          Text(desc, style: AppTextStyles.body(size: 12, color: AppColors.white40),
              overflow: TextOverflow.ellipsis),
        ])),
        if (isSelected) const Icon(Icons.check_circle, color: AppColors.red, size: 22),
      ]),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// SIGN-UP — MULTI-STEP: Step 1 Details → Step 2 Documents → Step 3 OTP
// ══════════════════════════════════════════════════════════════════════════════

class SignUpScreen extends StatefulWidget {
  final UserRole role;
  const SignUpScreen({super.key, required this.role});
  @override State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  int _step = 0; // 0=details 1=documents 2=otp

  // Step 1 controllers
  final _nameCtrl    = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _licenseCtrl = TextEditingController();
  final _bloodCtrl   = TextEditingController();
  bool _obscure = true, _loading = false;

  // Step 3
  final List<TextEditingController> _otpCtrls = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocus = List.generate(6, (_) => FocusNode());

  @override
  void dispose() {
    for (final c in [_nameCtrl, _phoneCtrl, _emailCtrl, _passCtrl, _licenseCtrl, _bloodCtrl]) c.dispose();
    for (final c in _otpCtrls) c.dispose();
    for (final f in _otpFocus) f.dispose();
    super.dispose();
  }

  String get _roleTitle {
    switch (widget.role) {
      case UserRole.customer: return 'Customer';
      case UserRole.donor:    return 'Donor';
      case UserRole.driver:   return 'Driver';
    }
  }

  void _nextStep() {
    if (_step == 0) {
      if (_nameCtrl.text.trim().isEmpty || _emailCtrl.text.trim().isEmpty) {
        showErrorSnack(context, 'Please fill all required fields'); return;
      }
      if (widget.role == UserRole.driver && _licenseCtrl.text.trim().isEmpty) {
        showErrorSnack(context, 'License number is required'); return;
      }
      setState(() => _step = 1);
    } else if (_step == 1) {
      setState(() => _step = 2);
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpCtrls.map((c) => c.text).join();
    if (otp.length < 6) { showErrorSnack(context, 'Enter the 6-digit code'); return; }
    setState(() => _loading = true);
    try {
      final ok = await AuthService.verifyOtp(_phoneCtrl.text, otp);
      if (!mounted) return;
      if (!ok) { showErrorSnack(context, 'Invalid code. Try 123456'); return; }
      // Register and navigate to the correct dashboard
      await AuthService.register({
        'name': _nameCtrl.text, 'phone': _phoneCtrl.text,
        'email': _emailCtrl.text, 'password': _passCtrl.text,
        'license': _licenseCtrl.text, 'bloodType': _bloodCtrl.text,
      }, widget.role);
      if (!mounted) return;
      Widget dashboard;
      switch (widget.role) {
        case UserRole.customer: dashboard = const CustomerShell(); break;
        case UserRole.donor:    dashboard = const DonorShell();    break;
        case UserRole.driver:   dashboard = const DriverShell();   break;
      }
      Navigator.pushAndRemoveUntil(context, fadeRoute(dashboard), (_) => false);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Container(width: 36, height: 36,
              decoration: BoxDecoration(color: AppColors.white08, borderRadius: BorderRadius.circular(50)),
              child: const Icon(Icons.arrow_back, size: 18)),
          onPressed: () => _step > 0 ? setState(() => _step--) : Navigator.pop(context)),
        title: Text('RESQLINK',
            style: AppTextStyles.heading(13, color: AppColors.red).copyWith(letterSpacing: 3)),
      ),
      body: SafeArea(
        child: Stack(children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            transitionBuilder: (child, a) => FadeTransition(opacity: a,
                child: SlideTransition(position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(a), child: child)),
            child: KeyedSubtree(
              key: ValueKey(_step),
              child: _step == 0 ? _detailsStep() : _step == 1 ? _documentsStep() : _otpStep(),
            ),
          ),
          if (_loading) const LoadingOverlay(message: 'Verifying...'),
        ]),
      ),
    );
  }

  // ── Step 1: Details ─────────────────────────────────────────────────────────

  Widget _detailsStep() => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 16),
      Text('Register as $_roleTitle', style: AppTextStyles.heading(26)),
      const SizedBox(height: 6),
      Text('Complete your profile to start using ResQLink.',
          style: AppTextStyles.body(size: 14, color: AppColors.white40)),
      const SizedBox(height: 28),
      ProfileField(label: 'FULL NAME', hint: 'John Doe', controller: _nameCtrl,
          prefixIcon: Icons.person_outline),
      const SizedBox(height: 14),
      ProfileField(label: 'PHONE NUMBER', hint: '+1 000 000 000', controller: _phoneCtrl,
          prefixIcon: Icons.phone_outlined, keyboardType: TextInputType.phone),
      const SizedBox(height: 14),
      ProfileField(label: 'EMAIL ADDRESS', hint: 'example@mail.com', controller: _emailCtrl,
          prefixIcon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
      const SizedBox(height: 14),
      if (widget.role == UserRole.driver) ...[
        ProfileField(label: 'LICENSE NUMBER', hint: 'DL-12345-XYZ', controller: _licenseCtrl,
            prefixIcon: Icons.badge_outlined),
        const SizedBox(height: 14),
      ],
      if (widget.role == UserRole.donor) ...[
        ProfileField(label: 'BLOOD TYPE', hint: 'e.g., O+, AB-', controller: _bloodCtrl,
            prefixIcon: Icons.water_drop_outlined),
        const SizedBox(height: 14),
      ],
      ProfileField(label: 'PASSWORD', hint: '••••••••', controller: _passCtrl,
          prefixIcon: Icons.lock_outline, obscure: _obscure),
      const SizedBox(height: 30),
      ElevatedButton(onPressed: _nextStep, child: const Text('Continue →')),
      const SizedBox(height: 12),
      Center(child: Text('STEP 1 OF 3 • DETAILS',
          style: AppTextStyles.label(color: AppColors.white40))),
      const SizedBox(height: 32),
    ]),
  );

  // ── Step 2: Documents ────────────────────────────────────────────────────────

  Widget _documentsStep() => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 16),
      Text('Upload Documents', style: AppTextStyles.heading(26)),
      const SizedBox(height: 6),
      Text('Required for verification. Files are stored securely.',
          style: AppTextStyles.body(size: 14, color: AppColors.white40)),
      const SizedBox(height: 28),
      _docUploadTile('Government ID', Icons.badge_outlined, 'ID Card / Passport'),
      const SizedBox(height: 14),
      if (widget.role == UserRole.driver) ...[
        _docUploadTile('Driver License', Icons.drive_eta, 'Front & Back'),
        const SizedBox(height: 14),
        _docUploadTile('Vehicle Registration', Icons.local_shipping_rounded, 'Registration Certificate'),
        const SizedBox(height: 14),
      ],
      if (widget.role == UserRole.donor) ...[
        _docUploadTile('Medical Certificate', Icons.medical_services_outlined, 'Blood test results (recent)'),
        const SizedBox(height: 14),
      ],
      _docUploadTile('Profile Photo', Icons.camera_alt_outlined, 'Clear face photo'),
      const SizedBox(height: 30),
      ElevatedButton(onPressed: _nextStep, child: const Text('Send Verification Code →')),
      const SizedBox(height: 12),
      Center(child: Text('STEP 2 OF 3 • DOCUMENTS',
          style: AppTextStyles.label(color: AppColors.white40))),
      const SizedBox(height: 32),
    ]),
  );

  Widget _docUploadTile(String label, IconData icon, String sub) {
    return GestureDetector(
      onTap: () => showSuccessSnack(context, '$label selected'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.white08)),
        child: Row(children: [
          Container(width: 44, height: 44,
              decoration: BoxDecoration(color: AppColors.redDim, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: AppColors.red, size: 22)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: AppTextStyles.bodyMedium(size: 14)),
            Text(sub, style: AppTextStyles.body(size: 12, color: AppColors.white40),
                overflow: TextOverflow.ellipsis),
          ])),
          const Icon(Icons.upload_rounded, color: AppColors.white40, size: 20),
        ]),
      ),
    );
  }

  // ── Step 3: OTP ──────────────────────────────────────────────────────────────

  Widget _otpStep() => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 16),
      Text('Verify Phone', style: AppTextStyles.heading(26)),
      const SizedBox(height: 6),
      Text('Enter the 6-digit code sent to ${_phoneCtrl.text.isEmpty ? "your phone" : _phoneCtrl.text}.',
          style: AppTextStyles.body(size: 14, color: AppColors.white40)),
      const SizedBox(height: 40),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(6, (i) => SizedBox(
          width: 46, height: 56,
          child: TextField(
            controller: _otpCtrls[i],
            focusNode: _otpFocus[i],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            style: AppTextStyles.heading(22),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              counterText: '',
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.white15)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.red, width: 2)),
            ),
            onChanged: (v) {
              if (v.isNotEmpty && i < 5) FocusScope.of(context).requestFocus(_otpFocus[i + 1]);
              if (v.isEmpty && i > 0) FocusScope.of(context).requestFocus(_otpFocus[i - 1]);
            },
          ),
        )),
      ),
      const SizedBox(height: 32),
      ElevatedButton(onPressed: _loading ? null : _verifyOtp, child: const Text('Verify & Create Account')),
      const SizedBox(height: 16),
      Center(child: GestureDetector(
        onTap: () => showSuccessSnack(context, 'Code resent'),
        child: Text('Resend Code', style: AppTextStyles.body(size: 14, color: AppColors.red)),
      )),
      const SizedBox(height: 12),
      Center(child: Text('STEP 3 OF 3 • VERIFICATION',
          style: AppTextStyles.label(color: AppColors.white40))),
      const SizedBox(height: 32),
    ]),
  );
}
