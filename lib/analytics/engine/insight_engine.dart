// lib/analytics/engine/insight_engine.dart
import '../models/analytics_models.dart';

// ===============================
// INSIGHT MODELS
// ===============================

class QuestionInsight {
  final String headline;
  final List<String> details;

  QuestionInsight({required this.headline, required this.details});
}

class SurveyInsights {
  final QuestionAnalytics? dropOffQuestion;
  final String engagementLabel;
  final String? topAnswerAcrossSurvey;
  final String executiveSummary;

  // ✅ NEW: AI-style metrics
  final int satisfactionScore; // 0–100
  final double averageRating; // 0–5 (0 if no rating questions)
  final String sentimentLabel; // Positive / Mixed / Negative / No text feedback
  final int positiveComments;
  final int negativeComments;
  final List<String> mainComplaints; // key negative themes
  final List<String> mainPraises; // key positive themes

  SurveyInsights({
    required this.dropOffQuestion,
    required this.engagementLabel,
    required this.topAnswerAcrossSurvey,
    required this.executiveSummary,
    required this.satisfactionScore,
    required this.averageRating,
    required this.sentimentLabel,
    required this.positiveComments,
    required this.negativeComments,
    required this.mainComplaints,
    required this.mainPraises,
  });
}

// Small sentiment word lists (basic but effective for MVP)
const List<String> _positiveWords = [
  'good',
  'great',
  'excellent',
  'amazing',
  'love',
  'easy',
  'fast',
  'helpful',
  'nice',
  'smooth',
  'awesome',
  'satisfied',
  'happy',
  'cool',
];

const List<String> _negativeWords = [
  'bad',
  'slow',
  'terrible',
  'hate',
  'confusing',
  'hard',
  'difficult',
  'buggy',
  'crash',
  'expensive',
  'worst',
  'lag',
  'problem',
  'issue',
  'error',
  'frustrating',
];

// ===============================
// QUESTION INSIGHTS
// ===============================

QuestionInsight buildQuestionInsight(QuestionAnalytics q) {
  if (q.type == QuestionType.text) {
    return _buildTextQuestionInsight(q);
  }

  final total = q.totalResponses;
  final List<String> details = [];

  if (total == 0) {
    return QuestionInsight(
      headline: "No responses yet",
      details: ["Share your survey to start collecting answers."],
    );
  }

  int bestIndex = 0;
  int bestCount = 0;
  for (int i = 0; i < q.counts.length; i++) {
    if (q.counts[i] > bestCount) {
      bestCount = q.counts[i];
      bestIndex = i;
    }
  }

  final topOption = q.options.isNotEmpty ? q.options[bestIndex] : "Top option";
  final topPercent = (bestCount / total) * 100;

  String headline =
      'Most users selected "$topOption" (${topPercent.toStringAsFixed(1)}%).';

  // Polarization detection
  bool polarized = false;
  if (q.counts.length >= 2) {
    final sorted = List<int>.from(q.counts)..sort();
    final top1 = sorted.last;
    final top2 = sorted[sorted.length - 2];
    polarized = (top1 / total >= 0.25) &&
        (top2 / total >= 0.25) &&
        ((top1 / total) - (top2 / total)).abs() < 0.15;
  }

  if (polarized) {
    details.add("Users are divided — strong mixed opinions detected.");
  } else if (topPercent > 70) {
    details.add("There is a clear consensus among users.");
  }

  // Rating-specific extra
  if (q.type == QuestionType.rating) {
    double sum = 0;
    int count = 0;
    for (int i = 0; i < q.options.length && i < q.counts.length; i++) {
      final numeric = double.tryParse(q.options[i]) ?? (i + 1);
      sum += numeric * q.counts[i];
      count += q.counts[i];
    }
    final avg = count == 0 ? 0 : sum / count;
    details.add("Average rating: ${avg.toStringAsFixed(1)}");
  }

  if (details.isEmpty) {
    details.add("No extreme patterns detected.");
  }

  return QuestionInsight(headline: headline, details: details);
}

