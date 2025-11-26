import 'dart:ui';
import 'package:flutter/material.dart';
import 'admin_login_screen.dart';
import 'landing_screen.dart'; // ✅ Added import for fallback navigation

class AdminAccessScreen extends StatelessWidget {
  const AdminAccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () {
            // ✅ Fix: Prevent black screen when no previous screen exists
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LandingScreen()),
              );
            }
          },
        ),
        title: const Text(
          'Admin Access',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF6A11CB),
              Color(0xFF2575FC),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  const Text(
                    "Select Admin Role",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // 🌟 Student Admin Card
                  _buildFrostedCard(
                    context,
                    title: "Student Admin",
                    icon: Icons.school_rounded,
                    color: Colors.blueAccent,
                    description:
                        "Manage student surveys, responses, and insights.",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const AdminLoginScreen(role: "student"),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 25),

                  // 🌟 Professor Admin Card
                  _buildFrostedCard(
                    context,
                    title: "Professor Admin",
                    icon: Icons.person_rounded,
                    color: Colors.purpleAccent,
                    description:
                        "Create, review, and analyze surveys for research or class.",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const AdminLoginScreen(role: "professor"),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFrostedCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: Colors.white.withAlpha((0.4 * 255).toInt()), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.25 * 255).toInt()),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              color: Colors.white.withAlpha((0.15 * 255).toInt()),
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Icon(icon, color: color, size: 48),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color.withAlpha((0.85 * 255).toInt()),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(150, 46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 3,
                    ),
                    onPressed: onTap,
                    child: const Text(
                      "Continue",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
