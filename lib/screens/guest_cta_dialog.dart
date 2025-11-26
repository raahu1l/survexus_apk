import 'package:flutter/material.dart';
import 'landing_screen.dart';

class GuestCtaDialog extends StatelessWidget {
  const GuestCtaDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🔹 Icon Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF2FF),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                color: Color(0xFF6366F1),
                size: 40,
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              "Limited Access Mode",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E1E2D),
              ),
            ),
            const SizedBox(height: 12),

            const Text(
              "You're currently exploring as a guest. Sign up or log in to unlock all features — including creating, managing, and analyzing surveys.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 🔸 Maybe Later button
                TextButton(
                  onPressed: () =>
                      Navigator.of(context, rootNavigator: true).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  child: const Text("Maybe Later"),
                ),

                // 🔹 Sign Up / Log In button
                ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                  label: const Text(
                    "Sign Up / Log In",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                  ),
                  onPressed: () {
                    // ✅ Close dialog first
                    Navigator.of(context, rootNavigator: true).pop();

                    // ✅ Then schedule navigation to LandingScreen after frame
                    Future.delayed(Duration.zero, () {
                      Navigator.of(context, rootNavigator: true)
                          .pushAndRemoveUntil(
                        MaterialPageRoute(
                            builder: (_) => const LandingScreen()),
                        (route) => false,
                      );
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