// ===============================
// TEXT INTELLIGENCE (PER QUESTION)
// ===============================

QuestionInsight _buildTextQuestionInsight(QuestionAnalytics q) {
  final answers = q.options;
  final total = q.totalResponses;

  if (total == 0 || answers.isEmpty) {
    return QuestionInsight(
      headline: "No responses yet",
      details: ["Users have not answered this question."],
    );
  }

  final Map<String, int> wordFrequency = {};
  final Map<String, int> phraseFrequency = {};

  for (final raw in answers) {
    final cleaned = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), '');
    final words = cleaned.split(" ").where((w) => w.length > 3).toList();

    for (final w in words) {
      wordFrequency[w] = (wordFrequency[w] ?? 0) + 1;
    }

    for (int i = 0; i < words.length - 1; i++) {
      final phrase = "${words[i]} ${words[i + 1]}";
      phraseFrequency[phrase] = (phraseFrequency[phrase] ?? 0) + 1;
    }
  }

  final sortedWords = wordFrequency.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final sortedPhrases = phraseFrequency.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final List<String> details = [];

  if (sortedWords.isNotEmpty) {
    final keywords = sortedWords.take(5).map((e) => e.key).join(", ");
    details.add("Common keywords: $keywords");
  }

  if (sortedPhrases.isNotEmpty && sortedPhrases.first.value > 1) {
    details.add('Repeated phrase: "${sortedPhrases.first.key}"');
  }

  final headline = sortedWords.isEmpty
      ? "No strong trend found"
      : 'Most users mention "${sortedWords.first.key}"';

  return QuestionInsight(headline: headline, details: details);
}

// ===============================
// SURVEY INSIGHTS
// ===============================

SurveyInsights buildSurveyInsights(SurveyAnalytics survey) {
  final dropOff = _findDropOffQuestion(survey.questions);
  final engagement = _computeEngagementLabel(survey);
  final top = _findTopAnswerAcrossSurvey(survey.questions);

  // NEW: rating + sentiment + satisfaction
  final averageRating = _computeAverageRating(survey);
  final textSummary = _analyzeSurveyText(survey.questions);

  final sentimentLabel = textSummary['sentimentLabel'] as String;
  final sentimentScore = textSummary['sentimentScore'] as int;
  final positiveComments = textSummary['positiveCount'] as int;
  final negativeComments = textSummary['negativeCount'] as int;
  final mainComplaints = (textSummary['complaints'] as List<String>);
  final mainPraises = (textSummary['praises'] as List<String>);

  final satisfactionScore = _computeSatisfactionScore(
    averageRating: averageRating,
    engagementLabel: engagement,
    sentimentScore: sentimentScore,
  );

  final summary = _buildExecutiveSummary(
    survey,
    dropOff,
    top,
    engagement,
    satisfactionScore,
    sentimentLabel,
    mainComplaints,
    mainPraises,
  );

  return SurveyInsights(
    dropOffQuestion: dropOff,
    engagementLabel: engagement,
    topAnswerAcrossSurvey: top,
    executiveSummary: summary,
    satisfactionScore: satisfactionScore,
    averageRating: averageRating,
    sentimentLabel: sentimentLabel,
    positiveComments: positiveComments,
    negativeComments: negativeComments,
    mainComplaints: mainComplaints,
    mainPraises: mainPraises,
  );
}

// ===============================
// AI EXECUTIVE SUMMARY (STRUCTURED)
// ===============================

