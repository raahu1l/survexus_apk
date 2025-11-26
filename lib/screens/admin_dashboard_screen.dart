import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'admin_login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  final String role;
  const AdminDashboardScreen({required this.role, super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  bool get isProfessor => widget.role.toLowerCase() == 'professor';

  Future<Map<String, int>> _countStats() async {
    final usersQ = FirebaseFirestore.instance.collection('users');
    final surveysQ = FirebaseFirestore.instance.collection('surveys');
    final responsesQ = FirebaseFirestore.instance.collection('responses');
    int totalUsers = 0, totalSurveys = 0, totalResponses = 0;

    try {
      if (isProfessor) {
        totalUsers = (await usersQ.get()).size;
        totalSurveys = (await surveysQ.get()).size;
        totalResponses = (await responsesQ.get()).size;
      } else {
        final students = await usersQ.where('role', isEqualTo: 'student').get();
        final ids = students.docs.map((d) => d.id).toSet();
        totalUsers = students.size;

        final s = await surveysQ.get();
        totalSurveys =
            s.docs.where((d) => ids.contains(d.data()['ownerId'])).length;

        final r = await responsesQ.get();
        totalResponses =
            r.docs.where((d) => ids.contains(d.data()['userId'])).length;
      }
    } catch (_) {}
    return {
      'users': totalUsers,
      'surveys': totalSurveys,
      'responses': totalResponses
    };
  }

  Widget _glassContainer({required Widget child, EdgeInsets? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(255, 255, 255, 0.12),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white24),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black26, blurRadius: 10, offset: Offset(0, 5)),
            ],
          ),
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }

  Widget _statChip(String label, String value, IconData icon, Color color) {
    return _glassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20)),
              Text(label, style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _togglePremium(String uid, bool current) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'premium': !current});
  }

  Future<void> _toggleSurveyStatus(
      DocumentReference doc, String current) async {
    await doc.update({'status': current == 'active' ? 'closed' : 'active'});
  }

  Future<void> _deleteSurvey(DocumentReference doc) async => doc.delete();

  Stream<QuerySnapshot<Map<String, dynamic>>> _surveysStream() =>
      FirebaseFirestore.instance
          .collection('surveys')
          .orderBy('createdAt', descending: true)
          .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> _usersStream() {
    final col = FirebaseFirestore.instance.collection('users');
    return isProfessor
        ? col.orderBy('createdAt', descending: true).snapshots()
        : col
            .where('role', isEqualTo: 'student')
            .orderBy('createdAt', descending: true)
            .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _notificationsStream() =>
      FirebaseFirestore.instance
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .snapshots();

  Future<Map<String, int>> _responsesPerSurvey() async {
    final res = await FirebaseFirestore.instance.collection('responses').get();
    final map = <String, int>{};
    for (final d in res.docs) {
      final id = d.data()['surveyId']?.toString() ?? 'unknown';
      map[id] = (map[id] ?? 0) + 1;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _overviewTab(),
      _surveysTab(),
      _usersTab(),
      _analyticsTab(),
      _notificationsTab(),
      _settingsTab(),
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          '${isProfessor ? "Professor" : "Student"} Admin Dashboard',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                    builder: (_) => AdminLoginScreen(role: widget.role)),
                (_) => false,
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: IndexedStack(
            index: _selectedIndex,
            children: pages,
          ),
        ),
      ),

      // ✅ Bottom Navigation Tabs
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF6366F1),
        unselectedItemColor: Colors.grey[600],
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded), label: 'Overview'),
          BottomNavigationBarItem(
              icon: Icon(Icons.article_outlined), label: 'Surveys'),
          BottomNavigationBarItem(
              icon: Icon(Icons.people_alt_rounded), label: 'Users'),
          BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_rounded), label: 'Analytics'),
          BottomNavigationBarItem(
              icon: Icon(Icons.notifications_active), label: 'Notifications'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }

  // ---------------- Tabs -------------------

  Widget _overviewTab() => FutureBuilder<Map<String, int>>(
        future: _countStats(),
        builder: (context, snap) {
          final stats = snap.data ?? {'users': 0, 'surveys': 0, 'responses': 0};
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: [
                    _statChip('Total Users', '${stats['users']}', Icons.people,
                        Colors.cyanAccent),
                    _statChip('Surveys', '${stats['surveys']}',
                        Icons.assignment, Colors.amberAccent),
                    _statChip('Responses', '${stats['responses']}', Icons.forum,
                        Colors.pinkAccent),
                  ],
                ),
                const SizedBox(height: 20),
                _glassContainer(
                  child: Column(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.white),
                      const SizedBox(height: 10),
                      Text(
                        isProfessor
                            ? 'You have full administrative privileges.'
                            : 'Scoped access to student data only.',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );

  Widget _surveysTab() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _surveysStream(),
        builder: (context, snap) {
          if (snap.hasError) return _errorWidget('Error loading surveys.');
          if (!snap.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.white));
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) return _emptyWidget('No surveys found.');
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i].data();
              final title = (d['title'] ?? 'Untitled').toString();
              final status = (d['status'] ?? 'active').toString();
              return _glassContainer(
                child: ListTile(
                  title: Text(title,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text('Status: $status',
                      style: const TextStyle(color: Colors.white70)),
                  trailing: PopupMenuButton<String>(
                    color: Colors.white,
                    onSelected: (v) async {
                      if (v == 'toggle') {
                        await _toggleSurveyStatus(
                            snap.data!.docs[i].reference, status);
                      }
                      if (v == 'delete') {
                        await _deleteSurvey(snap.data!.docs[i].reference);
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                          value: 'toggle',
                          child: Text(status == 'active'
                              ? 'Close survey'
                              : 'Activate')),
                      const PopupMenuItem(
                          value: 'delete', child: Text('Delete survey')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );

  Widget _usersTab() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _usersStream(),
        builder: (context, snap) {
          if (snap.hasError) return _errorWidget('Error loading users.');
          if (!snap.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.white));
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) return _emptyWidget('No users found.');
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i].data();
              final name =
                  (d['displayName'] ?? d['name'] ?? 'Unknown').toString();
              final email = (d['email'] ?? '').toString();
              final role = (d['role'] ?? 'User').toString();
              final premium = d['premium'] == true;
              return _glassContainer(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.white24,
                    child: Icon(
                        role == 'professor'
                            ? Icons.school
                            : Icons.person_outline,
                        color: Colors.white),
                  ),
                  title: Text(name,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text('$email • $role',
                      style: const TextStyle(color: Colors.white70)),
                  trailing: TextButton.icon(
                    onPressed: () => _togglePremium(docs[i].id, premium),
                    icon: Icon(
                        premium
                            ? Icons.verified_rounded
                            : Icons.workspace_premium_outlined,
                        color: premium ? Colors.yellowAccent : Colors.white),
                    label: Text(premium ? 'VIP' : 'Make VIP',
                        style: TextStyle(
                            color:
                                premium ? Colors.yellowAccent : Colors.white)),
                  ),
                ),
              );
            },
          );
        },
      );

  Widget _analyticsTab() => FutureBuilder<Map<String, int>>(
        future: _responsesPerSurvey(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.white));
          }
          final data = snap.data!;
          if (data.isEmpty) return _emptyWidget('No responses yet.');
          final keys = data.keys.toList();
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _glassContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Responses per Survey',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 240,
                    child: BarChart(
                      BarChartData(
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(show: false),
                        titlesData: FlTitlesData(show: false),
                        barGroups: List.generate(keys.length, (i) {
                          final y = (data[keys[i]] ?? 0).toDouble();
                          return BarChartGroupData(x: i, barRods: [
                            BarChartRodData(
                                toY: y,
                                width: 18,
                                color: Colors.cyanAccent,
                                borderRadius: BorderRadius.circular(6))
                          ]);
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

  Widget _notificationsTab() =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _notificationsStream(),
        builder: (context, snap) {
          if (snap.hasError) {
            return _errorWidget('Error loading notifications.');
          }
          if (!snap.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.white));
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) return _emptyWidget('No notifications yet.');
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final n = docs[i].data();
              final title = n['title'] ?? 'Notification';
              final msg = n['message'] ?? '';
              final time = (n['timestamp'] is Timestamp)
                  ? (n['timestamp'] as Timestamp)
                      .toDate()
                      .toString()
                      .split('.')[0]
                  : '';
              return _glassContainer(
                child: ListTile(
                  leading: const Icon(Icons.notifications, color: Colors.white),
                  title: Text(title,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle:
                      Text(msg, style: const TextStyle(color: Colors.white70)),
                  trailing: Text(time,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12)),
                ),
              );
            },
          );
        },
      );

  Widget _settingsTab() => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _glassContainer(
          child: ListTile(
            leading: const Icon(Icons.shield_outlined, color: Colors.white),
            title: const Text('Role',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text(widget.role,
                style: const TextStyle(color: Colors.white70)),
          ),
        ),
      );

  Widget _emptyWidget(String msg) => Center(
        child: _glassContainer(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Text(msg,
                style: const TextStyle(color: Colors.white70, fontSize: 15)),
          ),
        ),
      );

  Widget _errorWidget(String msg) => Center(
        child: _glassContainer(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Text(msg,
                style: const TextStyle(color: Colors.redAccent, fontSize: 15)),
          ),
        ),
      );
}
