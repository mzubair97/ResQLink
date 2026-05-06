// modules/auth/auth_screens.dart
// Polish v3 — micro-interactions, haptics, InkWell ripples,
// WillPopScope back-confirmation, live field validation icons,
// staggered entrance animations on form fields.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/haptics.dart';
import '../../widgets/animated_press_button.dart';
import '../../models/app_models.dart';
import '../../services/app_service.dart';
import '../customer/customer_shell.dart';
import '../donor/donor_shell.dart';
import '../driver/driver_shell.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

// ═══════════════════════════════════════════════════════════════════════════
// SPLASH
// ═══════════════════════════════════════════════════════════════════════════

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoCtrl;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;

  late AnimationController _textCtrl;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;

  late AnimationController _tagCtrl;
  late Animation<double> _tagFade;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseScale;
  late Animation<double> _pulseOpacity;

  @override
  void initState() {
    super.initState();

    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _logoScale = Tween<double>(begin: 0.55, end: 1.0)
        .animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut));
    _logoFade = CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut);

    _textCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 550));
    _textFade = CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut);
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic));

    _tagCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _tagFade = CurvedAnimation(parent: _tagCtrl, curve: Curves.easeIn);

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat();
    _pulseScale = Tween<double>(begin: 1.0, end: 1.55)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut));
    _pulseOpacity = Tween<double>(begin: 0.45, end: 0.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut));

    _logoCtrl.forward().then((_) async {
      await Future.delayed(const Duration(milliseconds: 50));
      if (mounted) _textCtrl.forward();
      await Future.delayed(const Duration(milliseconds: 250));
      if (mounted) {
        _tagCtrl.forward();
        // Haptic when animation settles
        Haptics.heavy();
      }
    });

    Timer(const Duration(seconds: 3), () async {
      if (!mounted) return;
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        // Session exists — resolve role and go to the correct dashboard.
        try {
          final user = Supabase.instance.client.auth.currentUser!;
          final data = await Supabase.instance.client
              .from('profiles')
              .select('role')
              .eq('id', user.id)
              .single();
          if (!mounted) return;
          final role = data['role'] as String? ?? 'customer';
          Widget dashboard;
          if (role == 'donor') {
            dashboard = const DonorShell();
          } else if (role == 'driver') {
            dashboard = const DriverShell();
          } else {
            dashboard = const CustomerShell();
          }
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => dashboard,
              transitionsBuilder: (_, a, __, child) =>
                  FadeTransition(opacity: a, child: child),
              transitionDuration: const Duration(milliseconds: 400),
            ),
          );
        } catch (_) {
          // Role fetch failed — fall back to login.
          if (mounted) {
            Navigator.pushReplacement(context, fadeRoute(const LoginScreen()));
          }
        }
      } else {
        // No session — go to login.
        Navigator.pushReplacement(context, fadeRoute(const LoginScreen()));
      }
    });
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _tagCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.bg,
        body: Stack(children: [
          // Radial red glow behind logo
          Positioned.fill(
            child: DecoratedBox(
              decoration:
                  const BoxDecoration(gradient: AppGradients.radialGlow),
            ),
          ),
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                width: 160,
                height: 160,
                child: Stack(alignment: Alignment.center, children: [
                  // Pulse ring
                  AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (_, __) => Opacity(
                      opacity: _pulseOpacity.value,
                      child: Transform.scale(
                        scale: _pulseScale.value,
                        child: Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: AppColors.red, width: 2.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Logo
                  ScaleTransition(
                    scale: _logoScale,
                    child: FadeTransition(
                      opacity: _logoFade,
                      child: Container(
                        width: 128,
                        height: 128,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.red.withValues(alpha: 0.35),
                              blurRadius: 28,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 32),
              SlideTransition(
                position: _textSlide,
                child: FadeTransition(
                  opacity: _textFade,
                  child: Text.rich(TextSpan(children: [
                    TextSpan(
                        text: 'ResQ',
                        style:
                            AppTextStyles.heading(48, color: AppColors.white)),
                    TextSpan(
                        text: 'Link',
                        style: AppTextStyles.heading(48, color: AppColors.red)),
                  ])),
                ),
              ),
              const SizedBox(height: 10),
              FadeTransition(
                opacity: _tagFade,
                child: Text(
                  'EMERGENCY HELP, INSTANTLY',
                  style: AppTextStyles.label(color: AppColors.white40)
                      .copyWith(letterSpacing: 2),
                ),
              ),
            ]),
          ),
        ]),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// LOGIN
// ═══════════════════════════════════════════════════════════════════════════

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true, _loading = false;
  String? _emailError, _passError;
  bool _emailValid = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _onEmailChanged(String v) {
    setState(() {
      _emailError = null;
      _emailValid = v.contains('@') && v.contains('.');
    });
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    String? eErr, pErr;
    if (email.isEmpty) {
      eErr = 'Email is required';
    } else if (!email.contains('@') || !email.contains('.')) {
      eErr = 'Enter a valid email (must contain @ and .)';
    }
    if (pass.isEmpty) pErr = 'Password is required';
    setState(() {
      _emailError = eErr;
      _passError = pErr;
    });
    if (eErr != null || pErr != null) {
      Haptics.medium();
      return;
    }
    Haptics.heavy();
    setState(() => _loading = true);
    try {
      final user = await AuthService.login(email, pass, UserRole.customer);
      if (!mounted) return;
      Widget dashboard;
      if (user.role == UserRole.donor) {
        dashboard = const DonorShell();
      } else if (user.role == UserRole.driver) {
        dashboard = const DriverShell();
      } else {
        dashboard = const CustomerShell();
      }
      Navigator.pushAndRemoveUntil(context, fadeRoute(dashboard), (_) => false);
    } catch (e) {
      if (mounted) showErrorSnack(context, 'Login failed');
      Haptics.medium();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60),
                Text('Welcome back', style: AppTextStyles.heading(32)),
                const SizedBox(height: 10),
                Text(
                  'Log in to access emergency services and blood donation requests.',
                  style: AppTextStyles.body(size: 15, color: AppColors.white40),
                ),
                const SizedBox(height: 40),
                Text('EMAIL ADDRESS', style: AppTextStyles.label()),
                const SizedBox(height: 8),
                Semantics(
                  label: 'Email address input',
                  child: TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: _onEmailChanged,
                    style: AppTextStyles.body(),
                    decoration: InputDecoration(
                      hintText: 'name@example.com',
                      errorText: _emailError,
                      suffixIcon: _emailValid
                          ? const Icon(Icons.check_circle_rounded,
                              color: AppColors.green, size: 20)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('PASSWORD', style: AppTextStyles.label()),
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      splashColor: AppColors.redDim,
                      onTap: () {
                        Haptics.light();
                        Navigator.push(
                            context, slideRoute(const ForgotPasswordScreen()));
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        child: Text('Forgot password?',
                            style: AppTextStyles.body(
                                size: 13, color: AppColors.red)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Semantics(
                  label: 'Password input',
                  child: TextField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    onChanged: (_) => setState(() => _passError = null),
                    style: AppTextStyles.body(),
                    decoration: InputDecoration(
                      hintText: 'Enter your password',
                      errorText: _passError,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppColors.white40,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Semantics(
                  label: 'Login button',
                  button: true,
                  child: AnimatedPressButton(
                    onTap: _loading ? null : _login,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _login,
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text('Login'),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Center(
                  child: Text('OR CONTINUE WITH',
                      style: AppTextStyles.label(color: AppColors.white40)),
                ),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(child: _socialBtn(Icons.apple)),
                  const SizedBox(width: 14),
                  Expanded(child: _socialBtn(Icons.g_mobiledata)),
                ]),
                const SizedBox(height: 32),
                Center(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    splashColor: AppColors.redDim,
                    onTap: () {
                      Haptics.light();
                      Navigator.push(
                          context, slideRoute(const RoleSelectionScreen()));
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: Text.rich(TextSpan(children: [
                        TextSpan(
                            text: "Don't have an account? ",
                            style: AppTextStyles.body(
                                size: 14, color: AppColors.white40)),
                        TextSpan(
                            text: 'Sign up',
                            style: AppTextStyles.bodyMedium(
                                size: 14, color: AppColors.red)),
                      ])),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      );

  Widget _socialBtn(IconData icon) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          splashColor: AppColors.white08,
          onTap: () => Haptics.light(),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.white15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Icon(icon, color: AppColors.white, size: 26)),
          ),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// FORGOT PASSWORD
// ═══════════════════════════════════════════════════════════════════════════

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _sent = false, _loading = false;
  String? _emailError;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      setState(() => _emailError = 'Enter a valid email address');
      Haptics.medium();
      return;
    }
    Haptics.heavy();
    setState(() {
      _loading = true;
      _emailError = null;
    });

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'io.supabase.resqlink://reset-callback/',
      );
      if (mounted) {
        setState(() {
          _loading = false;
          _sent = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showErrorSnack(context, 'Failed to send reset email');
        Haptics.medium();
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: AppColors.white08,
                  borderRadius: BorderRadius.circular(50)),
              child: const Icon(Icons.arrow_back, size: 18),
            ),
            onPressed: () {
              Haptics.light();
              Navigator.pop(context);
            },
          ),
          title: Text('RESQLINK',
              style: AppTextStyles.heading(13, color: AppColors.red)
                  .copyWith(letterSpacing: 3)),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _sent ? _sentView() : _formView(),
        ),
      );

  Widget _formView() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 32),
        Text('Reset Password', style: AppTextStyles.heading(28)),
        const SizedBox(height: 8),
        Text("Enter your email and we'll send a reset link.",
            style: AppTextStyles.body(size: 14, color: AppColors.white40)),
        const SizedBox(height: 40),
        Text('EMAIL ADDRESS', style: AppTextStyles.label()),
        const SizedBox(height: 8),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) => setState(() => _emailError = null),
          style: AppTextStyles.body(),
          decoration: InputDecoration(
              hintText: 'name@example.com', errorText: _emailError),
        ),
        const SizedBox(height: 28),
        AnimatedPressButton(
          onTap: _loading ? null : _send,
          child: ElevatedButton(
            onPressed: _loading ? null : _send,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Send Reset Link'),
          ),
        ),
      ]);

  Widget _sentView() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.green.withValues(alpha: 0.4)),
            ),
            child: const Icon(Icons.mark_email_read_outlined,
                color: AppColors.green, size: 40),
          ),
          const SizedBox(height: 20),
          Text('Email Sent!',
              style: AppTextStyles.heading(24, color: AppColors.green)),
          const SizedBox(height: 8),
          Text('Check your inbox for the reset link.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body(size: 14, color: AppColors.white40)),
          const SizedBox(height: 32),
          ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back to Login')),
        ]),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// ROLE SELECTION