String _buildExecutiveSummary(
  SurveyAnalytics survey,
  QuestionAnalytics? dropOff,
  String? topAnswer,
  String engagement,
  int satisfactionScore,
  String sentimentLabel,
  List<String> complaints,
  List<String> praises,
) {
  if (survey.totalResponses == 0) {
    return "This survey has not received any responses yet.";
  }

  final List<String> lines = [];

  // 1) Overall health
  lines.add(
      "Overall satisfaction is $satisfactionScore/100 with $engagement engagement and $sentimentLabel feedback mood.");

  // 2) Top answer pattern
  if (topAnswer != null) {
    lines.add('The most common answer across all questions is "$topAnswer".');
  }

  // 3) Drop-off
  if (dropOff != null) {
    lines.add('Users most often stop at the question: "${dropOff.question}".');
  }

  // 4) Pain points
  if (complaints.isNotEmpty) {
    final topComplaints = complaints.take(3).join(", ");
    lines.add("Main pain points mentioned: $topComplaints.");
  }

  // 5) Praises
  if (praises.isNotEmpty) {
    final topPraises = praises.take(3).join(", ");
    lines.add("Users especially appreciate: $topPraises.");
  }

  return lines.join(" ");
}

// ===============================
// SURVEY COMPARISON ENGINE (kept to avoid breaking code)
// ===============================

SurveyComparison compareSurveys(
  SurveyAnalytics a,
  SurveyAnalytics b,
) {
  final winnerResponses =
      a.totalResponses >= b.totalResponses ? a.title : b.title;

  final winnerCompletion =
      a.completionRate >= b.completionRate ? a.title : b.title;

  final aEngagement = _computeEngagementLabel(a);
  final bEngagement = _computeEngagementLabel(b);

  final winnerEngagement =
      _engagementScore(aEngagement) >= _engagementScore(bEngagement)
          ? a.title
          : b.title;

  final verdict = _buildComparisonSummary(
    a,
    b,
    winnerEngagement,
    winnerCompletion,
    winnerResponses,
  );

  return SurveyComparison(
    first: a,
    second: b,
    winnerByEngagement: winnerEngagement,
    winnerByCompletion: winnerCompletion,
    winnerByResponses: winnerResponses,
    comparativeSummary: verdict,
  );
}

int _engagementScore(String label) {
  switch (label) {
    case "High":
      return 3;
    case "Medium":
      return 2;
    default:
      return 1;
  }
}

String _buildComparisonSummary(
  SurveyAnalytics a,
  SurveyAnalytics b,
  String winnerEngagement,
  String winnerCompletion,
  String winnerResponses,
) {
  final List<String> lines = [];

  lines.add("Survey comparison summary:");
  lines.add("• Engagement – $winnerEngagement performs better.");
  lines.add("• Completion – $winnerCompletion has higher completion rate.");
  lines.add("• Volume – $winnerResponses received more responses.");

  if (winnerEngagement == winnerCompletion &&
      winnerCompletion == winnerResponses) {
    lines.add("$winnerEngagement clearly outperforms the other survey.");
  } else {
    lines.add(
        "Each survey performs better in different areas. No single survey dominates everywhere.");
  }

  return lines.join(" ");
}

// ===============================
// HELPERS
// ===============================

QuestionAnalytics? _findDropOffQuestion(List<QuestionAnalytics> questions) {
  if (questions.isEmpty) return null;
  final sorted = List<QuestionAnalytics>.from(questions)
    ..sort((a, b) => a.totalResponses.compareTo(b.totalResponses));
  return sorted.first.totalResponses == sorted.last.totalResponses
      ? null
      : sorted.first;
}

String _computeEngagementLabel(SurveyAnalytics survey) {
  if (survey.totalResponses == 0) return "Low";
  final r = survey.completionRate;
  if (r >= 80) return "High";
  if (r >= 40) return "Medium";
  return "Low";
}

String? _findTopAnswerAcrossSurvey(List<QuestionAnalytics> questions) {
  int highest = 0;
  String? best;

  for (final q in questions) {
    for (int i = 0; i < q.options.length && i < q.counts.length; i++) {
      if (q.counts[i] > highest) {
        highest = q.counts[i];
        best = q.options[i];
      }
    }
  }

  return highest == 0 ? null : best;
}

// ---------- NEW: AVERAGE RATING (0–5) ----------

