// lib/screens/dashboard_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'explore_surveys_screen.dart';
import 'survey_creation_screen.dart';
import 'my_surveys_screen.dart';
import 'analytics_screen.dart';
import 'profile_screen.dart';
import 'guest_cta_dialog.dart';
import 'vip_pricing_screen.dart';
import 'notification_screen.dart';
import 'settings_screen.dart';
import 'login_screen.dart';
import 'landing_screen.dart';
import '../services/api_service.dart';

// ⭐ Chatbot imports
import '../widgets/app_chatbot.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  bool _showedGuestDialog = false;
  bool _showedVipDialog = false;

  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();

    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        _showedGuestDialog = false;
        _showedVipDialog = false;
      }
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowGuestOrVip();
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  void _maybeShowGuestOrVip() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null && !_showedGuestDialog) {
      _showedGuestDialog = true;
      if (mounted) {
        showDialog(context: context, builder: (c) => GuestCtaDialog());
      }
      return;
    }

    if (user != null && !_showedVipDialog) {
      _showedVipDialog = true;
      Future.microtask(() async {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

          final isPremium =
              doc.data()?['premium'] == true || doc.data()?['isVIP'] == true;

          if (!isPremium && mounted) {
            await showDialog(
              context: context,
              builder: (c) => VipPricingScreen(dialogMode: true),
            );
          }
        } catch (_) {}
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isGuest = user == null;

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomeDashboard(isGuest: isGuest), // ⭐ Chatbot lives here
          const ExploreSurveysScreen(),
          isGuest
              ? const _SignInRequiredTab(feature: "create surveys")
              : SurveyCreationScreen(),
          isGuest
              ? const _SignInRequiredTab(feature: "manage surveys")
              : MySurveysScreen(),
          isGuest
              ? const _SignInRequiredTab(feature: "view analytics")
              : AnalyticsScreen(),
          ProfileScreen(isGuest: isGuest),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        selectedItemColor: const Color(0xFF6366F1),
        unselectedItemColor: Colors.grey[600],
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.public), label: "Explore"),
          BottomNavigationBarItem(
              icon: Icon(Icons.add_box_rounded), label: "Create"),
          BottomNavigationBarItem(
              icon: Icon(Icons.folder_special_rounded), label: "My Surveys"),
          BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_rounded), label: "Analytics"),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded), label: "Profile"),
        ],
      ),
    );
  }
}

/*───────────────────────────────────────────────────────────────*
 *                      HOME DASHBOARD
 *───────────────────────────────────────────────────────────────*/

class HomeDashboard extends StatefulWidget {
  final bool isGuest;
  const HomeDashboard({required this.isGuest, super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard>
    with TickerProviderStateMixin {
  bool _isVIP = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _vipSub;

  late final AnimationController _glowController;
  late final Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _glowAnim = Tween<double>(begin: 0.9, end: 1.06).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchVIPStatus();
      _listenVipRealtime();
    });
  }

