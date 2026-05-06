import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_theme.dart';
import 'modules/auth/auth_screens.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://kqyvdproxcokxubeemoy.supabase.co',
    anonKey: 'sb_publishable_yLCOFZg5kCIL2Hd-wWnRbg_QI7KE-EE',
  );

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const ResQLinkApp());
}

class ResQLinkApp extends StatefulWidget {
  const ResQLinkApp({super.key});

  @override
  State<ResQLinkApp> createState() => _ResQLinkAppState();
}

class _ResQLinkAppState extends State<ResQLinkApp> {
  late final StreamSubscription<AuthState> _authSubscription;
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.passwordRecovery) {
        _navigatorKey.currentState?.pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const UpdatePasswordScreen(),
            transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'ResQLink',
      theme: buildAppTheme(),
      // Always show the splash screen first; session check happens inside it.
      home: const SplashScreen(),
    );
  }
}

