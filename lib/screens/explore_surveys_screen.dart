import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'survey_respond_screen.dart';
import 'my_surveys_screen.dart';
import 'share_survey_dialog.dart';
import '../services/firestore_service.dart';

class ExploreSurveysScreen extends StatefulWidget {
  const ExploreSurveysScreen({super.key});

  @override
  State<ExploreSurveysScreen> createState() => _ExploreSurveysScreenState();
}

class _ExploreSurveysScreenState extends State<ExploreSurveysScreen> {
  final FirestoreService _fs = FirestoreService();

  String _search = '';
  int _filterIndex = 0; // 0 = All, 1 = Active, 2 = Closed

  String? get _filterStatus {
    if (_filterIndex == 1) return "active";
    if (_filterIndex == 2) return "closed";
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    late final Stream<QuerySnapshot<Map<String, dynamic>>> stream;

    if (_filterStatus == null) {
      stream = _fs.streamSurveys();
    } else {
      stream = _fs.streamSurveysByStatus(_filterStatus!);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      appBar: AppBar(
        title: const Text(
          'Explore Surveys',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 3,
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Failed to load surveys:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // ORIGINAL LIST
                var surveys = snapshot.data!.docs;

                // 🔥 FILTER OUT deleted surveys (Soft Delete)
                surveys = surveys
                    .where((doc) =>
                        (doc.data()['status'] ?? '').toString() != 'deleted')
                    .toList();

                // 🔍 Search filter
                if (_search.isNotEmpty) {
                  surveys = surveys.where((doc) {
                    final data = doc.data();
                    final title =
                        (data['title'] ?? '').toString().toLowerCase();
                    final creatorName =
                        (data['creatorName'] ?? '').toString().toLowerCase();
                    final creatorEmail =
                        (data['creatorEmail'] ?? '').toString().toLowerCase();

                    return title.contains(_search) ||
                        creatorName.contains(_search) ||
                        creatorEmail.contains(_search);
                  }).toList();
                }

                if (surveys.isEmpty) return _emptyStateWidget();

                return ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                  itemCount: surveys.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (_, index) {
                    final doc = surveys[index];
                    final data = doc.data();

                    final userIsCreator = currentUser != null &&
                        data['creatorId'] == currentUser.uid;

                    return _surveyCard(
                      context,
                      doc.id,
                      data['title'] ?? "Untitled Survey",
                      data,
                      userIsCreator,
                      data['questions'] ?? [],
                      data['responseCount'] ?? 0,
                      (data['createdAt'] as Timestamp?)?.toDate(),
                      data['status'] ?? 'active',
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // SEARCH + FILTER
  Widget _buildSearchAndFilter() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search surveys by title or creator...',
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (val) =>
                setState(() => _search = val.trim().toLowerCase()),
          ),
          const SizedBox(height: 12),
          Center(
            child: ToggleButtons(
              isSelected: [
                _filterIndex == 0,
                _filterIndex == 1,
                _filterIndex == 2
              ],
              borderRadius: BorderRadius.circular(20),
              selectedColor: Colors.white,
              fillColor: const Color(0xFF6366F1),
              color: Colors.grey[700],
              borderColor: Colors.grey[400],
              selectedBorderColor: const Color(0xFF6366F1),
              onPressed: (i) => setState(() => _filterIndex = i),
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text("All"),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text("Active"),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text("Closed"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyStateWidget() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              "No surveys found",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  // SURVEY CARD UI
  Widget _surveyCard(
    BuildContext context,
    String surveyId,
    String title,
    Map<String, dynamic> data,
    bool userIsCreator,
    List<dynamic> questions,
    int responseCount,
    DateTime? createdAt,
    String status,
  ) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TITLE + STATUS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      )),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: status == "active" ? Colors.green : Colors.grey[600],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text(
              "Created by: ${userIsCreator ? "You" : (data['creatorName'] ?? "Unknown")}"
              " • ${createdAt != null ? _formatDate(createdAt) : "Unknown Date"}",
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                _infoChip(Icons.question_answer_rounded,
                    "${questions.length} questions"),
                const SizedBox(width: 10),
                _infoChip(Icons.people_rounded, "$responseCount responses"),
              ],
            ),

            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: userIsCreator
                  ? [
                      TextButton.icon(
                        icon: const Icon(Icons.folder_open),
                        label: const Text("Manage"),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MySurveysScreen(),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.share),
                        onPressed: () =>
                            _showShareDialog(context, surveyId, title),
                      )
                    ]
                  : [
                      if (status == "active")
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SurveyRespondScreen(
                                  surveyId: surveyId,
                                  surveyTitle: title,
                                  questions: questions,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text("Respond"),
                        )
                      else
                        const Text("Closed",
                            style: TextStyle(color: Colors.grey)),
                      IconButton(
                        icon: const Icon(Icons.share),
                        onPressed: () =>
                            _showShareDialog(context, surveyId, title),
                      )
                    ],
            )
          ],
        ),
      ),
    );
  }

  void _showShareDialog(BuildContext context, String id, String title) {
    showDialog(
      context: context,
      builder: (_) => ShareSurveyDialog(
        surveyId: id,
        surveyTitle: title,
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt).inDays;

    if (diff == 0) return "Today";
    if (diff == 1) return "Yesterday";
    if (diff < 7) return "$diff days ago";

    return "${dt.day}/${dt.month}/${dt.year}";
  }

  Widget _infoChip(IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 18, color: Colors.indigo),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      backgroundColor: Colors.grey[100],
    );
  }
}
