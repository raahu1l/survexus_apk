// lib/screens/analytics_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../services/export_service.dart';

/// AnalyticsScreen — fully fallback-compatible.
///
/// Supports both old response format:
///   - surveyId
///   - respondedBy / respondedByName
///   - responses
///   - respondedAt (Timestamp)
///
/// and new response format:
///   - surveyId
///   - userId / userName
///   - answers
///   - timestamp (Timestamp)
///
/// Visuals:
///  - clean light UI
///  - your-surveys-only (creatorId == current user)
///  - global bar chart (# responses per survey)
///  - trend line (responses by day)
///  - per-survey visualizer (bar / line / pie)
class AnalyticsScreen extends StatefulWidget {
  final String? surveyId;
  const AnalyticsScreen({super.key, this.surveyId});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String? _selectedSurveyId;
  String _selectedChart = 'Bar Chart';
  final List<String> chartOptions = ['Bar Chart', 'Line Chart', 'Pie Chart'];
  bool _isVIP = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _selectedSurveyId = widget.surveyId;
    _initUserAndVip();
  }

  Future<void> _initUserAndVip() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _currentUserId = user.uid;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = doc.data();
    final vip = data?['isVIP'] == true || data?['premium'] == true;
    if (mounted) {
      setState(() {
        _isVIP = vip;
      });
    }
  }

  Future<void> _exportAsCSV() async {
    try {
      final csv = await ExportService.generateCSV();
      final dir = await getApplicationDocumentsDirectory();
      final file = File("${dir.path}/survey_export.csv");
      await file.writeAsString(csv);
      await Share.shareXFiles([XFile(file.path)],
          text: "Survey Analytics CSV Export");
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Export failed: $e")));
    }
  }

  Future<void> _exportAsPDF() async {
    try {
      final pdf = await ExportService.generatePDF();
      final dir = await getApplicationDocumentsDirectory();
      final file = File("${dir.path}/survey_analytics.pdf");
      await file.writeAsBytes(await pdf.save());
      await Share.shareXFiles([XFile(file.path)],
          text: "Survey Analytics PDF Export");
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Export failed: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    // require sign-in
    if (_currentUserId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Survey Analytics'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 2,
        ),
        body: const Center(child: Text('Please sign in to view analytics.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Survey Analytics'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 2,
        actions: _isVIP
            ? [
                IconButton(
                  tooltip: "Export CSV",
                  icon: const Icon(Icons.table_chart_rounded,
                      color: Colors.indigo),
                  onPressed: _exportAsCSV,
                ),
                IconButton(
                  tooltip: "Export PDF",
                  icon: const Icon(Icons.picture_as_pdf_rounded,
                      color: Colors.red),
                  onPressed: _exportAsPDF,
                ),
              ]
            : null,
      ),
      backgroundColor: const Color(0xFFF6F8FB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            // Only stream surveys created by the current user
            stream: FirebaseFirestore.instance
                .collection('surveys')
                .where('creatorId', isEqualTo: _currentUserId)
                .snapshots(),
            builder: (context, surveySnap) {
              if (surveySnap.hasError) {
                return Center(
                    child: Text('Error loading surveys: ${surveySnap.error}'));
              }
              if (!surveySnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final surveyDocs = surveySnap.data!.docs;
              if (surveyDocs.isEmpty) {
                return const Center(
                  child: Text(
                      'You have no surveys yet. Create a survey to view analytics.'),
                );
              }

              // Build a list of surveys owned by this user
              final surveys = surveyDocs
                  .map((d) => {
                        'id': d.id,
                        'title':
                            (d.data()['title'] ?? 'Untitled Survey') as String
                      })
                  .toList();

              // Ensure selected survey belongs to user
              if (_selectedSurveyId == null ||
                  !surveys.any((s) => s['id'] == _selectedSurveyId)) {
                _selectedSurveyId = surveys.first['id'];
              }

              // Stream responses (we will normalize each record for fallback compatibility)
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('responses')
                    // We can limit reads by only responses that match user's surveys using where + in,
                    // but Firestore limits 'in' to 10 items. We'll stream all responses and filter locally
                    // (acceptable for small datasets; if many surveys exist consider server-side aggregation).
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, respSnap) {
                  if (respSnap.hasError) {
                    return Center(
                        child:
                            Text('Error loading responses: ${respSnap.error}'));
                  }
                  if (!respSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final rawResponses = respSnap.data!.docs
                      .map((d) => _normalizeResponseDoc(d.data()))
                      .toList();

                  // Filter only responses that belong to this user's surveys
                  final mySurveyIds = surveys.map((s) => s['id']!).toSet();
                  final myResponses = rawResponses
                      .where((r) =>
                          r['surveyId'] != null &&
                          mySurveyIds.contains(r['surveyId']))
                      .toList();

                  // Aggregate counts per survey and by date
                  final Map<String, int> responseCountBySurvey = {};
                  final Map<String, int> responseCountByDate = {};

                  for (var r in myResponses) {
                    final sid = r['surveyId']?.toString() ?? 'unknown';
                    responseCountBySurvey[sid] =
                        (responseCountBySurvey[sid] ?? 0) + 1;

                    final dt = r['timestamp'] as DateTime?;
                    if (dt != null) {
                      final key =
                          "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
                      responseCountByDate[key] =
                          (responseCountByDate[key] ?? 0) + 1;
                    }
                  }

                  // UI: build dashboard showing only user's surveys
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),
                        const Text(
                          '📊 Your Surveys — Analytics',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.left,
                        ),
                        const SizedBox(height: 12),

                        // Global summary row
                        Row(
                          children: [
                            Expanded(
                                child:
                                    _smallCard('Surveys', '${surveys.length}')),
                            const SizedBox(width: 8),
                            Expanded(
                                child: _smallCard(
                                    'Responses', '${myResponses.length}')),
                            const SizedBox(width: 8),
                            Expanded(
                                child: _smallCard(
                                    'Avg / Survey',
                                    surveys.isNotEmpty
                                        ? (myResponses.length / surveys.length)
                                            .toStringAsFixed(1)
                                        : '0')),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Global bar chart (responses per survey)
                        Card(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Responses per Survey',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 220,
                                  child: responseCountBySurvey.isEmpty
                                      ? const Center(
                                          child: Text('No responses yet.'))
                                      : _buildGlobalBarChart(
                                          surveys, responseCountBySurvey),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Trend chart (responses by date)
                        Card(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Response Trend',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 200,
                                  child: responseCountByDate.isEmpty
                                      ? const Center(
                                          child: Text('No trend data yet.'))
                                      : _buildTrendLineChart(
                                          responseCountByDate),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Survey selector & per-survey charts
                        Card(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text('Per-Survey Visualizer',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  value: _selectedSurveyId,
                                  items: surveys
                                      .map((s) => DropdownMenuItem<String>(
                                            value: s['id'] as String,
                                            child: Text(s['title'] as String),
                                          ))
                                      .toList(),
                                  onChanged: (val) {
                                    setState(() {
                                      _selectedSurveyId = val;
                                    });
                                  },
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.grey[100],
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide.none),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                Wrap(
                                  spacing: 8,
                                  children: chartOptions.map((opt) {
                                    final isSel = _selectedChart == opt;
                                    return ChoiceChip(
                                      label: Text(opt),
                                      selected: isSel,
                                      onSelected: (_) {
                                        setState(() => _selectedChart = opt);
                                      },
                                    );
                                  }).toList(),
                                ),

                                const SizedBox(height: 14),

                                // Per-survey chart
                                if (_selectedSurveyId != null)
                                  FutureBuilder<
                                      QuerySnapshot<Map<String, dynamic>>>(
                                    future: FirebaseFirestore.instance
                                        .collection('responses')
                                        .where('surveyId',
                                            isEqualTo: _selectedSurveyId)
                                        .get(),
                                    builder: (context, snap) {
                                      if (snap.hasError) {
                                        return Text('Error: ${snap.error}');
                                      }
                                      if (!snap.hasData) {
                                        return const SizedBox(
                                            height: 180,
                                            child: Center(
                                                child:
                                                    CircularProgressIndicator()));
                                      }
                                      final docs = snap.data!.docs;
                                      if (docs.isEmpty) {
                                        return const SizedBox(
                                            height: 180,
                                            child: Center(
                                                child: Text(
                                                    'No responses for this survey yet.')));
                                      }

                                      // Normalize docs
                                      final normalized = docs
                                          .map((d) => _normalizeResponseDoc(
                                              Map<String, dynamic>.from(
                                                  d.data())))
                                          .toList();

                                      // Total responses for this survey
                                      final count =
                                          normalized.length.toDouble();

                                      switch (_selectedChart) {
                                        case 'Line Chart':
                                          return SizedBox(
                                              height: 220,
                                              child:
                                                  _perSurveyLine(normalized));
                                        case 'Pie Chart':
                                          return SizedBox(
                                              height: 220,
                                              child: _perSurveyPieFromAnswers(
                                                  normalized));
                                        default:
                                          return SizedBox(
                                              height: 220,
                                              child: _perSurveyBar(count));
                                      }
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  /// Normalize a response document map into a consistent structure:
  /// {
  ///   'surveyId': String?,
  ///   'userId': String?,
  ///   'userName': String?,
  ///   'answers': Map<String, dynamic>?,
  ///   'timestamp': DateTime?
  /// }
  Map<String, dynamic> _normalizeResponseDoc(Map<String, dynamic> raw) {
    // Survey id (same in both)
    final surveyId = raw['surveyId']?.toString();

    // userId fallback: userId OR respondedBy OR null
    final userId = raw['userId'] ?? raw['respondedBy'] ?? raw['createdBy'];

    // userName fallback: userName OR respondedByName OR userName OR Guest
    final userName = raw['userName'] ??
        raw['respondedByName'] ??
        raw['respondedBy'] ??
        raw['userName'] ??
        (userId == null ? 'Guest' : userId.toString());

    // answers fallback: answers OR responses OR answersMap
    final answersRaw = raw['answers'] ?? raw['responses'] ?? raw['answersMap'];

    Map<String, dynamic>? answers;
    if (answersRaw is Map<String, dynamic>) {
      answers = answersRaw;
    } else if (answersRaw is Map) {
      answers = Map<String, dynamic>.from(answersRaw);
    } else {
      answers = null;
    }

    // timestamp fallback: timestamp OR respondedAt OR createdAt OR null
    DateTime? ts;
    final tRaw = raw['timestamp'] ?? raw['respondedAt'] ?? raw['createdAt'];
    if (tRaw is Timestamp) {
      ts = tRaw.toDate();
    } else if (tRaw is DateTime) {
      ts = tRaw;
    } else {
      ts = null;
    }

    return {
      'surveyId': surveyId,
      'userId': userId?.toString(),
      'userName': userName?.toString(),
      'answers': answers,
      'timestamp': ts,
    };
  }

  // ------------------------- CHART BUILDERS -------------------------

  Widget _buildGlobalBarChart(
      List<Map<String, dynamic>> surveys, Map<String, int> counts) {
    // Map surveys to indices
    final groups = List.generate(surveys.length, (i) {
      final sid = surveys[i]['id'] as String;
      final y = (counts[sid] ?? 0).toDouble();
      return BarChartGroupData(x: i, barRods: [
        BarChartRodData(
          fromY: 0,
          toY: y,
          width: 20,
          borderRadius: BorderRadius.circular(6),
          color: i.isEven ? Colors.indigo : Colors.blueAccent,
        )
      ]);
    });

    return BarChart(BarChartData(
      alignment: BarChartAlignment.spaceAround,
      barGroups: groups,
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(showTitles: true, reservedSize: 40),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              final idx = value.toInt();
              if (idx < 0 || idx >= surveys.length) return const SizedBox();
              final label = surveys[idx]['title'] as String;
              return SideTitleWidget(
                axisSide: meta.axisSide,
                child: SizedBox(
                  width: 80,
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              );
            },
            reservedSize: 70,
          ),
        ),
      ),
      gridData: FlGridData(show: true),
      borderData: FlBorderData(show: false),
    ));
  }

  Widget _buildTrendLineChart(Map<String, int> dataMap) {
    final keys = dataMap.keys.toList()..sort();
    final spots = <FlSpot>[];
    for (var i = 0; i < keys.length; i++) {
      final k = keys[i];
      final y = dataMap[k]!.toDouble();
      spots.add(FlSpot(i.toDouble(), y));
    }

    if (spots.isEmpty) {
      return const Center(child: Text('No trend data yet.'));
    }

    return LineChart(
      LineChartData(
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
          bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, meta) {
                    final idx = v.toInt();
                    if (idx < 0 || idx >= keys.length) return const SizedBox();
                    final label = keys[idx];
                    return SideTitleWidget(
                        axisSide: meta.axisSide,
                        child:
                            Text(label, style: const TextStyle(fontSize: 10)));
                  },
                  reservedSize: 60)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.deepPurple,
            barWidth: 3,
            dotData: FlDotData(show: true),
          ),
        ],
        gridData: FlGridData(show: true),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  Widget _smallCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _perSurveyPieFromAnswers(List<Map<String, dynamic>> normalized) {
    // Attempt to create a pie chart from the first question's distribution
    // Fallback: show registered vs guest distribution
    Map<String, int> buckets = {};

    // Try first to find MCQ-like answers by inspecting first response answers map
    Map<String, dynamic>? firstAnswers;
    for (var r in normalized) {
      if (r['answers'] is Map<String, dynamic>) {
        firstAnswers = r['answers'] as Map<String, dynamic>;
        break;
      }
    }

    if (firstAnswers != null && firstAnswers.isNotEmpty) {
      // take the first question key
      final firstKey = firstAnswers.keys.first;
      for (var r in normalized) {
        final ans =
            r['answers'] is Map ? (r['answers'] as Map)[firstKey] : null;
        final label = (ans?.toString() ?? 'No answer');
        buckets[label] = (buckets[label] ?? 0) + 1;
      }
    } else {
      // fallback to guest vs registered
      for (var r in normalized) {
        final name = r['userName']?.toString().toLowerCase() ?? 'guest';
        final bucket = (name == 'guest' || name.contains('guest'))
            ? 'Guest'
            : 'Registered';
        buckets[bucket] = (buckets[bucket] ?? 0) + 1;
      }
    }

    final total = buckets.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) {
      return const Center(child: Text('No data for pie chart'));
    }

    final sections = buckets.entries.map((e) {
      final v = e.value.toDouble();
      final percent = '${((v / total) * 100).toStringAsFixed(0)}%';
      return PieChartSectionData(
        value: v,
        title: '${e.key} ($percent)',
        radius: 60,
        titleStyle: const TextStyle(color: Colors.white, fontSize: 12),
      );
    }).toList();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
          padding: const EdgeInsets.all(12),
          child: PieChart(PieChartData(sections: sections))),
    );
  }

  Widget _perSurveyLine(List<Map<String, dynamic>> normalized) {
    final Map<String, int> byDate = {};
    for (var r in normalized) {
      final dt = r['timestamp'] as DateTime?;
      if (dt != null) {
        final key =
            "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
        byDate[key] = (byDate[key] ?? 0) + 1;
      }
    }
    final keys = byDate.keys.toList()..sort();
    final spots = <FlSpot>[];
    for (var i = 0; i < keys.length; i++) {
      spots.add(FlSpot(i.toDouble(), byDate[keys[i]]!.toDouble()));
    }
    if (spots.isEmpty) return const Center(child: Text('No trend'));

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
          padding: const EdgeInsets.all(8),
          child: LineChart(LineChartData(
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, meta) {
                    final idx = v.toInt();
                    if (idx < 0 || idx >= keys.length) return const SizedBox();
                    final label = keys[idx];
                    return SideTitleWidget(
                        axisSide: meta.axisSide,
                        child:
                            Text(label, style: const TextStyle(fontSize: 10)));
                  },
                  reservedSize: 60,
                ),
              ),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
            ),
            lineBarsData: [
              LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: Colors.indigo,
                  barWidth: 3,
                  dotData: FlDotData(show: true))
            ],
            gridData: FlGridData(show: true),
            borderData: FlBorderData(show: false),
          ))),
    );
  }

  Widget _perSurveyBar(double val) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: BarChart(BarChartData(
            barGroups: [
              BarChartGroupData(x: 0, barRods: [
                BarChartRodData(toY: val, width: 36, color: Colors.blueAccent)
              ])
            ],
            titlesData: FlTitlesData(
                show: true,
                topTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false))))),
      ),
    );
  }
}