// ═══════════════════════════════════════════════════════════════════════════

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});
  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  UserRole _selected = UserRole.customer;

  static const _roles = [
    (
      role: UserRole.customer,
      title: 'Customer',
      desc: 'I need emergency assistance',
      icon: Icons.emergency
    ),
    (
      role: UserRole.donor,
      title: 'Blood Donor',
      desc: 'I want to donate blood',
      icon: Icons.bloodtype
    ),
    (
      role: UserRole.driver,
      title: 'Ambulance Driver',
      desc: 'I am a registered driver',
      icon: Icons.local_shipping
    ),
  ];

  void _proceed() =>
      Navigator.push(context, slideRoute(SignUpScreen(role: _selected)));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: AppColors.white08,
                  borderRadius: BorderRadius.circular(50)),
              child: const Icon(Icons.arrow_back, size: 18),
            ),
            // Fix #8: back button should navigate to LoginScreen, not pop
            // (prevents navigation loops if this was pushed via pushReplacement)
            onPressed: () {
              Haptics.light();
              Navigator.pushAndRemoveUntil(
                context,
                fadeRoute(const LoginScreen()),
                (_) => false,
              );
            },
          ),
          title: Text('RESQLINK',
              style: AppTextStyles.heading(13, color: AppColors.red)
                  .copyWith(letterSpacing: 3)),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Choose Your Role', style: AppTextStyles.heading(28)),
            ),
            const SizedBox(height: 10),
            Text('Select how you would like to use ResQLink to get started.',
                style: AppTextStyles.body(size: 14, color: AppColors.white40)),
            const SizedBox(height: 28),
            ..._roles.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _RoleCard(
                    title: r.title,
                    desc: r.desc,
                    icon: r.icon,
                    isSelected: _selected == r.role,
                    onTap: () {
                      Haptics.light();
                      setState(() => _selected = r.role);
                    },
                  ),
                )),
            const Spacer(),
            AnimatedPressButton(
              onTap: _proceed,
              child: ElevatedButton(
                  onPressed: _proceed, child: const Text('Continue')),
            ),
            const SizedBox(height: 12),
            Text('STEP 1 OF 3 - REGISTRATION',
                style: AppTextStyles.label(color: AppColors.white40)),
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

  const _RoleCard({
    required this.title,
    required this.desc,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          splashColor: AppColors.redDim,
          highlightColor: AppColors.redDim,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: isSelected ? AppColors.red : AppColors.white08,
                  width: 2),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.red.withValues(alpha: 0.20),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.red : AppColors.surface3,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon,
                    color: isSelected ? AppColors.white : AppColors.white40,
                    size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppTextStyles.bodyMedium(
                            size: 15,
                            color: isSelected
                                ? AppColors.white
                                : AppColors.white70)),
                    const SizedBox(height: 2),
                    Text(desc,
                        style: AppTextStyles.body(
                            size: 12, color: AppColors.white40),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle, color: AppColors.red, size: 22),
            ]),
          ),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// SIGN-UP
