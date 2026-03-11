import 'package:flutter/material.dart';
import 'signup_screen.dart'; // Make sure this import matches your file structure

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  // Logic: 'Customer', 'Donor', 'Driver'
  String selectedRole = 'Customer';

  // Smooth navigation to the next step
  void _navigateToSignUp() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            SignUpScreen(role: selectedRole),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;
          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Matching your dark theme
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          "RESQLINK",
          style: TextStyle(
            color: Color(0xFFE53935),
            fontSize: 13,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text(
              "Choose Your Role",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Select how you would like to use ResQLink to get started with our emergency services.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, height: 1.4, fontSize: 15),
            ),
            const SizedBox(height: 40),

            // Use the helper method to build the cards
            _roleCard(
              title: "Customer",
              desc: "I need emergency assistance",
              icon: Icons.emergency,
              roleId: 'Customer',
            ),
            const SizedBox(height: 16),
            _roleCard(
              title: "Blood Donor",
              desc: "I want to donate blood",
              icon: Icons.bloodtype,
              roleId: 'Donor',
            ),
            const SizedBox(height: 16),
            _roleCard(
              title: "Ambulance Driver",
              desc: "I am a registered driver",
              icon: Icons.local_shipping,
              roleId: 'Driver',
            ),

            const Spacer(),

            // Action Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _navigateToSignUp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Continue →",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
            const Text(
              "STEP 1 OF 3 • REGISTRATION",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 10,
                letterSpacing: 1,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // Optimized Role Card Widget
  Widget _roleCard({
    required String title,
    required String desc,
    required IconData icon,
    required String roleId,
  }) {
    bool isSelected = selectedRole == roleId;

    return GestureDetector(
      onTap: () => setState(() => selectedRole = roleId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFE53935) : Colors.white12,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            // Icon Container
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFE53935)
                    : const Color(0xFF2D2D2D),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.white54,
              ),
            ),
            const SizedBox(width: 16),
            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: isSelected ? Colors.white : Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
            // Selection Indicator
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFFE53935),
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}
