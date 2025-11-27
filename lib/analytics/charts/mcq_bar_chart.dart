// lib/analytics/charts/mcq_bar_chart.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/analytics_models.dart';

class McqBarChart extends StatelessWidget {
  final QuestionAnalytics question;

  const McqBarChart({super.key, required this.question});

  @override
  Widget build(BuildContext context) {
    final total = question.totalResponses == 0
        ? question.counts.fold<int>(0, (p, e) => p + e)
        : question.totalResponses;

    if (total == 0 || question.options.isEmpty) {
      return const Center(child: Text('No data for this question yet.'));
    }

    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    final groups = <BarChartGroupData>[];
    for (int i = 0; i < question.options.length; i++) {
      final count = i < question.counts.length ? question.counts[i] : 0;
      final percent = total == 0 ? 0.0 : (count / total) * 100;
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: percent,
              fromY: 0,
              width: 18,
              borderRadius: BorderRadius.circular(8),
              color: primary,
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        barGroups: groups,
        gridData: FlGridData(show: true),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (v, meta) =>
                  Text("${v.toInt()}%", style: const TextStyle(fontSize: 10)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (v, meta) {
                final idx = v.toInt();
                if (idx < 0 || idx >= question.options.length) {
                  return const SizedBox.shrink();
                }
                final label = question.options[idx];
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: SizedBox(
                    width: 60,
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
