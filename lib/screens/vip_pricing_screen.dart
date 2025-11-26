import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'landing_screen.dart';

class VipPricingScreen extends StatefulWidget {
  final bool dialogMode;
  const VipPricingScreen({super.key, this.dialogMode = false});

  @override
  State<VipPricingScreen> createState() => _VipPricingScreenState();
}

class _VipPricingScreenState extends State<VipPricingScreen> {
  bool _isVIPPurchased = false;
  bool _popupShown = false;

  @override
  void initState() {
    super.initState();
    _checkExistingVip();
  }

  Future<void> _checkExistingVip() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && (doc.data()?['premium'] == true)) {
        if (mounted) setState(() => _isVIPPurchased = true);
      }
    } catch (e) {
      debugPrint("VIP check failed: $e");
    }
  }

  Future<void> _grantVipAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to upgrade to VIP.')),
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LandingScreen()),
        (r) => false,
      );
      return;
    }

    try {
      // Update Firestore immediately
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'premium': true,
        'premiumSince': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() => _isVIPPurchased = true);

      // Show popup message for re-login
      if (!_popupShown) {
        _popupShown = true;
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Text(
              '🎉 VIP Activated',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: const Text(
              '⭐ VIP plan activated successfully.\n\n⚠️ You must re-login to enable premium features.',
              style: TextStyle(fontSize: 15.5, height: 1.4),
            ),
            actions: [
              ElevatedButton.icon(
                icon: const Icon(Icons.logout_rounded, size: 20),
                onPressed: () async {
                  try {
                    await FirebaseAuth.instance.signOut();
                  } catch (_) {}
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LandingScreen()),
                    (r) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                label: const Text(
                  'Log Out Now',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not grant VIP: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isGuest = FirebaseAuth.instance.currentUser == null;

    if (widget.dialogMode) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("VIP Pricing & Plans"),
        content: const Text(
          "Unlock VIP to access analytics, exports, and premium tools. Continue to the full upgrade page to complete your purchase.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const VipPricingScreen(dialogMode: false),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
            ),
            child: const Text('Open VIP Page'),
          ),
        ],
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('VIP Pricing & Plans'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A2980), Color(0xFF26D0CE)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text(
                  'Choose Your Plan',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 25),

                // Free Plan Card
                _glassPlanCard(
                  title: 'Free Plan',
                  price: '₹0 / month',
                  features: const [
                    '✅ Create unlimited surveys',
                    '✅ Save survey drafts',
                    '✅ View response summaries',
                    '🚫 Export or analytics access',
                    '🚫 Custom branding & AI tools',
                  ],
                  highlight: false,
                  buttonLabel: 'Active Plan',
                  buttonAction: null,
                ),

                const SizedBox(height: 30),

                // VIP Plan Card
                _glassPlanCard(
                  title: _isVIPPurchased ? 'VIP Plan ✅ Verified' : 'VIP Plan',
                  price: '₹499 / month',
                  features: const [
                    '✨ All Free Plan features',
                    '📊 Advanced analytics & insights',
                    '🧠 Predictive trend visualization',
                    '📥 Export data (CSV, PDF)',
                    '🎨 Custom branding & design tools',
                    '📢 Priority email + chat support',
                    '🔒 VIP-only templates & forms',
                    '🌐 Cross-platform dashboards',
                    '💡 AI survey question suggestions',
                  ],
                  highlight: true,
                  buttonLabel:
                      _isVIPPurchased ? 'VIP Active' : 'Buy Now (Get Access)',
                  buttonAction: _isVIPPurchased
                      ? () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('⚠️ VIP Plan Purchased'),
                              content: const Text(
                                'You need to re-login to activate the VIP features.',
                              ),
                              actions: [
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.logout_rounded),
                                  label: const Text('Log Out Now'),
                                  onPressed: () async {
                                    await FirebaseAuth.instance.signOut();
                                    if (!context.mounted) return;
                                    Navigator.of(context).pushAndRemoveUntil(
                                      MaterialPageRoute(
                                        builder: (_) => const LandingScreen(),
                                      ),
                                      (r) => false,
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        }
                      : () {
                          if (isGuest) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Please log in to upgrade.')),
                            );
                            Navigator.of(context, rootNavigator: true)
                                .pushAndRemoveUntil(
                              MaterialPageRoute(
                                  builder: (_) => const LandingScreen()),
                              (r) => false,
                            );
                            return;
                          }
                          _grantVipAccess();
                        },
                ),

                if (isGuest)
                  Padding(
                    padding: const EdgeInsets.only(top: 30),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context, rootNavigator: true)
                            .pushAndRemoveUntil(
                          MaterialPageRoute(
                              builder: (_) => const LandingScreen()),
                          (r) => false,
                        );
                      },
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text(
                        'Sign Up / Log In to Unlock VIP Features',
                        style: TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _glassPlanCard({
    required String title,
    required String price,
    required List<String> features,
    required bool highlight,
    required String buttonLabel,
    required VoidCallback? buttonAction,
  }) {
    Color alpha(Color c, double opacity) =>
        c.withAlpha((opacity * 255).toInt());

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: highlight
                ? alpha(Colors.amberAccent, 0.25)
                : alpha(Colors.white, 0.12),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: alpha(Colors.white, 0.3),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: highlight
                    ? alpha(Colors.amber, 0.3)
                    : alpha(Colors.black, 0.1),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    highlight
                        ? Icons.workspace_premium_rounded
                        : Icons.card_giftcard_rounded,
                    color: highlight ? Colors.yellowAccent : Colors.white70,
                    size: 32,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                price,
                style: TextStyle(
                  fontSize: 20,
                  color: highlight ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: features
                    .map(
                      (f) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              f.startsWith('🚫')
                                  ? Icons.cancel_rounded
                                  : Icons.check_circle_rounded,
                              color: f.startsWith('🚫')
                                  ? Colors.redAccent
                                  : Colors.greenAccent,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                f
                                    .replaceAll(
                                        RegExp(r'[✅🚫✨📊🧠📥🎨📢🔒🌐💡]'), '')
                                    .trim(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15.5,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: buttonAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        highlight ? Colors.white : Colors.blueAccent,
                    foregroundColor:
                        highlight ? Colors.amber.shade800 : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 12),
                  ),
                  child: Text(
                    buttonLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
