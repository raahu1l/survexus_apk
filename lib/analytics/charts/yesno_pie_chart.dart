// lib/analytics/charts/yesno_pie_chart.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/analytics_models.dart';

class YesNoPieChart extends StatelessWidget {
  final QuestionAnalytics question;

  const YesNoPieChart({super.key, required this.question});

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
    final secondary = theme.colorScheme.secondary;

    final sections = <PieChartSectionData>[];
    for (int i = 0; i < question.options.length; i++) {
      final count = i < question.counts.length ? question.counts[i] : 0;
      if (count == 0) continue;

      final percent = (count / total) * 100;
      sections.add(
        PieChartSectionData(
          value: count.toDouble(),
          title: "${percent.toStringAsFixed(0)}%",
          radius: 60,
          titleStyle: const TextStyle(color: Colors.white, fontSize: 12),
          color: i.isEven ? primary : secondary,
        ),
      );
    }

    if (sections.isEmpty) {
      return const Center(child: Text('No data for this question yet.'));
    }

    return PieChart(PieChartData(
      sections: sections,
      sectionsSpace: 2,
      centerSpaceRadius: 30,
    ));
  }
}
