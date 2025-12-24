import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fl_chart/fl_chart.dart';

import '../services/export_service.dart';

class AnalyticsScreen extends StatefulWidget {
  final String? surveyId;
  const AnalyticsScreen({super.key, this.surveyId});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  String? _userId;
  String? _selectedSurveyId;
  bool _isVIP = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..forward();
    _initUser();
    _selectedSurveyId = widget.surveyId;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!mounted) return;
    setState(() {
      _userId = user.uid;
      _isVIP = userDoc.data()?['isVIP'] == true ||
          userDoc.data()?['premium'] == true;
    });
  }

  Future<void> _exportCSV() async {
    final csv = await ExportService.generateCSV();
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/survey_analytics. csv');
    await file.writeAsString(csv);
    await Share.shareXFiles([XFile(file.path)]);
  }

  Future<void> _exportPDF() async {
    final pdf = await ExportService.generatePDF();
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/survey_analytics.pdf');
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)]);
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        title: const Text('Survey Intelligence',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: _isVIP
            ? [
                IconButton(
                    icon: const Icon(Icons.table_chart), onPressed: _exportCSV),
                IconButton(
                    icon: const Icon(Icons.picture_as_pdf),
                    onPressed: _exportPDF),
              ]
            : null,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('surveys')
            .where('creatorId', isEqualTo: _userId)
            .snapshots(),
        builder: (context, surveySnap) {
          if (!surveySnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final surveys = surveySnap.data!.docs;
          if (surveys.isEmpty) {
            return const Center(
                child: Text('No surveys yet',
                    style: TextStyle(color: Colors.white70)));
          }

          _selectedSurveyId ??= surveys.first.id;
          final surveyDoc =
              surveys.firstWhere((s) => s.id == _selectedSurveyId).data();

          final bool isActive = surveyDoc['status'] != 'closed';
          final List<Map<String, dynamic>> questions =
              List<Map<String, dynamic>>.from(surveyDoc['questions']);

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('responses')
                .where('surveyId', isEqualTo: _selectedSurveyId)
                .snapshots(),
            builder: (context, respSnap) {
              if (!respSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final responses = respSnap.data!.docs.map((d) {
                final data = d.data();
                return {
                  'answers': Map<String, dynamic>.from(data['answers'] ?? {}),
                  'ts': (data['timestamp'] as Timestamp?)?.toDate() ??
                      DateTime.now(),
                };
              }).toList();

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusAndSurvey(surveys, isActive),
                    const SizedBox(height: 20),
                    _sectionTitle('🎯 Critical Metrics'),
                    _buildCriticalMetrics(responses, questions),
                    const SizedBox(height: 24),
                    _sectionTitle('📈 Response Arrival Momentum'),
                    _buildResponseMomentum(responses),
                    const SizedBox(height: 24),
                    _sectionTitle('⏱ Response Time Distribution'),
                    _buildResponseTimeCluster(responses),
                    const SizedBox(height: 24),
                    _sectionTitle('📊 Response Consistency'),
                    _buildResponseConsistency(responses),
                    const SizedBox(height: 24),
                    _buildCriticalAlerts(responses, questions),
                    const SizedBox(height: 24),
                    _sectionTitle('🔍 Question-wise Analysis'),
                    ...questions
                        .map((q) => _buildDetailedQuestion(q, responses)),
                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatusAndSurvey(List surveys, bool isActive) {
    return Row(
      children: [
        Expanded(
          child: _glassCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Survey Status',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (isActive ? Colors.greenAccent : Colors.redAccent)
                        .withAlpha(220),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isActive ? '🟢 LIVE' : '🔴 CLOSED',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _glassCard(
            child: DropdownButtonFormField<String>(
              dropdownColor: const Color(0xFF0A0E27),
              value: _selectedSurveyId,
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
              ),
              items: surveys
                  .map<DropdownMenuItem<String>>(
                    (e) => DropdownMenuItem(
                      value: e.id,
                      child: Text(
                        e.data()['title'] ?? 'Survey',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedSurveyId = v);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCriticalMetrics(
      List<Map<String, dynamic>> responses, List questions) {
    if (responses.isEmpty) {
      return _glassCard(
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: Text('Gathering data...  Check back soon',
                style: TextStyle(color: Colors.white54)),
          ),
        ),
      );
    }

    int totalAnswered = 0;
    for (final r in responses) {
      totalAnswered += (r['answers'] as Map).length;
    }
    final completeness =
        ((totalAnswered / (responses.length * questions.length)) * 100).toInt();

    int promoters = 0, detractors = 0, ratingCount = 0;
    for (final r in responses) {
      for (final q in questions) {
        if (q['type'] == 'rating') {
          final ans = r['answers'][q['question']];
          if (ans != null) {
            ratingCount++;
            final max = q['ratingMax'] ?? 5;
            if (ans >= max * 0.8) {
              promoters++;
            } else if (ans < max * 0.5) {
              detractors++;
            }
          }
        }
      }
    }
    final npsIndex = ratingCount == 0
        ? 0
        : (((promoters - detractors) / ratingCount) * 100).toInt();

    String velocity = '0/h';
    if (responses.length > 1) {
      final timestamps = responses.map((r) => r['ts'] as DateTime).toList()
        ..sort();
      final hours =
          timestamps.last.difference(timestamps.first).inHours.toDouble();
      if (hours > 0) {
        velocity = '${(responses.length / hours).toStringAsFixed(1)}/h';
      }
    }

    return Row(
      children: [
        _buildMetricCard('Quality', '$completeness%', '✨',
            completeness >= 80 ? Colors.greenAccent : Colors.orangeAccent),
        const SizedBox(width: 10),
        _buildMetricCard('NPS', '$npsIndex', '📈', _getNpsColor(npsIndex)),
        const SizedBox(width: 10),
        _buildMetricCard('Speed', velocity, '⚡', Colors.cyanAccent),
        const SizedBox(width: 10),
        _buildMetricCard(
            'Count', '${responses.length}', '📊', Colors.purpleAccent),
      ],
    );
  }

  Widget _buildMetricCard(
      String label, String value, String emoji, Color color) {
    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withAlpha(25), width: 1),
              boxShadow: [
                BoxShadow(
                  color: color.withAlpha(50),
                  blurRadius: 15,
                  spreadRadius: 1,
                )
              ],
            ),
            child: Column(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: color,
                      height: 1.2),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
                const SizedBox(height: 2),
                Text(label,
                    style: const TextStyle(color: Colors.white54, fontSize: 9),
                    textAlign: TextAlign.center,
                    maxLines: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getNpsColor(int nps) {
    if (nps >= 50) return Colors.greenAccent;
    if (nps >= 0) return Colors.amberAccent;
    return Colors.redAccent;
  }

  Widget _buildResponseMomentum(List<Map<String, dynamic>> responses) {
    if (responses.isEmpty) {
      return _glassCard(
        child: const SizedBox(
          height: 160,
          child: Center(child: Text('No responses yet')),
        ),
      );
    }

    final times = responses.map((r) => r['ts'] as DateTime).toList()..sort();

    final spots = <FlSpot>[];
    for (int i = 0; i < times.length; i++) {
      spots.add(FlSpot(i.toDouble(), (i + 1).toDouble()));
    }

    return _glassCard(
      child: SizedBox(
        height: 160,
        child: LineChart(
          LineChartData(
            minY: 0,
            gridData: FlGridData(show: false),
            titlesData: FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                barWidth: 3,
                gradient: LinearGradient(
                  colors: [
                    Colors.cyanAccent.withAlpha(220),
                    Colors.blueAccent.withAlpha(220),
                  ],
                ),
                dotData: FlDotData(show: true),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      Colors.cyanAccent.withAlpha(40),
                      Colors.blueAccent.withAlpha(10),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResponseTimeCluster(List<Map<String, dynamic>> responses) {
    if (responses.length < 2) {
      return _glassCard(
        child: const SizedBox(
          height: 140,
          child: Center(
            child: Text(
              'Waiting for more responses to analyze timing…',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ),
      );
    }

    final times = responses.map((r) => r['ts'] as DateTime).toList()..sort();
    final first = times.first;

    int fast = 0, medium = 0, slow = 0;

    for (final t in times.skip(1)) {
      final mins = t.difference(first).inMinutes;
      if (mins <= 10) {
        fast++;
      } else if (mins <= 60) {
        medium++;
      } else {
        slow++;
      }
    }

    final values = [fast, medium, slow];
    final maxVal = values.reduce(math.max).toDouble().clamp(1, double.infinity);

    String insight;
    if (slow >= fast && slow >= medium) {
      insight = '⏳ Most users responded late — distribution may be weak';
    } else if (fast >= medium) {
      insight = '⚡ Users responded quickly — strong engagement';
    } else {
      insight = '🟡 Mixed response timing — moderate reach';
    }

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Response Timing',
            style: TextStyle(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: BarChart(
              BarChartData(
                maxY: maxVal + 1,
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        const labels = ['Fast', 'Moderate', 'Slow'];
                        return Text(
                          labels[v.toInt()],
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 10),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(
                  3,
                  (i) => BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: values[i].toDouble(),
                        width: 16,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6)),
                        color: [
                          Colors.greenAccent,
                          Colors.amberAccent,
                          Colors.redAccent,
                        ][i],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            insight,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildResponseConsistency(List<Map<String, dynamic>> responses) {
    if (responses.length < 5) {
      return _glassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Engagement Pattern',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14),
            ),
            SizedBox(height: 12),
            LinearProgressIndicator(
              value: 0.4,
              minHeight: 10,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(Colors.white38),
            ),
            SizedBox(height: 8),
            Text(
              '⏳ Too early to determine engagement pattern',
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontStyle: FontStyle.italic),
            ),
          ],
        ),
      );
    }

    final times = responses.map((r) => r['ts'] as DateTime).toList()..sort();

    final gaps = <int>[];
    for (int i = 1; i < times.length; i++) {
      gaps.add(times[i].difference(times[i - 1]).inMinutes);
    }

    final avgGap = gaps.reduce((a, b) => a + b) / gaps.length;
    final variance =
        gaps.map((g) => (g - avgGap) * (g - avgGap)).reduce((a, b) => a + b) /
            gaps.length;

    final normalized = variance.clamp(0, 600).toDouble();
    final double progress = (normalized / 600).clamp(0.0, 1.0).toDouble();

    final bool isBurst = progress > 0.6;

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Engagement Pattern',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation(
              isBurst ? Colors.redAccent : Colors.greenAccent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isBurst
                ? '🚨 Responses came in a short burst — engagement faded'
                : '✅ Responses arrived steadily over time',
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildCriticalAlerts(
      List<Map<String, dynamic>> responses, List questions) {
    final alerts = <Widget>[];

    if (responses.isEmpty) {
      return const SizedBox();
    }

    final completion = <int>[];
    for (final q in questions) {
      int answered = 0;
      for (final r in responses) {
        if ((r['answers'] as Map).containsKey(q['question'])) {
          answered++;
        }
      }
      completion.add(((answered / responses.length) * 100).toInt());
    }

    final lowest = completion.reduce((a, b) => a < b ? a : b);
    if (lowest < 60) {
      final idx = completion.indexWhere((c) => c == lowest);
      alerts.add(
        _buildAlertBox(
            '⚠️ High Drop-off',
            'Q${idx + 1}:  ${100 - lowest}% abandoned this question',
            Colors.redAccent),
      );
    }

    int negativeCount = 0, totalRatings = 0;
    for (final r in responses) {
      for (final q in questions) {
        if (q['type'] == 'rating') {
          final ans = r['answers'][q['question']];
          if (ans != null) {
            totalRatings++;
            final max = q['ratingMax'] ?? 5;
            if ((ans as num) < max * 0.4) {
              negativeCount++;
            }
          }
        }
      }
    }
    if (totalRatings > 0 && ((negativeCount / totalRatings) * 100) > 30) {
      alerts.add(
        _buildAlertBox(
            '😟 Negative Sentiment',
            '${((negativeCount / totalRatings) * 100).toStringAsFixed(0)}% gave poor ratings',
            Colors.orangeAccent),
      );
    }

    if (responses.length < 5) {
      alerts.add(
        _buildAlertBox(
            'ℹ️ Low Volume',
            'Only ${responses.length} responses.  Collect more for insights.',
            Colors.blueAccent),
      );
    }

    if (alerts.isEmpty) {
      return _glassCard(
        child: const Text('All good!  ✅',
            style: TextStyle(color: Colors.greenAccent)),
      );
    }

    return Column(children: [
      _sectionTitle('⚠️ Critical Alerts'),
      ...alerts,
    ]);
  }

  Widget _buildAlertBox(String title, String msg, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withAlpha(150), width: 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
                      const SizedBox(height: 2),
                      Text(msg,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailedQuestion(
      Map<String, dynamic> q, List<Map<String, dynamic>> responses) {
    final type = q['type'] as String? ?? 'text';
    final qText = q['question'] as String? ?? 'Question';

    final answers = responses
        .map((r) => r['answers'][qText])
        .where((a) => a != null)
        .toList();

    if (answers.isEmpty) {
      return _glassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(qText,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            const Text('No responses',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      );
    }

    Widget content;
    String insight;

    switch (type) {
      case 'rating':
        final vals = answers.cast<num>();
        final avg = vals.reduce((a, b) => a + b) / vals.length;
        final max = q['ratingMax'] ?? 5;
        final ratio = avg / max;
        content = Column(
          children: [
            LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(
                ratio >= 0.7
                    ? Colors.greenAccent
                    : ratio >= 0.5
                        ? Colors.amberAccent
                        : Colors.redAccent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Average: ${avg.toStringAsFixed(1)}/$max',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        );
        insight = ratio >= 0.7
            ? '⭐ Excellent ratings'
            : ratio >= 0.5
                ? '😊 Good feedback'
                : '😟 Needs improvement';
        break;

      case 'yesno':
        final strs = answers.cast<String>();
        final yes = strs.where((a) => a == 'Yes').length;
        final total = strs.length;
        final ratio = yes / total;
        content = Column(
          children: [
            LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(Colors.greenAccent),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Yes:  $yes (${(ratio * 100).toStringAsFixed(0)}%)',
                    style: const TextStyle(
                        color: Colors.greenAccent, fontSize: 11)),
                Text(
                    'No: ${total - yes} (${((1 - ratio) * 100).toStringAsFixed(0)}%)',
                    style:
                        const TextStyle(color: Colors.redAccent, fontSize: 11)),
              ],
            ),
          ],
        );
        insight = ratio >= 0.6
            ? '✅ Strong agreement'
            : ratio <= 0.4
                ? '❌ Disagreement'
                : '⚖️ Split opinions';
        break;

      case 'mcq':
        final strs = answers.cast<String>();
        final Map<String, int> counts = {};
        for (final a in strs) {
          counts[a] = (counts[a] ?? 0) + 1;
        }
        final entries = counts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final topOption = entries.first;

        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: entries.take(3).map((e) {
            final ratio = e.value / strs.length;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      e.key,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 6,
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation(
                          Color.lerp(
                            Colors.indigoAccent,
                            Colors.purpleAccent,
                            ratio,
                          )!,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 30,
                    child: Text(
                      '${(ratio * 100).toStringAsFixed(0)}%',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 10),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
        insight =
            '🎯 Top:  "${topOption.key}" (${(topOption.value / strs.length * 100).toStringAsFixed(0)}%)';
        break;

      case 'text':
        final strs = answers.cast<String>();
        final Map<String, int> freq = {};
        for (final a in strs) {
          final key = a.trim().toLowerCase();
          if (key.isNotEmpty) freq[key] = (freq[key] ?? 0) + 1;
        }
        final sorted = freq.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final topWords = sorted.take(5).toList();

        if (topWords.isEmpty) {
          content = const Text('No valid text responses',
              style: TextStyle(color: Colors.white54, fontSize: 12));
          insight = 'No feedback';
        } else {
          final maxFreq = topWords.first.value;
          content = Wrap(
            spacing: 6,
            runSpacing: 6,
            children: topWords.map((e) {
              final ratio = e.value / maxFreq;
              final fontSize = 10 + (ratio * 4);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withAlpha((ratio * 200).toInt()),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  e.key,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          );
          insight = '💬 Top theme: "${topWords.first.key}"';
        }
        break;

      default:
        content = const SizedBox();
        insight = '';
    }

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(qText,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          content,
          const SizedBox(height: 6),
          Text(insight,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _glassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withAlpha(25), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withAlpha(5),
                blurRadius: 15,
                spreadRadius: 1,
              )
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          t,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      );
}