double _computeAverageRating(SurveyAnalytics survey) {
  double sum = 0;
  int count = 0;

  for (final q in survey.questions) {
    if (q.type != QuestionType.rating) continue;
    for (int i = 0; i < q.options.length && i < q.counts.length; i++) {
      final value = double.tryParse(q.options[i]) ?? (i + 1).toDouble();
      sum += value * q.counts[i];
      count += q.counts[i];
    }
  }

  if (count == 0) return 0;
  return sum / count;
}

// ---------- NEW: SURVEY TEXT ANALYSIS ----------

Map<String, dynamic> _analyzeSurveyText(List<QuestionAnalytics> questions) {
  final textQuestions =
      questions.where((q) => q.type == QuestionType.text).toList();

  if (textQuestions.isEmpty) {
    return {
      'sentimentLabel': 'No text feedback',
      'sentimentScore': 50,
      'positiveCount': 0,
      'negativeCount': 0,
      'complaints': <String>[],
      'praises': <String>[],
    };
  }

  int positiveCount = 0;
  int negativeCount = 0;
  int neutralCount = 0;

  final Map<String, int> wordFreq = {};

  for (final q in textQuestions) {
    for (final raw in q.options) {
      if (raw.trim().isEmpty) continue;

      final lower = raw.toLowerCase();
      final cleaned =
          lower.replaceAll(RegExp(r'[^a-z0-9 ]'), ' '); // basic cleaning
      final words =
          cleaned.split(RegExp(r'\s+')).where((w) => w.length > 2).toList();

      bool hasPos = false;
      bool hasNeg = false;

      for (final w in words) {
        wordFreq[w] = (wordFreq[w] ?? 0) + 1;
        if (_positiveWords.contains(w)) hasPos = true;
        if (_negativeWords.contains(w)) hasNeg = true;
      }

      if (hasPos && !hasNeg) {
        positiveCount++;
      } else if (hasNeg && !hasPos) {
        negativeCount++;
      } else {
        neutralCount++;
      }
    }
  }

  final total = positiveCount + negativeCount + neutralCount;
  int sentimentScore;
  String sentimentLabel;

  if (total == 0) {
    sentimentScore = 50;
    sentimentLabel = "No text feedback";
  } else {
    final rawScore =
        ((positiveCount - negativeCount) / total.toDouble()) * 50.0 + 50.0;
    sentimentScore = rawScore.round().clamp(0, 100);

    if (sentimentScore >= 65) {
      sentimentLabel = "Positive";
    } else if (sentimentScore <= 40) {
      sentimentLabel = "Negative";
    } else {
      sentimentLabel = "Mixed";
    }
  }

  // complaints / praises from word frequency
  final List<String> complaints = [];
  final List<String> praises = [];

  final sortedWords = wordFreq.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  for (final e in sortedWords) {
    if (_negativeWords.contains(e.key)) {
      complaints.add(e.key);
    } else if (_positiveWords.contains(e.key)) {
      praises.add(e.key);
    }
  }

  return {
    'sentimentLabel': sentimentLabel,
    'sentimentScore': sentimentScore,
    'positiveCount': positiveCount,
    'negativeCount': negativeCount,
    'complaints': complaints,
    'praises': praises,
  };
}

// ---------- NEW: SATISFACTION SCORE (0–100) ----------

int _computeSatisfactionScore({
  required double averageRating,
  required String engagementLabel,
  required int sentimentScore,
}) {
  // Rating contribution (if no rating present, use neutral 50)
  final int ratingScore = averageRating <= 0
      ? 50
      : (averageRating / 5.0 * 100).round().clamp(0, 100);

  // Combine rating + sentiment
  double combined = ratingScore * 0.6 + sentimentScore * 0.4;

  // Small adjustment from engagement
  if (engagementLabel == "High") {
    combined += 5;
  } else if (engagementLabel == "Low") {
    combined -= 5;
  }

  final result = combined.round().clamp(0, 100);
  return result;
}
