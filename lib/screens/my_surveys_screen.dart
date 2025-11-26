// lib/screens/my_surveys_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';

import 'view_my_responses_screen.dart';
import 'analytics_screen.dart';
import 'survey_creation_screen.dart';
import '../services/firestore_service.dart';

class MySurveysScreen extends StatelessWidget {
  MySurveysScreen({super.key});

  final FirestoreService _fs = FirestoreService();

  Future<void> _toggleSurveyStatus(
      String surveyId, String currentStatus) async {
    final newStatus = currentStatus == 'active' ? 'closed' : 'active';
    await _fs.updateSurveyStatus(surveyId, newStatus);
  }

  // DELETE SURVEY + ALL RESPONSES
  Future<void> _deleteSurvey(BuildContext context, String surveyId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Survey?"),
        content: const Text(
          "This will permanently delete this survey and all of its responses.",
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Delete all responses belonging to this survey
      final responses = await FirebaseFirestore.instance
          .collection('responses')
          .where('surveyId', isEqualTo: surveyId)
          .get();

      final batch = FirebaseFirestore.instance.batch();

      for (var doc in responses.docs) {
        batch.delete(doc.reference);
      }

      final surveyRef =
          FirebaseFirestore.instance.collection('surveys').doc(surveyId);

      batch.delete(surveyRef);

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Survey deleted successfully."),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error deleting survey: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(
        child: Text("Please sign in to manage your surveys."),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Surveys"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 2,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _fs.streamSurveysByCreator(user.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error loading surveys:\n${snapshot.error}",
                textAlign: TextAlign.center,
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final surveys = snapshot.data!.docs;

          if (surveys.isEmpty) {
            return const Center(
              child: Text("You haven't created any surveys yet."),
            );
          }

          final active =
              surveys.where((d) => (d['status'] ?? '') == 'active').toList();
          final closed =
              surveys.where((d) => (d['status'] ?? '') == 'closed').toList();
          final drafts =
              surveys.where((d) => (d['status'] ?? '') == 'draft').toList();

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (active.isNotEmpty) ...[
                _sectionTitle(context, "Active Surveys (${active.length})"),
                ...active.map(
                  (d) => _SurveyCard(
                    data: d,
                    onToggle: _toggleSurveyStatus,
                    onDelete: (id) => _deleteSurvey(context, id),
                  ),
                ),
              ],
              if (closed.isNotEmpty) ...[
                _sectionTitle(context, "Closed Surveys (${closed.length})"),
                ...closed.map(
                  (d) => _SurveyCard(
                    data: d,
                    onToggle: _toggleSurveyStatus,
                    onDelete: (id) => _deleteSurvey(context, id),
                  ),
                ),
              ],
              if (drafts.isNotEmpty) ...[
                _sectionTitle(context, "Drafts (${drafts.length})"),
                ...drafts.map(
                  (d) => _SurveyCard(
                    data: d,
                    onToggle: null,
                    onDelete: (id) => _deleteSurvey(context, id),
                  ),
                ),
              ],
              const SizedBox(height: 100),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SurveyCreationScreen()),
          );
        },
        label: const Text("Create Survey"),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _SurveyCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> data;
  final Future<void> Function(String surveyId, String currentStatus)? onToggle;
  final Function(String surveyId) onDelete;

  const _SurveyCard({
    required this.data,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final survey = data.data();
    final surveyId = data.id;

    final status = survey['status'] ?? 'active';
    final title = survey['title'] ?? 'Untitled Survey';
    final responseCount = survey['responseCount'] ?? 0;
    final createdAt = (survey['createdAt'] as Timestamp?)?.toDate();

    final formattedDate = createdAt != null
        ? "${createdAt.day}/${createdAt.month}/${createdAt.year}"
        : "Unknown date";

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + Delete + Toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                Row(
                  children: [
                    if (onToggle != null)
                      Switch(
                        value: status == 'active',
                        thumbColor: WidgetStateProperty.all(Colors.green),
                        onChanged: (_) async {
                          await onToggle!(surveyId, status);
                        },
                      )
                    else
                      const Chip(label: Text("Draft")),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => onDelete(surveyId),
                    )
                  ],
                )
              ],
            ),

            const SizedBox(height: 6),

            Row(
              children: [
                Chip(
                  label: Text("$responseCount responses"),
                  backgroundColor: Colors.blue[50],
                  labelStyle: const TextStyle(color: Colors.blue),
                ),
                const SizedBox(width: 10),
                Text(formattedDate, style: const TextStyle(color: Colors.grey)),
              ],
            ),

            const SizedBox(height: 10),

            Wrap(
              spacing: 16,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.bar_chart, color: Colors.indigo),
                  label: const Text("Analytics"),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AnalyticsScreen(surveyId: surveyId),
                      ),
                    );
                  },
                ),
                TextButton.icon(
                  icon: const Icon(Icons.people_alt, color: Colors.indigo),
                  label: const Text("Responses"),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ViewMyResponsesScreen(surveyId: surveyId),
                      ),
                    );
                  },
                ),
                TextButton.icon(
                  icon: const Icon(Icons.file_download, color: Colors.indigo),
                  label: const Text("Export Data"),
                  onPressed: () => _exportSurveyData(context, surveyId),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 🔥 UPDATED TO NEW FORMAT B
  Future<void> _exportSurveyData(BuildContext context, String surveyId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('responses')
          .where('surveyId', isEqualTo: surveyId)
          .get();

      if (snapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No responses to export.")),
        );
        return;
      }

      // NEW HEADERS (correct format)
      final headers = [
        "Response ID",
        "User ID",
        "User Name",
        "Answers",
        "Timestamp"
      ];
      final rows = [headers];

      for (var doc in snapshot.docs) {
        final data = doc.data();

        // NEW FORMAT B FIELDS
        final userId = data['userId'] ?? "unknown";
        final userName = data['userName'] ?? "Guest";
        final answers = data['answers'] ?? {};
        final timestamp = (data['timestamp'] is Timestamp)
            ? (data['timestamp'] as Timestamp).toDate().toString()
            : "unknown";

        rows.add([
          doc.id,
          userId,
          userName,
          answers.toString(), // show full map
          timestamp,
        ]);
      }

      final csv = const ListToCsvConverter().convert(rows);

      final dir = await getApplicationDocumentsDirectory();
      final path = "${dir.path}/survey_export_$surveyId.csv";
      final file = File(path);
      await file.writeAsString(csv);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: "Survey Export: $surveyId",
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Data exported successfully!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error exporting data: $e")),
      );
    }
  }
}
