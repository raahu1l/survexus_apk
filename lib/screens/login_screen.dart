import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dashboard_screen.dart';
import '../services/firebase_auth_service.dart';
import 'landing_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuthService _authService = FirebaseAuthService();
  bool _loading = false;

  void _navigateToDashboard() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
      (route) => false,
    );
  }

  // ───────────────────────────────
  // EMAIL LOGIN
  // ───────────────────────────────
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      await cred.user?.getIdToken(true);
      await cred.user?.reload();

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Login successful!')));
      _navigateToDashboard();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Login failed')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ───────────────────────────────
  // GOOGLE LOGIN (uses service)
  // ───────────────────────────────
  Future<void> _googleLogin() async {
    setState(() => _loading = true);
    try {
      final user = await _authService.signInWithGoogle();
      if (user == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      await user.getIdToken(true);
      await user.reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Signed in as ${user.displayName ?? "User"}')),
      );
      _navigateToDashboard();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google sign-in failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ───────────────────────────────
  // PASSWORD RESET
  // ───────────────────────────────
  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your registered email first.')),
      );
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send reset email: $e')),
      );
    }
  }

  void _loginAsGuest() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Proceeding as Guest...')),
    );
    _navigateToDashboard();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 🔙 BACK BUTTON ADDED → LANDING SCREEN
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LandingScreen()),
            );
          },
        ),
      ),

      extendBodyBehindAppBar: true,

      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              physics: const BouncingScrollPhysics(),
              child: Container(
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(255, 255, 255, 0.15),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: const Color.fromRGBO(255, 255, 255, 0.25),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const Icon(Icons.lock_outline,
                          size: 70, color: Colors.white),
                      const SizedBox(height: 12),
                      const Text(
                        'Login to Survexus',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 30),
                      TextFormField(
                        controller: _emailController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration(
                          label: 'Email Address',
                          icon: Icons.email_outlined,
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => v == null || !v.contains('@')
                            ? 'Enter valid email'
                            : null,
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _passwordController,
                        style: const TextStyle(color: Colors.white),
                        obscureText: true,
                        decoration: _inputDecoration(
                          label: 'Password',
                          icon: Icons.lock_outline,
                        ),
                        validator: (v) => v == null || v.length < 6
                            ? 'Min 6 characters'
                            : null,
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.deepPurpleAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 5,
                          ),
                          child: _loading
                              ? const CircularProgressIndicator(
                                  color: Colors.deepPurpleAccent,
                                )
                              : const Text(
                                  'Login',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _forgotPassword,
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                      const Divider(
                        color: Colors.white38,
                        thickness: 1,
                        height: 28,
                      ),
                      _altButton(
                        label: 'Login as Guest',
                        icon: Icons.person_outline,
                        color: Colors.transparent,
                        borderColor: Colors.white,
                        textColor: Colors.white,
                        onPressed: _loginAsGuest,
                      ),
                      const SizedBox(height: 10),
                      _altButton(
                        label: 'Login with Google',
                        icon: Icons.g_mobiledata_rounded,
                        color: Colors.white,
                        textColor: Colors.blueAccent,
                        onPressed: _googleLogin,
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

  Widget _altButton({
    required String label,
    required IconData icon,
    required Color color,
    Color? borderColor,
    required Color textColor,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: _loading ? null : onPressed,
        icon: Icon(icon, color: textColor),
        label: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          side: BorderSide(
            color: borderColor ?? Colors.transparent,
            width: borderColor != null ? 2 : 0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: color == Colors.transparent ? 0 : 6,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIcon: Icon(icon, color: Colors.white70),
      filled: true,
      fillColor: Colors.white.withOpacity(0.1),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Colors.white70),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Colors.white38),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Colors.white),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }
}
