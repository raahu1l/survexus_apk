// lib/analytics/widgets/question_analytics_card.dart

import 'package:flutter/material.dart';
import '../models/analytics_models.dart';
import '../engine/insight_engine.dart';

class QuestionAnalyticsCard extends StatefulWidget {
  final QuestionAnalytics question;

  const QuestionAnalyticsCard({super.key, required this.question});

  @override
  State<QuestionAnalyticsCard> createState() => _QuestionAnalyticsCardState();
}

class _QuestionAnalyticsCardState extends State<QuestionAnalyticsCard> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final insight = buildQuestionInsight(q);

    final total = q.totalResponses == 0
        ? q.counts.fold<int>(0, (a, b) => a + b)
        : q.totalResponses;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------- TITLE ----------
            Row(
              children: [
                Expanded(
                  child: Text(
                    q.question,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => expanded = !expanded),
                  child: Icon(
                    expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 22,
                  ),
                )
              ],
            ),

            const SizedBox(height: 4),

            // ---------- META ----------
            Text(
              "$total responses",
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: Colors.grey),
            ),

            const SizedBox(height: 12),

            // ---------- INSIGHT CHIP ----------
            _InsightChip(insight.headline),

            const SizedBox(height: 10),

            // ---------- MAIN CHART ----------
            _buildMainChart(q),

            // ---------- DETAILS ----------
            if (expanded && insight.details.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 4),
              ...insight.details.map(
                (d) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("• "),
                      Expanded(
                        child: Text(
                          d,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ======================
  // MAIN CHART SWITCHER
  // ======================

  Widget _buildMainChart(QuestionAnalytics q) {
    // ✅ TEXT QUESTIONS: always display frequency view
    if (q.type == QuestionType.text) {
      return _TextFrequencyChart(question: q);
    }

    // ✅ NO DATA SAFETY
    final int total = q.totalResponses == 0
        ? q.counts.fold<int>(0, (a, b) => a + b)
        : q.totalResponses;

    if (total == 0) {
      return const _EmptyPlaceholder();
    }

    // ✅ YES / NO
    if (q.type == QuestionType.yesNo && q.options.length >= 2) {
      return _BinaryBar(
        left: q.options[0],
        right: q.options[1],
        leftCount: q.counts[0],
        rightCount: q.counts[1],
      );
    }

    // ✅ MCQ / RATING
    return _HorizontalResults(question: q);
  }
}

// ======================
// HORIZONTAL RESULTS BAR
// ======================

class _HorizontalResults extends StatelessWidget {
  final QuestionAnalytics question;

  const _HorizontalResults({required this.question});

  @override
  Widget build(BuildContext context) {
    final total = question.totalResponses == 0
        ? question.counts.fold<int>(0, (a, b) => a + b)
        : question.totalResponses;

    final int strongestIndex = question.counts.isEmpty
        ? -1
        : question.counts.indexOf(question.maxCount);

    return Column(
      children: List.generate(question.options.length, (i) {
        final label = question.options[i];
        final value = i < question.counts.length ? question.counts[i] : 0;
        final percent = total == 0 ? 0.0 : value / total;

        final isTop = i == strongestIndex;

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              SizedBox(
                  width: 90,
                  child: Text(label, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 10,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(
                      isTop ? Colors.indigo : Colors.blueGrey.shade300,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text("${(percent * 100).toStringAsFixed(0)}%"),
            ],
          ),
        );
      }),
    );
  }
}

// ======================
// YES / NO COMPARISON
// ======================

class _BinaryBar extends StatelessWidget {
  final String left;
  final String right;
  final int leftCount;
  final int rightCount;

  const _BinaryBar({
    required this.left,
    required this.right,
    required this.leftCount,
    required this.rightCount,
  });

  @override
  Widget build(BuildContext context) {
    final total = leftCount + rightCount;
    final leftP = total == 0 ? 0.0 : leftCount / total;
    final rightP = total == 0 ? 0.0 : rightCount / total;

    return Row(
      children: [
        _binaryCol(left, leftP),
        const SizedBox(width: 14),
        _binaryCol(right, rightP, alt: true),
      ],
    );
  }

  Widget _binaryCol(String label, double value, {bool alt = false}) {
    return Expanded(
      child: Column(
        children: [
          Text(label),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: value,
            valueColor: alt ? AlwaysStoppedAnimation(Colors.teal) : null,
          ),
          const SizedBox(height: 4),
          Text("${(value * 100).toStringAsFixed(0)}%"),
        ],
      ),
    );
  }
}

// ======================
// TEXT FREQUENCY BAR CHART
// ======================

class _TextFrequencyChart extends StatelessWidget {
  final QuestionAnalytics question;

  const _TextFrequencyChart({required this.question});

  // -------- NORMALIZE --------
  String _clean(String s) {
    return s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), '').trim();
  }

  // -------- BUILD COUNTS --------
  Map<String, int> _counts(List<String> data) {
    final map = <String, int>{};
    for (final v in data) {
      final key = _clean(v);
      if (key.isEmpty) continue;
      map[key] = (map[key] ?? 0) + 1;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    if (question.options.isEmpty) {
      return const Text("No responses yet");
    }

    final freq = _counts(question.options);

    if (freq.isEmpty) {
      return const Text("No meaningful responses yet");
    }

    final entries = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final total = entries.fold<int>(0, (sum, e) => sum + e.value);
    final top = entries.take(7).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Top requested features",
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...top.map((e) {
          final percent = e.value / total;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                    width: 90,
                    child: Text(e.key, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: percent,
                      minHeight: 10,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text("${e.value}"),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ======================
// UI ELEMENTS
// ======================

class _InsightChip extends StatelessWidget {
  final String text;
  const _InsightChip(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.indigo.withOpacity(.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w500)),
    );
  }
}

class _EmptyPlaceholder extends StatelessWidget {
  const _EmptyPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Center(child: Text("No responses yet")),
    );
  }
}
