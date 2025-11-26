import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ignore: unused_import
import 'survey_respond_screen.dart'; // reference if you add "View My Response" later

class MyResponseHistoryScreen extends StatelessWidget {
  const MyResponseHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // Handle guest users
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view your responses.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Response History'),
        backgroundColor: const Color(0xFF6366F1),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('responses')
            .where('respondedBy', isEqualTo: user.uid)
            .orderBy('respondedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'You have not responded to any surveys yet.',
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final surveyId = data['surveyId'] ?? '';
              final respondedAt = (data['respondedAt'] as Timestamp?)?.toDate();

              final dateStr = respondedAt != null
                  ? '${respondedAt.day}/${respondedAt.month}/${respondedAt.year}'
                  : 'Unknown Date';

              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 3,
                child: ListTile(
                  title: Text(
                    'Survey ID: $surveyId',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('Responded on $dateStr'),
                  trailing:
                      const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                  onTap: () {
                    // Future enhancement:
                    // Navigate to detailed view of this response
                    // Example:
                    // Navigator.push(
                    //   context,
                    //   MaterialPageRoute(
                    //     builder: (_) => SurveyRespondScreen(
                    //       surveyId: surveyId,
                    //       surveyTitle: 'Response View',
                    //       questions: [], // load questions dynamically if needed
                    //     ),
                    //   ),
                    // );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
