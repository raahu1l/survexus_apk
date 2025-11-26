import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _saving = false;
  bool _passwordLinkSent = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await user.reload();
      final freshUser = FirebaseAuth.instance.currentUser;

      _nameController.text = freshUser?.displayName ?? '';
      _emailController.text = freshUser?.email ?? '';

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(freshUser!.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        if ((_nameController.text).trim().isEmpty &&
            (data['name'] ?? '').toString().trim().isNotEmpty) {
          _nameController.text = data['name'];
        }
        if ((_emailController.text).trim().isEmpty &&
            (data['email'] ?? '').toString().trim().isNotEmpty) {
          _emailController.text = data['email'];
        }
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('⚠️ Error loading profile: $e');
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final newName = _nameController.text.trim();
      final newEmail = _emailController.text.trim();
      bool emailChanged = false;

      if ((user.displayName ?? '') != newName) {
        await user.updateDisplayName(newName);
      }

      if ((user.email ?? '') != newEmail) {
        emailChanged = true;
        await user.verifyBeforeUpdateEmail(newEmail);
      }

      await user.reload();
      final refreshed = FirebaseAuth.instance.currentUser!;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(refreshed.uid)
          .set({
        'name': newName,
        if (!emailChanged) 'email': (refreshed.email ?? newEmail),
      }, SetOptions(merge: true));

      if (!mounted) return;
      _showSnack(emailChanged
          ? '✅ Name updated. Check your inbox to confirm the new email.'
          : '✅ Profile updated successfully!');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error updating profile: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) {
      _showSnack('⚠️ You are not logged in.');
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      setState(() => _passwordLinkSent = true);
      _showSnack('🔐 Password reset link sent!');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error sending reset link: $e');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Settings'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 2,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SizedBox(height: 10),
              const Text(
                "Edit Profile",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Full Name",
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.trim().length < 2
                    ? 'Enter a valid name'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: "Email Address",
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || !v.contains('@')
                    ? 'Enter a valid email'
                    : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.save_rounded),
                label: Text(_saving ? 'Saving...' : 'Save Changes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _saving ? null : _saveProfile,
              ),
              const SizedBox(height: 24),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.lock_outline, color: Colors.black54),
                title: const Text('Change Password'),
                onTap: _changePassword,
              ),
              if (_passwordLinkSent)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                  child: Text(
                    "✅ Password reset link has been sent to your email.",
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              const Divider(),
              // ✅ Delete Account button removed completely
            ],
          ),
        ),
      ),
    );
  }
}
