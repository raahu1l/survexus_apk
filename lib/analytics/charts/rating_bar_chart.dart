// lib/analytics/charts/rating_bar_chart.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/analytics_models.dart';

class RatingBarChart extends StatelessWidget {
  final QuestionAnalytics question;

  const RatingBarChart({super.key, required this.question});

  @override
  Widget build(BuildContext context) {
    final total = question.totalResponses == 0
        ? question.counts.fold<int>(0, (p, e) => p + e)
        : question.totalResponses;

    if (total == 0 || question.options.isEmpty) {
      return const Center(child: Text('No ratings yet.'));
    }

    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    final bars = <BarChartGroupData>[];
    double sum = 0;
    double responded = 0;

    for (int i = 0; i < question.options.length; i++) {
      final label = question.options[i];
      final count = i < question.counts.length ? question.counts[i] : 0;
      final numeric = double.tryParse(label) ?? (i + 1).toDouble();

      sum += numeric * count;
      responded += count;

      bars.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: count.toDouble(),
              fromY: 0,
              width: 18,
              borderRadius: BorderRadius.circular(6),
              color: primary,
            ),
          ],
        ),
      );
    }

    final avg = responded == 0 ? 0 : sum / responded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              barGroups: bars,
              gridData: FlGridData(show: true),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 28),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (v, meta) {
                      final idx = v.toInt();
                      if (idx < 0 || idx >= question.options.length) {
                        return const SizedBox.shrink();
                      }
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        child: Text(
                          question.options[idx],
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
        Text("Average rating: ${avg.toStringAsFixed(1)}"),
      ],
    );
  }
}