  @override
  void dispose() {
    _vipSub?.cancel();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _fetchVIPStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (mounted) {
        setState(() => _isVIP = doc.exists &&
            ((doc.data()?['premium'] == true) ||
                (doc.data()?['isVIP'] == true)));
      }
    } catch (e) {
      debugPrint("Error fetching VIP: $e");
    }
  }

  void _listenVipRealtime() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _vipSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;

      final premium =
          snap.data()?['premium'] == true || snap.data()?['isVIP'] == true;

      if (premium != _isVIP) {
        setState(() => _isVIP = premium);
      }
    });
  }

  Future<void> _safeNavigate(BuildContext context, Widget page) async {
    if (!context.mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isGuest = widget.isGuest;

    return Stack(
      children: [
        /*───────────────────────────────────────────────*
         *      MAIN HOME DASHBOARD UI (background)
         *───────────────────────────────────────────────*/
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              children: [
                // ------------------------------------------
                // Header Row
                // ------------------------------------------
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ScaleTransition(
                      scale: _glowAnim,
                      child: _GlowingAvatar(
                        uid: currentUser?.uid,
                        displayName: currentUser?.displayName,
                        email: currentUser?.email,
                        glowColors: const [
                          Color(0xFF7C3AED),
                          Color(0xFF3B82F6),
                          Color(0xFFE11D48),
                        ],
                        isVIP: _isVIP,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _GradientName(
                            name: currentUser?.displayName ??
                                currentUser?.email?.split('@').first ??
                                (isGuest ? "Guest" : "User"),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isGuest
                                ? "Welcome — explore & respond"
                                : "Let’s create something meaningful",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Notifications',
                          icon: const Icon(Icons.notifications_none_rounded,
                              color: Colors.white, size: 28),
                          onPressed: () =>
                              _safeNavigate(context, NotificationScreen()),
                        ),
                        IconButton(
                          tooltip: 'Settings',
                          icon: const Icon(Icons.settings_outlined,
                              color: Colors.white, size: 26),
                          onPressed: () =>
                              _safeNavigate(context, SettingsScreen()),
                        ),
                        IconButton(
                          tooltip: 'Logout',
                          icon: const Icon(Icons.logout_rounded),
                          color: Colors.white,
                          onPressed: () async {
                            await FirebaseAuth.instance.signOut();
                            if (!context.mounted) return;
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => LandingScreen()),
                              (route) => false,
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                _StatsRow(isGuest: isGuest, uid: currentUser?.uid),

                const SizedBox(height: 24),

                const Text(
                  "Latest News",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),

                const _NewsFeed(),
              ],
            ),
          ),
        ),

        /*───────────────────────────────────────────────*
         *             CHATBOT OVERLAY + BUTTON
         *───────────────────────────────────────────────*/

        AppChatBotWelcomeBanner(),
        Positioned(
          bottom: 20,
          right: 20,
          child: AppChatBotButton(),
        ),
      ],
    );
  }
}

/*───────────────────────────────────────────────────────────────*
 *                      AVATAR WIDGET
 *───────────────────────────────────────────────────────────────*/

class _GlowingAvatar extends StatelessWidget {
  final String? uid;
  final String? displayName;
  final String? email;
  final List<Color> glowColors;
  final bool isVIP;

  const _GlowingAvatar({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.glowColors,
    required this.isVIP,
  });

  String _initials() {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) {
      final parts =
          name.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
      if (parts.length >= 2) {
        return (parts[0][0] + parts[1][0]).toUpperCase();
      }
      return parts[0][0].toUpperCase();
    }

    final em = email?.trim();
    if (em != null && em.isNotEmpty && em.contains('@')) {
      final local = em.split('@').first;
      final pts =
          local.split(RegExp(r'[._-]')).where((s) => s.isNotEmpty).toList();
      if (pts.length >= 2) {
        return (pts[0][0] + pts[1][0]).toUpperCase();
      }
      return local[0].toUpperCase();
    }

    if (uid != null && uid!.isNotEmpty) {
      return uid!.substring(0, uid!.length > 2 ? 2 : 1).toUpperCase();
    }

    return 'G';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: glowColors,
              startAngle: 0.0,
              endAngle: 6.28,
            ),
            boxShadow: [
              BoxShadow(
                color: glowColors.first.withOpacity(0.18),
                blurRadius: 18,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
        Container(
          width: 54,
          height: 54,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: CircleAvatar(
            backgroundColor: const Color(0xFFF1F5F9),
            child: Text(
              _initials(),
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
        if (isVIP)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.amber.shade600,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.shade200.withOpacity(0.6),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: const Icon(Icons.star, size: 12, color: Colors.white),
            ),
          ),
      ],
    );
  }
}

/*───────────────────────────────────────────────────────────────*
 *                        GRADIENT NAME
 *───────────────────────────────────────────────────────────────*/