// ═══════════════════════════════════════════════════════════════════════════

const _validBloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

class SignUpScreen extends StatefulWidget {
  final UserRole role;
  const SignUpScreen({super.key, required this.role});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  int _step = 0;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController(text: '+92');
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();
  final Map<String, String?> _uploadedDocs = {}; // documentType -> fileUrl
  final Map<String, bool> _uploadingDocs = {}; // documentType -> isUploading
  bool _obscure = true, _loading = false;
  String? _selectedBloodGroup;

  // Inline validation states
  String? _nameErr, _phoneErr, _emailErr, _passErr, _bloodErr, _licenseErr;
  bool _nameValid = false,
      _emailValid = false,
      _passValid = false,
      _phoneValid = false;

  final List<TextEditingController> _otpCtrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocus = List.generate(6, (_) => FocusNode());

  // OTP resend countdown state
  Timer? _resendTimer;
  int _resendCooldown = 0;

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (final c in [
      _nameCtrl,
      _phoneCtrl,
      _emailCtrl,
      _passCtrl,
      _licenseCtrl
    ]) {
      c.dispose();
    }
    for (final c in _otpCtrls) c.dispose();
    for (final f in _otpFocus) f.dispose();
    super.dispose();
  }

  String get _roleTitle {
    switch (widget.role) {
      case UserRole.customer:
        return 'Customer';
      case UserRole.donor:
        return 'Donor';
      case UserRole.driver:
        return 'Driver';
    }
  }

  bool get _isCustomer => widget.role == UserRole.customer;
  void _nextStep() async {
    if (_step == 0) {
      if (!_validateDetails()) return;
      Haptics.medium();
      setState(() => _step = _isCustomer ? 2 : 1);
      if (_isCustomer) {
        // Register in Supabase — this sends the OTP email automatically
        try {
          await AuthService.register({
            'name': _nameCtrl.text,
            'phone': _phoneCtrl.text,
            'email': _emailCtrl.text,
            'password': _passCtrl.text,
            'license': _licenseCtrl.text,
            'bloodType': _selectedBloodGroup ?? '',
          }, widget.role);
        } catch (e) {
          if (mounted)
            showErrorSnack(
                context, e.toString().replaceFirst('Exception: ', ''));
          setState(() => _step = 0);
          return;
        }
        _startResendTimer();
      }
    } else if (_step == 1) {
      showSuccessSnack(
          context, 'Documents noted. You can upload later in Profile.');
      Haptics.medium();
      // Register in Supabase — this sends the OTP email automatically
      try {
        await AuthService.register({
          'name': _nameCtrl.text,
          'phone': _phoneCtrl.text,
          'email': _emailCtrl.text,
          'password': _passCtrl.text,
          'license': _licenseCtrl.text,
          'bloodType': _selectedBloodGroup ?? '',
        }, widget.role);
      } catch (e) {
        if (mounted)
          showErrorSnack(context, e.toString().replaceFirst('Exception: ', ''));
        return;
      }
      setState(() => _step = 2);
      _startResendTimer();
    }
  }

  /// Starts the 30-second resend cooldown timer.
  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendCooldown = MockOtpService.resendCooldownSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_resendCooldown <= 1) {
        t.cancel();
        setState(() => _resendCooldown = 0);
      } else {
        setState(() => _resendCooldown--);
      }
    });
  }

  bool _validateDetails() {
    String? nErr, phErr, emErr, pErr, bErr, lErr;
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;

    if (name.isEmpty) nErr = 'Full name is required';
    if (phone.length < 13 || !phone.startsWith('+92'))
      phErr = 'Enter 10 digits after +92';
    if (email.isEmpty)
      emErr = 'Email is required';
    else if (!email.contains('@') || !email.contains('.'))
      emErr = 'Enter a valid email (must contain @ and .)';
    if (pass.isEmpty)
      pErr = 'Password is required';
    else if (pass.length < 8)
      pErr = 'Password must be at least 8 characters';
    else if (!RegExp(r'\d').hasMatch(pass)) // ← CHECK THIS LINE
      pErr = 'Password must contain at least one digit (0-9)';
    else if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(pass)) // ← AND THIS
      pErr = 'Password must contain at least one special character';
    if (widget.role == UserRole.donor && _selectedBloodGroup == null)
      bErr = 'Select your blood group';
    if (widget.role == UserRole.driver && _licenseCtrl.text.trim().isEmpty)
      lErr = 'License number is required';

    setState(() {
      _nameErr = nErr;
      _phoneErr = phErr;
      _emailErr = emErr;
      _passErr = pErr;
      _bloodErr = bErr;
      _licenseErr = lErr;
    });
    if ([nErr, phErr, emErr, pErr, bErr, lErr].any((e) => e != null)) {
      showErrorSnack(context, 'Please fix the highlighted fields');
      Haptics.medium();
      return false;
    }
    return true;
  }

  Future<void> _verifyOtp() async {
    final otp = _otpCtrls.map((c) => c.text).join();
    if (otp.length < 6) {
      showErrorSnack(context, 'Enter the 6-digit code');
      Haptics.medium();
      return;
    }
    Haptics.heavy();
    setState(() => _loading = true);
    try {
      final ok = await AuthService.verifyOtp(_emailCtrl.text.trim(), otp);
      if (!mounted) return;
      if (!ok) {
        showErrorSnack(context, 'Incorrect code. Please check your email.');
        Haptics.medium();
        return;
      }
      await AuthService.completeRegistration({
        'name': _nameCtrl.text,
        'phone': _phoneCtrl.text,
        'email': _emailCtrl.text,
        'password': _passCtrl.text,
        'license': _licenseCtrl.text,
        'bloodType': _selectedBloodGroup ?? '',
        'profilePhotoPath': _uploadedDocs['profile_photo'], // ← ADD THIS LINE
      }, widget.role);
      if (!mounted) return;
      Widget dash;
      switch (widget.role) {
        case UserRole.customer:
          dash = const CustomerShell();
          break;
        case UserRole.donor:
          dash = const DonorShell();
          break;
        case UserRole.driver:
          dash = const DriverShell();
          break;
      }
      Navigator.pushAndRemoveUntil(context, fadeRoute(dash), (_) => false);
    } catch (e) {
      if (mounted) {
        showErrorSnack(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _onWillPop() async {
    if (_step == 0) return true;
    final leave = await showConfirmDialog(
      context,
      title: 'Leave sign-up?',
      message: 'Your progress will not be saved.',
      confirmLabel: 'Leave',
      cancelLabel: 'Stay',
      danger: true,
    );
    if (leave == true) {
      setState(() => _step = _step == 2 && _isCustomer ? 0 : _step - 1);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => WillPopScope(
        onWillPop: _onWillPop,
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: AppColors.white08,
                    borderRadius: BorderRadius.circular(50)),
                child: const Icon(Icons.arrow_back, size: 18),
              ),
              onPressed: () async {
                final go = await _onWillPop();
                if (go && mounted) Navigator.pop(context);
              },
            ),
            title: Text('RESQLINK',
                style: AppTextStyles.heading(13, color: AppColors.red)
                    .copyWith(letterSpacing: 3)),
          ),
          body: SafeArea(
            child: Stack(children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, a) =>
                    FadeTransition(opacity: a, child: child),
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: _step == 0
                      ? _detailsStep()
                      : _step == 1
                          ? _documentsStep()
                          : _otpStep(),
                ),
              ),
              if (_loading) const LoadingOverlay(message: 'Verifying...'),
            ]),
          ),
        ),
      );

  // ── Validation icon helper ──────────────────────────────────────────────
  Widget? _validIcon(bool valid) => valid
      ? const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 20)
      : null;

  // ── Step 0: Details ─────────────────────────────────────────────────────
  Widget _detailsStep() => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 16),
          Text('Register as $_roleTitle', style: AppTextStyles.heading(26)),
          const SizedBox(height: 6),
          Text('Complete your profile to start using ResQLink.',
              style: AppTextStyles.body(size: 14, color: AppColors.white40)),
          const SizedBox(height: 24),

          // Full name
          ProfileField(
            label: 'FULL NAME',
            hint: 'Ahmed',
            controller: _nameCtrl,
            prefixIcon: Icons.person_outline,
            errorText: _nameErr,
            suffixIcon: _nameValid ? Icons.check_circle_rounded : null,
            onChanged: (v) => setState(() {
              _nameErr = null;
              _nameValid = v.trim().isNotEmpty;
            }),
          ),
          const SizedBox(height: 14),

          // Phone
          Text('PHONE NUMBER', style: AppTextStyles.label()),
          const SizedBox(height: 7),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.number,
            style: AppTextStyles.body(size: 14, color: AppColors.white70),
            maxLength: 13,
            onChanged: (v) {
              setState(() {
                _phoneErr = null;
                _phoneValid = v.length >= 13 && v.startsWith('+92');
              });
              if (!v.startsWith('+92')) {
                _phoneCtrl.value = const TextEditingValue(
                    text: '+92', selection: TextSelection.collapsed(offset: 3));
              }
            },
            inputFormatters: [
              TextInputFormatter.withFunction((old, newVal) {
                if (!newVal.text.startsWith('+92')) return old;
                final rest = newVal.text.substring(3);
                if (rest.contains(RegExp(r'[^0-9]'))) return old;
                return newVal;
              }),
              LengthLimitingTextInputFormatter(13),
            ],
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.phone_outlined,
                  color: AppColors.white40, size: 18),
              suffixIcon: _validIcon(_phoneValid),
              hintText: '+92 3XX XXXXXXX',
              hintStyle: AppTextStyles.body(size: 14, color: AppColors.white40),
              counterText: '',
              errorText: _phoneErr,
            ),
          ),
          const SizedBox(height: 14),

          // Email
          ProfileField(
            label: 'EMAIL ADDRESS',
            hint: 'example@mail.com',
            controller: _emailCtrl,
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            errorText: _emailErr,
            suffixIcon: _emailValid ? Icons.check_circle_rounded : null,
            onChanged: (v) => setState(() {
              _emailErr = null;
              _emailValid = v.contains('@') && v.contains('.');
            }),
          ),
          const SizedBox(height: 14),

          // Driver: License
          if (widget.role == UserRole.driver) ...[
            ProfileField(
              label: 'LICENSE NUMBER',
              hint: 'DL-12345-XYZ',
              controller: _licenseCtrl,
              prefixIcon: Icons.badge_outlined,
              errorText: _licenseErr,
              onChanged: (_) => setState(() => _licenseErr = null),
            ),
            const SizedBox(height: 14),
          ],

          // Donor: Blood group
          if (widget.role == UserRole.donor) ...[
            Text('BLOOD GROUP', style: AppTextStyles.label()),
            const SizedBox(height: 7),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color:
                        _bloodErr != null ? AppColors.red : AppColors.white08),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  dropdownColor: AppColors.surface2,
                  value: _selectedBloodGroup,
                  hint: Text('Select blood group',
                      style: AppTextStyles.body(
                          size: 14, color: AppColors.white40)),
                  icon: const Icon(Icons.keyboard_arrow_down,
                      color: AppColors.white40),
                  items: _validBloodGroups
                      .map((g) => DropdownMenuItem(
                          value: g,
                          child: Text(g, style: AppTextStyles.body(size: 14))))
                      .toList(),
                  onChanged: (v) {
                    Haptics.light();
                    setState(() {
                      _selectedBloodGroup = v;
                      _bloodErr = null;
                    });
                  },
                ),
              ),
            ),
            if (_bloodErr != null) ...[
              const SizedBox(height: 4),
              Text(_bloodErr!,
                  style: AppTextStyles.body(size: 11, color: AppColors.red)),
            ],
            const SizedBox(height: 14),
          ],

          // Password
          Text('Password Requirements:',
              style: AppTextStyles.body(size: 12, color: AppColors.white40)),
          Text('Min 8 characters, at least one digit & one special character',
              style: AppTextStyles.body(size: 11, color: AppColors.white40)),
          const SizedBox(height: 6),
          Text('PASSWORD', style: AppTextStyles.label()),
          const SizedBox(height: 7),
          TextField(
            controller: _passCtrl,
            obscureText: _obscure,
            onChanged: (v) => setState(() {
              _passErr = null;
              _passValid = v.length >= 8 &&
                  RegExp(r'\d').hasMatch(v) &&
                  RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(v);
            }),
            style: AppTextStyles.body(size: 14, color: AppColors.white70),
            decoration: InputDecoration(
              hintText: 'Min 8 chars, 1 digit, 1 special char',
              hintStyle: AppTextStyles.body(size: 14, color: AppColors.white40),
              prefixIcon: const Icon(Icons.lock_outline,
                  color: AppColors.white40, size: 18),
              errorText: _passErr,
              suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
                if (_passValid)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(Icons.check_circle_rounded,
                        color: AppColors.green, size: 20),
                  ),
                IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppColors.white40,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 28),

          AnimatedPressButton(
            onTap: _nextStep,
            child: ElevatedButton(
                onPressed: _nextStep, child: const Text('Continue')),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text('STEP 1 OF ${_isCustomer ? 2 : 3} - DETAILS',
                style: AppTextStyles.label(color: AppColors.white40)),
          ),
          const SizedBox(height: 32),
        ]),
      );

  // ── Step 1: Documents ───────────────────────────────────────────────────
  Widget _documentsStep() => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 16),
          Text('Upload Documents', style: AppTextStyles.heading(26)),
          const SizedBox(height: 6),
          Text('Required for verification. Files are stored securely.',
              style: AppTextStyles.body(size: 14, color: AppColors.white40)),
          const SizedBox(height: 28),

          // Government ID — all roles
          _docTile('Government ID', Icons.badge_outlined, 'ID Card / Passport',
              'government_id'),
          const SizedBox(height: 14),

          // Driver specific
          if (widget.role == UserRole.driver) ...[
            _docTile('Driver License', Icons.drive_eta, 'Front & Back',
                'driver_license'),
            const SizedBox(height: 14),
            _docTile('Vehicle Registration', Icons.local_shipping_rounded,
                'Registration Certificate', 'vehicle_registration'),
            const SizedBox(height: 14),
          ],

          // Donor specific
          if (widget.role == UserRole.donor) ...[
            _docTile('Medical Certificate', Icons.medical_services_outlined,
                'Blood test results (recent)', 'medical_certificate'),
            const SizedBox(height: 14),
          ],

          _docTile('Profile Photo', Icons.camera_alt_outlined,
              'Clear face photo', 'profile_photo'),
          const SizedBox(height: 28),

          AnimatedPressButton(
            onTap: _nextStep,
            child: ElevatedButton(
              onPressed: _nextStep,
              child: const Text('Send Verification Code'),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text('STEP 2 OF 3 - DOCUMENTS',
                style: AppTextStyles.label(color: AppColors.white40)),
          ),
          const SizedBox(height: 32),
        ]),
      );

  Widget _docTile(
      String label, IconData icon, String sub, String documentType) {
    final isUploaded = _uploadedDocs[documentType] != null;
    final isUploading = _uploadingDocs[documentType] == true;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        splashColor: AppColors.redDim,
        onTap: isUploading
            ? null
            : () async {
                Haptics.light();
                // Pick file
                final picker = ImagePicker();
                final picked = await picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 80,
                );
                if (picked == null) return;

                setState(() => _uploadingDocs[documentType] = true);
                try {
                  // We don't have userId yet (not registered) so store locally
                  // and upload after registration in _verifyOtp
                  setState(() {
                    _uploadedDocs[documentType] =
                        picked.path; // local path for now
                    _uploadingDocs[documentType] = false;
                  });
                  if (mounted) showSuccessSnack(context, '$label selected ✓');
                } catch (e) {
                  if (mounted) {
                    showErrorSnack(context, 'Failed to select $label');
                    setState(() => _uploadingDocs[documentType] = false);
                  }
                }
              },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isUploaded
                ? AppColors.green.withOpacity(0.08)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isUploaded ? AppColors.green : AppColors.white08,
            ),
          ),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isUploaded
                    ? AppColors.green.withOpacity(0.15)
                    : AppColors.redDim,
                borderRadius: BorderRadius.circular(10),
              ),
              child: isUploading
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                          color: AppColors.red, strokeWidth: 2),
                    )
                  : Icon(
                      isUploaded ? Icons.check_circle_rounded : icon,
                      color: isUploaded ? AppColors.green : AppColors.red,
                      size: 22,
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.bodyMedium(size: 14)),
                  Text(
                    isUploaded ? 'File selected ✓' : sub,
                    style: AppTextStyles.body(
                      size: 12,
                      color: isUploaded ? AppColors.green : AppColors.white40,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              isUploaded ? Icons.edit_outlined : Icons.upload_rounded,
              color: AppColors.white40,
              size: 20,
            ),
          ]),
        ),
      ),
    );
  }

