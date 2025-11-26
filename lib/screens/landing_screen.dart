import 'package:flutter/material.dart';
import 'signup_screen.dart';
import 'login_screen.dart';
import 'admin_access_screen.dart';
import '../animated_logo.dart';
// 🔹 new import

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🔹 Background image (replaces gradient)
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background_image.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // 🔹 Main content (everything else)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // 🔹 Admin Access Button (Top Right)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.12),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                        icon: const Icon(Icons.admin_panel_settings_outlined),
                        label: const Text("Admin Access"),
                        onPressed: () {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                                builder: (_) => const AdminAccessScreen()),
                            (route) => false,
                          );
                        },
                      ),
                    ],
                  ),

                  const Spacer(),

                  // 🔹 Animated Logo above the card
                  const AnimatedLogo(), // ✨ added animation

                  const SizedBox(height: 40),

                  // 🔹 App Title Card (unchanged)
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF56CCF2), Color(0xFF2F80ED)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 14,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Survexus',
                          style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.8,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Turning Data into Decisions',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 19,
                            color: Colors.white70,
                            fontStyle: FontStyle.italic,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 38),

                        // 🔹 Sign Up Button
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.blueAccent.shade700,
                            elevation: 3,
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                  builder: (_) => const SignupScreen()),
                              (route) => false,
                            );
                          },
                          child: const Text(
                            'Sign Up',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // 🔹 Login Button
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side:
                                const BorderSide(color: Colors.white, width: 2),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                  builder: (_) => const LoginScreen()),
                              (route) => false,
                            );
                          },
                          child: const Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 2),

                  // 🔹 Footer (unchanged)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10.0),
                    child: Text(
                      '© 2025 Survexus Technologies',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
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
}
