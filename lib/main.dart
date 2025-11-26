// main.dart — fixed: no unused 'key' parameters, robust startup, no nav loops.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'screens/landing_screen.dart';
import 'screens/dashboard_screen.dart';
import 'providers/app_state_provider.dart';
import 'services/notification_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Start the app quickly; initialization happens inside _InitSplash with timeouts.
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppStateProvider()),
      ],
      child: const SurvexusApp(),
    ),
  );
}

class SurvexusApp extends StatelessWidget {
  const SurvexusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Survexus',
      debugShowCheckedModeBanner: false,

      // Disable Hero animations globally to avoid hero recursion crashes.
      builder: (context, child) => HeroControllerScope.none(child: child!),

      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6366F1),
        useMaterial3: true,
        fontFamily: 'Poppins',
      ),

      // Splash/init screen handles Firebase + notifications with timeouts and retry.
      home: const _InitSplash(),
    );
  }
}

/// Splash + initialization screen.
/// - Runs Firebase.initializeApp() with a timeout
/// - Initializes notifications (with a timeout)
/// - Shows progress → on success navigates to RootRouter
/// - On failure shows error + retry
class _InitSplash extends StatefulWidget {
  const _InitSplash();

  @override
  State<_InitSplash> createState() => _InitSplashState();
}

class _InitSplashState extends State<_InitSplash> {
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _startInit();
  }

  Future<void> _startInit() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      // 1) Firebase init with timeout (8s)
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 8), onTimeout: () {
        throw Exception('Firebase initialization timed out (8s).');
      });

      // 2) Notification init (best-effort with timeout)
      final notif = NotificationService();
      try {
        await notif.init().timeout(const Duration(seconds: 6));
      } catch (e) {
        debugPrint('Notification init failed or timed out: $e');
        // continue — notifications are optional for startup
      }

      // 3) Initialization succeeded — replace splash with RootRouter
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const RootRouter()),
      );
    } catch (e, st) {
      debugPrint('Initialization error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: _busy
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    CircularProgressIndicator(color: Color(0xFF6366F1)),
                    SizedBox(height: 16),
                    Text('Starting Survexus...'),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline,
                        size: 52, color: Colors.red.shade400),
                    const SizedBox(height: 12),
                    const Text(
                      'Initialization failed',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error ?? 'Unknown error',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _startInit,
                      child: const Text('Retry'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      child: const Text('Open app offline (Landing)'),
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                              builder: (_) => const LandingScreen()),
                        );
                      },
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// RootRouter returns LandingScreen or DashboardScreen directly based on auth.
/// This avoids calling Navigator inside stream builders and prevents navigation loops.
class RootRouter extends StatelessWidget {
  const RootRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
                child: CircularProgressIndicator(color: Color(0xFF6366F1))),
          );
        }

        if (snap.hasError) {
          return Scaffold(
            body: Center(
              child: Text('Auth error: ${snap.error}'),
            ),
          );
        }

        final user = snap.data;
        // Directly return the widget (no navigator pushes)
        return user == null ? const LandingScreen() : const DashboardScreen();
      },
    );
  }
}