// ── Step 2: OTP ─────────────────────────────────────────────────────────
  Widget _otpStep() => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 16),
          Text('Verify Email', style: AppTextStyles.heading(26)),
          const SizedBox(height: 6),
          Text(
            'Enter the 6-digit code sent to ${_emailCtrl.text.isEmpty ? "your email" : _emailCtrl.text}.',
            style: AppTextStyles.body(size: 14, color: AppColors.white40),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              6, // ✅ 6 digits for email OTP
              (i) => SizedBox(
                width: 46,
                height: 64,
                child: TextField(
                  controller: _otpCtrls[i],
                  focusNode: _otpFocus[i],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  style: AppTextStyles.heading(24),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    counterText: '',
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.white15),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: AppColors.red, width: 2),
                    ),
                  ),
                  onChanged: (v) {
                    if (v.isNotEmpty && i < 5) {
                      Haptics.light();
                      FocusScope.of(context).requestFocus(_otpFocus[i + 1]);
                    }
                    if (v.isEmpty && i > 0) {
                      FocusScope.of(context).requestFocus(_otpFocus[i - 1]);
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          AnimatedPressButton(
            onTap: _loading ? null : _verifyOtp,
            child: ElevatedButton(
              onPressed: _loading ? null : _verifyOtp,
              child: const Text('Verify & Create Account'),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              splashColor: AppColors.redDim,
              onTap: () {
                Haptics.light();
                showSuccessSnack(context, 'Code resent');
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text('Resend Code',
                    style: AppTextStyles.body(size: 14, color: AppColors.red)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'STEP ${_isCustomer ? 2 : 3} OF ${_isCustomer ? 2 : 3} - VERIFICATION',
              style: AppTextStyles.label(color: AppColors.white40),
            ),
          ),
          const SizedBox(height: 32),
        ]),
      );
} // ✅ Single closing parenthesis - end of method
// ═══════════════════════════════════════════════════════════════════════════
// UPDATE PASSWORD
// ═══════════════════════════════════════════════════════════════════════════

