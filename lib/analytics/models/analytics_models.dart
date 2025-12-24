// lib/analytics/models/analytics_models.dart

enum QuestionType {
  mcq,
  yesNo,
  rating,
  text,
}

class QuestionAnalytics {
  final String id;
  final String question;
  final QuestionType type;
  final List<String> options;
  final List<int> counts;
  final int totalResponses;
  final int order;

  QuestionAnalytics({
    required this.id,
    required this.question,
    required this.type,
    required this.options,
    required this.counts,
    required this.totalResponses,
    required this.order,
  });

  int get maxCount =>
      counts.isEmpty ? 0 : counts.reduce((a, b) => a > b ? a : b);

  double get maxPercent =>
      totalResponses == 0 ? 0 : (maxCount / totalResponses) * 100;
}

class SurveyAnalytics {
  final String id;
  final String title;
  final bool isLive;
  final DateTime createdAt;
  final DateTime? lastResponseAt;
  final int totalResponses;
  final int expectedResponses;
  final List<QuestionAnalytics> questions;

  SurveyAnalytics({
    required this.id,
    required this.title,
    required this.isLive,
    required this.createdAt,
    this.lastResponseAt,
    required this.totalResponses,
    required this.expectedResponses,
    required this.questions,
  });

  double get completionRate =>
      expectedResponses == 0 ? 0 : (totalResponses / expectedResponses) * 100;
}

/// ===============================
/// ✅ COMPARISON MODEL (NEW)
/// ===============================
class SurveyComparison {
  final SurveyAnalytics first;
  final SurveyAnalytics second;

  final String winnerByEngagement;
  final String winnerByCompletion;
  final String winnerByResponses;
  final String? comparativeSummary;

  SurveyComparison({
    required this.first,
    required this.second,
    required this.winnerByEngagement,
    required this.winnerByCompletion,
    required this.winnerByResponses,
    required this.comparativeSummary,
  });
}
