// lib/screens/analytics_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../services/export_service.dart';

// analytics layer
import '../analytics/adapters/firebase_analytics_adapter.dart';
import '../analytics/models/analytics_models.dart';
import '../analytics/engine/insight_engine.dart';
import '../analytics/widgets/question_analytics_card.dart';

class AnalyticsScreen extends StatefulWidget {
  final String? surveyId;
  const AnalyticsScreen({super.key, this.surveyId});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String? _selectedSurveyId;
  bool _isVIP = false;
  String? _currentUserId;

  // ✅ TEAM SUPPORT
  List<String> _myTeams = [];

  @override
  void initState() {
    super.initState();
    _selectedSurveyId = widget.surveyId;
    _initUserAndVip();
    _loadTeams();
  }

  Future<void> _initUserAndVip() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = doc.data();
    final vip = data?['isVIP'] == true || data?['premium'] == true;

    if (!mounted) return;

    setState(() {
      _currentUserId = user.uid;
      _isVIP = vip;
    });
  }

  // ✅ LOAD USER TEAM IDS
  Future<void> _loadTeams() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snap = await FirebaseFirestore.instance.collection('teams').get();

    final myTeams = <String>[];

    for (final doc in snap.docs) {
      final members = (doc['members'] ?? []) as List;
      for (final m in members) {
        if (m['uid'] == user.uid) myTeams.add(doc.id);
      }
    }

    if (!mounted) return;
    setState(() => _myTeams = myTeams);
  }

  // ---------------- EXPORT ----------------

  Future<void> _exportAsCSV() async {
    final csv = await ExportService.generateCSV();
    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/survey_export.csv");
    await file.writeAsString(csv);
    await Share.shareXFiles([XFile(file.path)],
        text: "Survey Analytics CSV Export");
  }

  Future<void> _exportAsPDF() async {
    final pdf = await ExportService.generatePDF();
    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/survey_analytics.pdf");
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)],
        text: "Survey Analytics PDF Export");
  }

  // ---------------- MAIN UI ----------------

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Survey Analytics"),
        actions: _isVIP
            ? [
                IconButton(
                    icon: const Icon(Icons.table_chart),
                    onPressed: _exportAsCSV),
                IconButton(
                    icon: const Icon(Icons.picture_as_pdf),
                    onPressed: _exportAsPDF),
              ]
            : null,
      ),
      backgroundColor: const Color(0xFFF6F8FB),
      body: _buildBody(),
    );
  }
  // Add this method inside _AnalyticsScreenState, alongside other widget methods:

  Widget _buildSurveyDropdown(List surveys) {
    return DropdownButtonFormField<String>(
      value: _selectedSurveyId,
      items: surveys
          .map<DropdownMenuItem<String>>(
            (s) => DropdownMenuItem<String>(
              value: s['id'] as String,
              child: Text(s['title'] as String),
            ),
          )
          .toList(),
      onChanged: (v) => setState(() => _selectedSurveyId = v),
      decoration: const InputDecoration(
        labelText: "Select Survey",
        filled: true,
      ),
    );
  }

  Widget _buildBody() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection("surveys").snapshots(),
      builder: (context, surveySnap) {
        if (!surveySnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // ✅ FILTER PERSONAL + TEAM SURVEYS
        final surveyDocs = surveySnap.data!.docs.where((d) {
          final data = d.data();
          final creatorId = data['creatorId'];
          final teamId = data['teamId'];

          if (creatorId == _currentUserId) return true;
          if (teamId != null && _myTeams.contains(teamId)) return true;

          return false;
        }).toList();

        if (surveyDocs.isEmpty) {
          return const Center(child: Text("No surveys found"));
        }

        final surveys = surveyDocs
            .map((d) => {'id': d.id, 'title': d.data()['title'] ?? 'Untitled'})
            .toList();

        _selectedSurveyId ??= surveys.first['id'] as String;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection("responses")
              .orderBy("timestamp", descending: true)
              .snapshots(),
          builder: (context, responseSnap) {
            if (!responseSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final responses = responseSnap.data!.docs
                .map((d) => _normalizeResponseDoc(d.data()))
                .where((r) =>
                    r['surveyId'] != null &&
                    surveys.any((s) => s['id'] == r['surveyId']))
                .toList();

            final primarySurvey =
                surveyDocs.firstWhere((d) => d.id == _selectedSurveyId);

            final primaryResponses = responses
                .where((r) => r['surveyId'] == _selectedSurveyId)
                .toList();

            final surveyA = FirebaseAnalyticsAdapter.buildSurveyAnalytics(
              surveyDoc: {...primarySurvey.data(), 'id': primarySurvey.id},
              responses: primaryResponses,
            );

            final insights = buildSurveyInsights(surveyA);
            final completionPercent =
                _computeCompletionPercent(primaryResponses, surveyA);

            final Map<String, int> trend = {};
            for (final r in primaryResponses) {
              final d = r['timestamp'] as DateTime?;
              if (d != null) {
                final key =
                    "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
                trend[key] = (trend[key] ?? 0) + 1;
              }
            }

            final avgRating = _computeAverageRating(surveyA);
            final moodLabel = _computeMoodLabel(avgRating);
            final anomalies = _detectAnomalies(trend);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(surveyA),
                  const SizedBox(height: 12),
                  _buildKPIs(
                    surveyA,
                    insights,
                    completionPercent,
                    avgRating,
                    moodLabel,
                  ),
                  const SizedBox(height: 16),
                  _buildSurveyDropdown(surveys),
                  const SizedBox(height: 16),
                  _buildTrendChart(trend),
                  const SizedBox(height: 16),
                  _buildRatingDistributionHistogram(surveyA),
                  const SizedBox(height: 16),
                  _buildHeatmap(surveyA),
                  const SizedBox(height: 16),
                  _buildCompletionBlock(surveyA, completionPercent),
                  const SizedBox(height: 16),
                  _buildAnomalyCard(anomalies),
                  const SizedBox(height: 16),
                  _buildInsightBox(insights),
                  const SizedBox(height: 20),
                  _buildQuestionSection(surveyA),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ======================= YOUR ORIGINAL CODE BELOW =======================
  // You can keep your original methods here unchanged.
  Widget _buildHeader(SurveyAnalytics a) {
    final created =
        "${a.createdAt.day}/${a.createdAt.month}/${a.createdAt.year}";
    final last = a.lastResponseAt == null
        ? "No responses yet"
        : "${a.lastResponseAt!.day}/${a.lastResponseAt!.month}/${a.lastResponseAt!.year}";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          a.title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          a.isLive ? "🟢 Live survey" : "🔴 Closed survey",
          style: const TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          "Created $created • Last response: $last",
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildKPIs(
    SurveyAnalytics s,
    SurveyInsights i,
    double completionPercent,
    double? avgRating,
    String moodLabel,
  ) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _kpiCard("Responses", "${s.totalResponses}", Icons.people),
        _kpiCard(
          "Completion",
          "${completionPercent.toStringAsFixed(1)}%",
          Icons.check_circle,
        ),
        _kpiCard(
          "Avg Rating",
          avgRating != null ? avgRating.toStringAsFixed(1) : "—",
          Icons.star_rate_rounded,
        ),
        _kpiCard("Mood", moodLabel, Icons.emoji_emotions),
      ],
    );
  }

  static Widget _kpiCard(String title, String value, IconData icon) {
    return SizedBox(
      width: 170,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icon),
              const SizedBox(height: 6),
              Text(
                value,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(title),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrendChart(Map<String, int> data) {
    if (data.isEmpty) {
      return _buildEmptyChartCard(
        "Response Trend (Cumulative)",
        "No responses yet for this survey.",
      );
    }

    final keys = data.keys.toList()..sort();
    final limitedKeys =
        keys.length > 14 ? keys.sublist(keys.length - 14) : keys;

    final List<FlSpot> spots = [];
    int running = 0;
    for (var i = 0; i < limitedKeys.length; i++) {
      final key = limitedKeys[i];
      running += data[key] ?? 0;
      spots.add(FlSpot(i.toDouble(), running.toDouble()));
    }

    final totalResponses = running;
    String bestDayLabel = "";
    int bestDayCount = 0;

    for (final key in limitedKeys) {
      final value = data[key] ?? 0;
      if (value > bestDayCount) {
        bestDayCount = value;
        bestDayLabel = key;
      }
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Response Trend (Cumulative)",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      barWidth: 3,
                      dotData: FlDotData(show: true),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles:
                          SideTitles(showTitles: true, reservedSize: 32),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= limitedKeys.length) {
                            return const SizedBox.shrink();
                          }
                          final dateKey = limitedKeys[index]; // YYYY-MM-DD
                          final label = dateKey.substring(5); // MM-DD
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(
                              label,
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Total responses: $totalResponses"
              "${bestDayLabel.isNotEmpty ? " • Best day: $bestDayLabel ($bestDayCount responses)" : ""}",
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingDistributionHistogram(SurveyAnalytics survey) {
    final ratingQs =
        survey.questions.where((q) => q.type == QuestionType.rating).toList();

    if (ratingQs.isEmpty) {
      return _buildEmptyChartCard(
        "Rating Distribution",
        "No rating questions in this survey.",
      );
    }

    final q = ratingQs.first;

    final hasData = q.counts.any((c) => c > 0);
    if (!hasData) {
      return _buildEmptyChartCard(
        "Rating Distribution",
        "No rating responses collected yet.",
      );
    }

    // Build bar groups for each rating option
    final barGroups = <BarChartGroupData>[];
    for (int i = 0; i < q.options.length && i < q.counts.length; i++) {
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: q.counts[i].toDouble(),
              width: 14,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Rating Distribution",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(show: false),
                  barGroups: barGroups,
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= q.options.length) {
                            return const SizedBox.shrink();
                          }
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(q.options[index]),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeatmap(SurveyAnalytics survey) {
    // Skip text questions and ones with no options/counts to avoid empty rows
    final rows = survey.questions
        .where((q) =>
            q.type != QuestionType.text &&
            q.counts.isNotEmpty &&
            q.maxCount > 0)
        .take(5)
        .toList();

    if (rows.isEmpty) {
      return _buildEmptyChartCard(
        "Response Heatmap",
        "No multiple-choice or rating responses yet.",
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Response Heatmap",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...rows.map((q) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    q.question,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: List.generate(q.counts.length, (i) {
                      final c = q.counts[i];
                      final intensity = q.maxCount == 0
                          ? 0.0
                          : (c.toDouble() / q.maxCount.toDouble());

                      // No color if count is 0, stronger color for higher counts
                      final baseOpacity = c == 0 ? 0.05 : 0.2;
                      final opacity =
                          (baseOpacity + intensity * 0.8).clamp(0.05, 1.0);

                      return Expanded(
                        child: Container(
                          height: 16,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: Colors.indigo.withOpacity(opacity),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 10),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionBlock(
      SurveyAnalytics survey, double completionPercent) {
    if (survey.totalResponses == 0) {
      return _buildEmptyChartCard(
        "Completion Flow",
        "No responses yet. Once responses come in, each one will fully complete the survey because all questions are mandatory.",
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Completion Flow",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              "All questions in this survey are mandatory.\nEvery submitted response has 100% question completion.",
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(
                  child: LinearProgressIndicator(value: 1.0),
                ),
                const SizedBox(width: 8),
                Text(
                  "${completionPercent.toStringAsFixed(1)}%",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              "Total responses: ${survey.totalResponses}",
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _detectAnomalies(Map<String, int> dataMap) {
    if (dataMap.length < 3) return [];

    final values = dataMap.values.toList();
    final keys = dataMap.keys.toList()..sort();

    int sum = 0;
    for (final v in values) {
      sum += v;
    }
    final mean = sum / values.length;

    if (mean == 0) return [];

    final anomalies = <Map<String, dynamic>>[];

    for (final key in keys) {
      final v = dataMap[key] ?? 0;
      final dv = v.toDouble();

      // Heuristic: strong spikes & drops relative to mean
      if (dv >= mean * 2 && dv >= mean + 3) {
        anomalies.add({
          'date': key,
          'value': v,
          'type': 'Spike',
        });
      } else if (dv <= mean * 0.3 && dv <= mean - 2) {
        anomalies.add({
          'date': key,
          'value': v,
          'type': 'Drop',
        });
      }
    }

    return anomalies;
  }

  Widget _buildAnomalyCard(List<Map<String, dynamic>> anomalies) {
    return Card(
      color: Colors.red.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: anomalies.isEmpty
            ? const Text(
                "No unusual spikes or drops detected in responses.",
                style: TextStyle(fontSize: 13),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Anomaly Detection",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...anomalies.take(4).map(
                        (a) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            "${a['date']} — ${a['type']} (${a['value']} responses)",
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                  if (anomalies.length > 4)
                    Text(
                      "+ ${anomalies.length - 4} more anomalies...",
                      style: const TextStyle(
                          fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildInsightBox(SurveyInsights i) {
    return Card(
      color: Colors.indigo.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Executive Summary",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              i.executiveSummary,
              style: const TextStyle(fontSize: 13),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionSection(SurveyAnalytics s) {
    if (s.questions.isEmpty) {
      return const Text(
        "No question-wise analytics yet. Once responses arrive, details will appear here.",
        style: TextStyle(fontSize: 13),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Question-wise Analytics",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        ...s.questions.map(
          (q) => QuestionAnalyticsCard(question: q),
        ),
      ],
    );
  }

  Map<String, dynamic> _normalizeResponseDoc(Map<String, dynamic> raw) {
    final surveyId = raw['surveyId'] ?? raw['surveyID'] ?? raw['survey_id'];

    final tsRaw = raw['timestamp'] ?? raw['respondedAt'] ?? raw['createdAt'];
    DateTime? ts;
    if (tsRaw is Timestamp) {
      ts = tsRaw.toDate();
    } else if (tsRaw is DateTime) {
      ts = tsRaw;
    }

    final rawAnswers =
        raw['answers'] ?? raw['responses'] ?? <String, dynamic>{};

    final Map<String, dynamic> normalizedAnswers = {};
    if (rawAnswers is Map<String, dynamic>) {
      rawAnswers.forEach((key, value) {
        final normalizedKey =
            key.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');

        normalizedAnswers[normalizedKey] = {
          'question': key,
          'value': value,
        };
      });
    }

    return {
      'surveyId': surveyId,
      'timestamp': ts,
      'answers': rawAnswers,
      'normalizedAnswers': normalizedAnswers,
    };
  }

  double _computeCompletionPercent(
      List<Map<String, dynamic>> responses, SurveyAnalytics survey) {
    final totalQuestions = survey.questions.length;
    if (totalQuestions == 0 || responses.isEmpty) return 0;

    int answeredCount = 0;
    final possible = responses.length * totalQuestions;

    for (final r in responses) {
      final answers = (r['normalizedAnswers'] ?? r['answers']) as Map?;
      if (answers != null) {
        answeredCount += answers.length;
      }
    }

    if (possible == 0) return 0;
    return (answeredCount.toDouble() / possible.toDouble()) * 100.0;
  }

  double? _computeAverageRating(SurveyAnalytics survey) {
    double sum = 0;
    int count = 0;

    for (final q in survey.questions) {
      if (q.type == QuestionType.rating) {
        for (int i = 0; i < q.options.length && i < q.counts.length; i++) {
          final label = q.options[i];
          final numeric = double.tryParse(label) ?? (i + 1).toDouble();
          final c = q.counts[i];
          sum += numeric * c;
          count += c;
        }
      }
    }

    if (count == 0) return null;
    return sum / count;
  }

  String _computeMoodLabel(double? avgRating) {
    if (avgRating == null) return "—";

    if (avgRating >= 4.2) return "Positive";
    if (avgRating >= 3.0) return "Mixed";
    return "Negative";
  }

  Widget _buildEmptyChartCard(String title, String message) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