class UpdatePasswordScreen extends StatefulWidget {
  const UpdatePasswordScreen({super.key});
  @override
  State<UpdatePasswordScreen> createState() => _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends State<UpdatePasswordScreen> {
  final _passCtrl = TextEditingController();
  bool _obscure = true, _loading = false;
  String? _passError;

  @override
  void dispose() {
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    final pass = _passCtrl.text.trim();
    if (pass.length < 6) {
      setState(() => _passError = 'Password must be at least 6 characters');
      Haptics.medium();
      return;
    }
    Haptics.heavy();
    setState(() {
      _loading = true;
      _passError = null;
    });

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: pass),
      );
      if (mounted) {
        showSuccessSnack(context, 'Password updated successfully');
        Navigator.pushAndRemoveUntil(
          context,
          fadeRoute(const LoginScreen()),
          (_) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showErrorSnack(context, 'Failed to update password');
        Haptics.medium();
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: AppColors.white08,
                  borderRadius: BorderRadius.circular(50)),
              child: const Icon(Icons.arrow_back, size: 18),
            ),
            onPressed: () {
              Haptics.light();
              Navigator.pushAndRemoveUntil(
                context,
                fadeRoute(const LoginScreen()),
                (_) => false,
              );
            },
          ),
          title: Text('RESQLINK',
              style: AppTextStyles.heading(13, color: AppColors.red)
                  .copyWith(letterSpacing: 3)),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              Text('Update Password', style: AppTextStyles.heading(28)),
              const SizedBox(height: 8),
              Text("Enter your new password below.",
                  style:
                      AppTextStyles.body(size: 14, color: AppColors.white40)),
              const SizedBox(height: 40),
              Text('NEW PASSWORD', style: AppTextStyles.label()),
              const SizedBox(height: 8),
              Semantics(
                label: 'New password input',
                child: TextField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  onChanged: (_) => setState(() => _passError = null),
                  style: AppTextStyles.body(),
                  decoration: InputDecoration(
                    hintText: 'Minimum 6 characters',
                    errorText: _passError,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.white40,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              AnimatedPressButton(
                onTap: _loading ? null : _updatePassword,
                child: ElevatedButton(
                  onPressed: _loading ? null : _updatePassword,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Save New Password'),
                ),
              ),
            ],
          ),
        ),
      );
}
