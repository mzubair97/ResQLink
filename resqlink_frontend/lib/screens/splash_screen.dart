import 'package:flutter/material.dart';
import 'dart:async'; // Required for Timer
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Set a 3-second delay before navigating
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ambulance/Drop Logo Placeholder
            Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.water_drop,
                  size: 120,
                  color: Color(0xFFE53935),
                ),
                const Icon(Icons.emergency, size: 40, color: Colors.white),
              ],
            ),
            const SizedBox(height: 24),
            RichText(
              text: const TextSpan(
                style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                children: [
                  TextSpan(
                    text: 'ResQ',
                    style: TextStyle(color: Colors.white),
                  ),
                  TextSpan(
                    text: 'Link',
                    style: TextStyle(color: Color(0xFFE53935)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Emergency Help, Instantly",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
