import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ViewMyResponsesScreen extends StatefulWidget {
  final String surveyId;

  const ViewMyResponsesScreen({super.key, required this.surveyId});

  @override
  State<ViewMyResponsesScreen> createState() => _ViewMyResponsesScreenState();
}

class _ViewMyResponsesScreenState extends State<ViewMyResponsesScreen> {
  String _filter = 'All';

  // --------------------------------------------------------------------------
  // STREAM USING OPTION-B FIELDS:
  // - timestamp
  // - userId
  // - userName
  // - answers
  // --------------------------------------------------------------------------
  Stream<QuerySnapshot<Map<String, dynamic>>> _responseStream() {
    final fs = FirebaseFirestore.instance;
    Timestamp? start;

    if (_filter == 'Today') {
      final now = DateTime.now();
      start = Timestamp.fromDate(DateTime(now.year, now.month, now.day));
    } else if (_filter == 'This Week') {
      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      start =
          Timestamp.fromDate(DateTime(monday.year, monday.month, monday.day));
    }

    Query<Map<String, dynamic>> q = fs
        .collection('responses')
        .where('surveyId', isEqualTo: widget.surveyId)
        .orderBy('timestamp', descending: true); // ★ FIXED FIELD

    if (start != null) {
      q = q.where('timestamp', isGreaterThanOrEqualTo: start); // ★ FIXED
    }

    return q.snapshots();
  }

  // --------------------------------------------------------------------------
  // UI
  // --------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Survey Responses'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 2,
      ),
      body: Column(
        children: [
          // FILTER BUTTONS
          Padding(
            padding: const EdgeInsets.all(12),
            child: ToggleButtons(
              isSelected: [
                _filter == 'All',
                _filter == 'This Week',
                _filter == 'Today'
              ],
              onPressed: (i) {
                setState(() {
                  _filter = ['All', 'This Week', 'Today'][i];
                });
              },
              borderRadius: BorderRadius.circular(20),
              fillColor: const Color(0xFF6366F1),
              selectedColor: Colors.white,
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text("All"),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text("This Week"),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text("Today"),
                ),
              ],
            ),
          ),

          // RESPONSE LIST
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _responseStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text("Error: ${snapshot.error}"),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Center(child: Text("No responses yet."));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();

                    // ★ EXACT FIELD MAPPING (Option B)
                    final answersRaw = data['answers'];
                    final String userName = data['userName'] ?? "Guest";
                    final ts = data['timestamp'];

                    // FORMAT DATE
                    String date = "Unknown";
                    if (ts is Timestamp) {
                      final dt = ts.toDate();
                      date =
                          "${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
                    }

                    // Normalized answers map
                    Map<String, dynamic> answers = {};
                    if (answersRaw is Map<String, dynamic>) {
                      answers = answersRaw;
                    }

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 3,
                      child: ExpansionTile(
                        title: Text(
                          "Response #${index + 1} - $userName",
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(date),
                        children: answers.entries.map((entry) {
                          return ListTile(
                            title: Text(entry.key),
                            subtitle: Text("Answer: ${entry.value}"),
                          );
                        }).toList(),
                      ),
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
}
