import 'package:flutter/material.dart';
import 'driver_dashboard.dart';
class SignUpScreen extends StatefulWidget {
  final String role;

  const SignUpScreen({super.key, required this.role});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Define role-specific controllers here so they persist
  final TextEditingController _licenseController = TextEditingController();
  final TextEditingController _bloodTypeController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _licenseController.dispose();
    _bloodTypeController.dispose();
    super.dispose();
  }

void _handleRegister() {
  if (_nameController.text.trim().isEmpty ||
      _emailController.text.trim().isEmpty) {
    _showError("Please fill in required fields");
    return;
  }

  if (widget.role == 'Driver' && _licenseController.text.isEmpty) {
    _showError("License number is required for drivers");
    return;
  }

  // Navigate to Driver Dashboard
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const DriverDashboard(),
    ),
  );
}

  void _showError(String message) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE53935),
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "RESQLINK",
          style: TextStyle(
            color: Color(0xFFE53935),
            fontSize: 13,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                "Register as ${widget.role}",
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Complete your profile to start using ResQLink services.",
                style: TextStyle(color: Colors.grey[400], fontSize: 15),
              ),
              const SizedBox(height: 32),

              _fieldLabel("FULL NAME"),
              _buildTextField(
                _nameController,
                "John Doe",
                Icons.person_outline,
              ),

              const SizedBox(height: 20),
              _fieldLabel("PHONE NUMBER"),
              _buildTextField(
                _phoneController,
                "+1 000 000 000",
                Icons.phone_outlined,
                type: TextInputType.phone,
              ),

              const SizedBox(height: 20),
              _fieldLabel("EMAIL ADDRESS"),
              _buildTextField(
                _emailController,
                "example@mail.com",
                Icons.email_outlined,
                type: TextInputType.emailAddress,
              ),

              const SizedBox(height: 20),

              // --- DYNAMIC FIELDS BASED ON ROLE ---
              if (widget.role == 'Driver') ...[
                _fieldLabel("LICENSE NUMBER"),
                _buildTextField(
                  _licenseController,
                  "DL-12345-XYZ",
                  Icons.badge_outlined,
                ),
                const SizedBox(height: 20),
              ],

              if (widget.role == 'Donor') ...[
                _fieldLabel("BLOOD TYPE"),
                _buildTextField(
                  _bloodTypeController,
                  "e.g., O+, AB-",
                  Icons.water_drop_outlined,
                ),
                const SizedBox(height: 20),
              ],

              // ------------------------------------
              _fieldLabel("PASSWORD"),
              _buildTextField(
                _passwordController,
                "••••••••",
                Icons.lock_outline,
                isPassword: true,
              ),

              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _handleRegister,
                child: const Text("Register →"),
              ),
              const SizedBox(height: 24),
              const Center(
                child: Text(
                  "STEP 2 OF 3 • DETAILS",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 10,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    TextInputType type = TextInputType.text,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: type,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        suffixIcon: isPassword
            ? const Icon(
                Icons.visibility_outlined,
                color: Colors.white38,
                size: 20,
              )
            : null,
      ),
    );
  }
}