class _GradientName extends StatelessWidget {
  final String name;
  const _GradientName({required this.name});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) {
        return const LinearGradient(
          colors: [Color(0xFFE11D48), Color(0xFF7C3AED), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height));
      },
      child: Text(
        "Hi, $name",
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/*───────────────────────────────────────────────────────────────*
 *                         STAT CARDS
 *───────────────────────────────────────────────────────────────*/

class _StatsRow extends StatelessWidget {
  final bool isGuest;
  final String? uid;

  const _StatsRow({required this.isGuest, required this.uid});

  List<List<T>> _chunk<T>(List<T> list, int size) {
    final out = <List<T>>[];
    for (var i = 0; i < list.length; i += size) {
      out.add(list.sublist(i, i + size > list.length ? list.length : i + size));
    }
    return out;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _mySurveysStream() {
    if (isGuest || uid == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('surveys')
        .where('creatorId', isEqualTo: uid)
        .snapshots();
  }

  Future<int> _countResponsesForSurveyIds(List<String> ids) async {
    if (ids.isEmpty) return 0;
    final fs = FirebaseFirestore.instance;
    int total = 0;
    final chunks = _chunk<String>(ids, 10);
    for (final c in chunks) {
      final snap =
          await fs.collection('responses').where('surveyId', whereIn: c).get();
      total += snap.size;
    }
    return total;
  }

  Future<int> _countResponsesByUser(String uid) async {
    final snap = await FirebaseFirestore.instance
        .collection('responses')
        .where('respondedBy', isEqualTo: uid)
        .get();
    return snap.size;
  }

  @override
  Widget build(BuildContext context) {
    if (isGuest) {
      return Row(
        children: const [
          Expanded(
            child:
                _StatCard(label: "Created", value: "0", color: Colors.indigo),
          ),
          SizedBox(width: 12),
          Expanded(
            child:
                _StatCard(label: "Responded", value: "0", color: Colors.purple),
          ),
        ],
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _mySurveysStream(),
      builder: (context, snap) {
        final surveys = snap.data?.docs ?? [];
        final createdCount = surveys.length;
        final mySurveyIds = surveys.map((d) => d.id).toList();

        return FutureBuilder<List<int>>(
          future: Future.wait([
            _countResponsesByUser(uid!),
            _countResponsesForSurveyIds(mySurveyIds),
          ]),
          builder: (context, counts) {
            final responded = counts.hasData ? counts.data![0] : 0;

            return Row(
              children: [
                Expanded(
                  child: _StatCard(
                      label: "Created",
                      value: "$createdCount",
                      color: Colors.indigo),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                      label: "Responded",
                      value: "$responded",
                      color: Colors.purple),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final Color color;

  const _StatCard(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.18),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
                fontSize: 15, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/*───────────────────────────────────────────────────────────────*
 *                        NEWS FEED
 *───────────────────────────────────────────────────────────────*/

class _NewsFeed extends StatelessWidget {
  const _NewsFeed();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: ApiService.fetchNews(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }

        if (snap.hasError) {
          return const _NewsCard(
            title: "Error fetching news",
            description: "Please check your connection.",
          );
        }

        final items = snap.data ?? [];

        if (items.isEmpty) {
          return const _NewsCard(
            title: "No news available",
            description: "Please check back later.",
          );
        }

        return Column(
          children: items.map((n) {
            return _NewsCard(
              title: (n['title'] ?? 'Untitled').toString(),
              description: (n['description'] ?? 'No description').toString(),
            );
          }).toList(),
        );
      },
    );
  }
}

class _NewsCard extends StatelessWidget {
  final String title, description;

  const _NewsCard({required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white.withOpacity(0.99),
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            Text(description,
                style: const TextStyle(fontSize: 15, color: Colors.black87)),
          ],
        ),
      ),
    );
  }
}

/*───────────────────────────────────────────────────────────────*
 *                 SIGN-IN REQUIRED PLACEHOLDER
 *───────────────────────────────────────────────────────────────*/

class _SignInRequiredTab extends StatelessWidget {
  final String feature;

  const _SignInRequiredTab({required this.feature});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline_rounded, size: 56, color: Colors.grey),
          const SizedBox(height: 16),
          Text("Sign in required to $feature",
              style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => LoginScreen()),
              (route) => false,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              textStyle:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            child: const Text("Go to Login / Sign Up"),
          ),
        ],
      ),
    );
  }
}
