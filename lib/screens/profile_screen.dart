import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'vip_pricing_screen.dart';
import 'notification_screen.dart';
import 'settings_screen.dart';
import 'landing_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool isGuest;
  const ProfileScreen({required this.isGuest, super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isVIP = false;
  bool _loading = true;
  String _displayName = 'User';
  String _email = 'No email available';
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileListener;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (!widget.isGuest && user != null) {
      _loadProfile();
      _listenUserRealtime();
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _profileListener?.cancel();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      await user.reload();
      final refreshed = FirebaseAuth.instance.currentUser;
      String name = refreshed?.displayName ?? '';
      String mail = refreshed?.email ?? '';

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(refreshed!.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          name = name.isNotEmpty ? name : (data['name'] ?? name);
          mail = mail.isNotEmpty ? mail : (data['email'] ?? mail);
          _isVIP = (data['premium'] == true || data['isVIP'] == true);
        }
      }

      if (mounted) {
        setState(() {
          _displayName = name.trim().isEmpty ? 'User' : name.trim();
          _email = mail.trim().isEmpty ? 'No email available' : mail.trim();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _listenUserRealtime() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _profileListener = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final data = snap.data();
      if (data == null) return;

      final newVip = data['premium'] == true || data['isVIP'] == true;
      final newName = (data['name'] ?? _displayName).toString();
      final newEmail = (data['email'] ?? _email).toString();

      setState(() {
        _isVIP = newVip;
        _displayName = newName;
        _email = newEmail;
        _loading = false;
      });
    }, onError: (e) {
      debugPrint("Profile stream error: $e");
    });
  }

  void _resetLocalState() {
    _profileListener?.cancel();
    _profileListener = null;
    _isVIP = false;
    _displayName = 'User';
    _email = 'No email available';
    _loading = false;
  }

  Future<void> _deleteAccount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _navigateToLanding();
        return;
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .delete();
      await user.delete();
      if (!mounted) return;
      _navigateToLanding();
    } catch (e) {
      debugPrint('Delete account error: $e');
      // If delete fails due to re-auth needed, you can handle here
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Failed to delete account. Please re-login and try again.')),
      );
    }
  }

  void _navigateToLanding() {
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LandingScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isGuest) {
      return _buildGuestView(context);
    }

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: () async {
              _resetLocalState();
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              _navigateToLanding();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            CircleAvatar(
              radius: 52,
              backgroundColor:
                  _isVIP ? Colors.amber.shade600 : const Color(0xFF6366F1),
              child: Text(
                _displayName.isNotEmpty ? _displayName[0].toUpperCase() : '?',
                style: const TextStyle(
                    fontSize: 48,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_displayName,
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87)),
                      if (_isVIP)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Icon(Icons.verified_rounded,
                              color: Colors.amber.shade700, size: 22),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(_email,
                      style: const TextStyle(color: Colors.grey, fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const Divider(thickness: 1.2),
            const SizedBox(height: 20),
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              color: _isVIP ? Colors.amber[100] : Colors.amber[50],
              elevation: 2,
              child: ListTile(
                leading: const Icon(Icons.workspace_premium_rounded,
                    color: Colors.amber, size: 36),
                title: Text(_isVIP ? 'You are a VIP Member' : 'VIP Status',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(_isVIP
                    ? 'All premium features unlocked 🎉'
                    : 'You are on Free Plan'),
                trailing: _isVIP
                    ? const Icon(Icons.verified_rounded,
                        color: Colors.amber, size: 30)
                    : ElevatedButton(
                        onPressed: () async {
                          final upgraded = await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const VipPricingScreen(dialogMode: false)),
                          );

                          if (upgraded == true && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  '🎉 VIP purchased successfully! Please re-login for premium features to activate.',
                                  style: TextStyle(fontSize: 15),
                                ),
                                duration: Duration(seconds: 4),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber[700],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                        ),
                        child: const Text('Upgrade'),
                      ),
              ),
            ),
            const SizedBox(height: 28),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.black54),
              title: const Text('Account Settings'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.notifications, color: Colors.black54),
              title: const Text('Notifications'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const NotificationScreen())),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.help_outline, color: Colors.black54),
              title: const Text('Help & Support'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Help & Support'),
                    content: const Text(
                        'For help, contact support@survexus.app\n\nVisit our FAQ section for common questions.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close')),
                    ],
                  ),
                );
              },
            ),
            const Divider(),
            // DELETE ACCOUNT Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Delete Account'),
                    content: const Text(
                        'Are you sure you want to delete your account? This action cannot be undone.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel')),
                      TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete',
                              style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );

                if (confirm == true) {
                  await _deleteAccount();
                }
              },
              child: const Text('Delete Account'),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildGuestView(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 2,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_outline_rounded,
                  size: 90, color: Colors.grey),
              const SizedBox(height: 24),
              const Text(
                'You need to log in to view your details',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
