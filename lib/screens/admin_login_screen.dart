import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_access_screen.dart';
import 'admin_dashboard_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  final String role; // "student" or "professor"
  const AdminLoginScreen({required this.role, super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    // Prefill for quick testing
    if (widget.role.toLowerCase() == 'professor') {
      _emailController.text = 'vpg@gmail.com';
    } else if (widget.role.toLowerCase() == 'student') {
      _emailController.text = 'rahul@gmail.com';
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter email and password.")),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      // ✅ 1) Hardcoded admin logins (skip Firebase completely if matched)
      final e = email.toLowerCase();
      final r = widget.role.toLowerCase();

      final isProfessorHardcoded =
          (r == 'professor' && e == 'vpg@gmail.com' && password == '1234');
      final isStudentHardcoded =
          (r == 'student' && e == 'rahul@gmail.com' && password == '1234');

      if (isProfessorHardcoded || isStudentHardcoded) {
        final roleStr = isProfessorHardcoded ? 'professor' : 'student';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ Welcome ${roleStr.toUpperCase()} Admin!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => AdminDashboardScreen(role: roleStr),
          ),
          (_) => false,
        );
        return;
      }

      // ✅ 2) Otherwise fallback to Firebase Auth (for real accounts)
      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      final user = credential.user;
      if (user == null) throw Exception("User not found.");

      // 3️⃣ Verify Firestore admin record
      final adminSnap = await FirebaseFirestore.instance
          .collection('admins')
          .doc(user.uid)
          .get();

      if (!adminSnap.exists) {
        throw Exception(
          "Access denied — no admin record for this account. Please register first.",
        );
      }

      final data = adminSnap.data()!;
      final storedRole = (data['role'] ?? '').toString().toLowerCase();
      final expectedRole = r;
      final isActive = data['active'] != false; // default true

      if (!isActive) {
        await FirebaseAuth.instance.signOut();
        throw Exception("Admin account is disabled. Contact support.");
      }

      if (storedRole != expectedRole) {
        await FirebaseAuth.instance.signOut();
        throw Exception(
          "Incorrect role — registered as '$storedRole', not '$expectedRole'.",
        );
      }

      // ✅ Success → Go to dashboard
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✅ Welcome ${widget.role.toUpperCase()} Admin!"),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => AdminDashboardScreen(role: widget.role),
        ),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String msg = "Login failed. Please try again.";
      switch (e.code) {
        case 'user-not-found':
          msg = "No user found for that email.";
          break;
        case 'wrong-password':
          msg = "Incorrect password.";
          break;
        case 'invalid-email':
          msg = "Invalid email format.";
          break;
        case 'invalid-credential':
          msg = "Invalid credentials.";
          break;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⚠️ ${e.toString()}")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Optional admin registration (kept for future)
  Future<void> _registerAdmin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter email & password to register.")),
      );
      return;
    }

    try {
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      await FirebaseFirestore.instance
          .collection('admins')
          .doc(cred.user!.uid)
          .set({
        'email': email,
        'role': widget.role.toLowerCase(),
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Admin registered successfully.")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title =
        "${widget.role[0].toUpperCase()}${widget.role.substring(1)} Admin Login";

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () {
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const AdminAccessScreen()),
            );
          },
        ),
        title: Text(title, style: const TextStyle(color: Colors.white)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(255, 255, 255, 0.15),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: const Color.fromRGBO(255, 255, 255, 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.admin_panel_settings,
                          color: Colors.white, size: 70),
                      const SizedBox(height: 12),
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 30),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _input("Email", Icons.email_outlined),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscure,
                        decoration: _input(
                          "Password",
                          Icons.lock_outline,
                          suffix: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.white70,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ),
                      const SizedBox(height: 26),
                      ElevatedButton(
                        onPressed: _loading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.deepPurple,
                          minimumSize: const Size.fromHeight(50),
                        ),
                        child: _loading
                            ? const CircularProgressIndicator(
                                color: Colors.deepPurple,
                              )
                            : const Text(
                                "Login",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                      const SizedBox(height: 14),
                      TextButton(
                        onPressed: _registerAdmin,
                        child: const Text(
                          "Register as Admin",
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _input(String label, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIcon: Icon(icon, color: Colors.white70),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color.fromRGBO(255, 255, 255, 0.1),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
    );
  }
}
