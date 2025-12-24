import '../models/analytics_models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseAnalyticsAdapter {
  static SurveyAnalytics buildSurveyAnalytics({
    required Map<String, dynamic> surveyDoc,
    required List<Map<String, dynamic>> responses,
  }) {
    final questionsRaw = surveyDoc['questions'] as List? ?? [];

    final questions = questionsRaw.map<QuestionAnalytics>((qRaw) {
      final id = qRaw['id'].toString();
      final questionText = qRaw['question']?.toString() ?? '';
      final type = _parseType(qRaw['type']?.toString());

      List<String> options =
          (qRaw['options'] as List? ?? []).map((e) => e.toString()).toList();

      return _buildQuestionAnalytics(
        id: id,
        question: questionText,
        type: type,
        options: options,
        allResponses: responses,
        order: (qRaw['order'] is num) ? (qRaw['order'] as num).toInt() : 0,
      );
    }).toList();

    questions.sort((a, b) => a.order.compareTo(b.order));

    final createdRaw = surveyDoc['createdAt'];
    DateTime createdAt =
        createdRaw is Timestamp ? createdRaw.toDate() : DateTime.now();

    return SurveyAnalytics(
      id: surveyDoc['id']?.toString() ?? '',
      title: surveyDoc['title']?.toString() ?? "Untitled",
      isLive: surveyDoc['isLive'] == true,
      createdAt: createdAt,
      lastResponseAt: _getLastResponseTime(responses),
      totalResponses: responses.length,
      expectedResponses: (surveyDoc['expectedResponses'] is num)
          ? (surveyDoc['expectedResponses'] as num).toInt()
          : 0,
      questions: questions,
    );
  }

  // -------------------------------------------------------------------------
  // ✅ DEFINITIVE FIXED QUESTION ANALYTICS
  // -------------------------------------------------------------------------

  static QuestionAnalytics _buildQuestionAnalytics({
    required String id,
    required String question,
    required QuestionType type,
    required List<String> options,
    required List<Map<String, dynamic>> allResponses,
    required int order,
  }) {
    final Map<String, int> countsMap = {};
    final List<String> textAnswers = [];
    int total = 0;

    final normQuestion = _norm(question);

    // ✅ RATING ALWAYS HAS SCALE
    if (type == QuestionType.rating) {
      options = ['1', '2', '3', '4', '5'];
      for (final o in options) {
        countsMap[o] = 0;
      }
    }

    for (final r in allResponses) {
      final answers = r['answers'];
      if (answers is! Map) continue;

      // ✅ FLEXIBLE match by normalized question text
      String? matchedKey;
      for (final k in answers.keys) {
        if (_norm(k.toString()) == normQuestion) {
          matchedKey = k.toString();
          break;
        }
      }

      if (matchedKey == null) continue;
      final value = answers[matchedKey];
      if (value == null) continue;

      total++;

      // ---------------- TEXT ----------------
      if (type == QuestionType.text) {
        textAnswers.add(value.toString());
        continue;
      }

      // ---------------- RATING ----------------
      if (type == QuestionType.rating) {
        final rating = double.tryParse(value.toString());
        if (rating == null) continue;

        final idx = rating.clamp(1, 5).toInt() - 1;
        final key = options[idx];

        countsMap[key] = (countsMap[key] ?? 0) + 1;
        continue;
      }

      // ---------------- MCQ / YESNO ----------------
      final selected = value.toString().trim();

      // ✅ Auto build options from answers if empty
      if (!options.contains(selected)) {
        options.add(selected);
      }

      countsMap[selected] = (countsMap[selected] ?? 0) + 1;
    }

    final counts = options.map((o) => countsMap[o] ?? 0).toList();

    return QuestionAnalytics(
      id: id,
      question: question,
      type: type,
      options: type == QuestionType.text ? textAnswers : options,
      counts: type == QuestionType.text ? [] : counts,
      totalResponses: total,
      order: order,
    );
  }

  // -------------------------------------------------------------------------

  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static QuestionType _parseType(String? raw) {
    final v = raw?.toLowerCase() ?? '';
    if (v.contains('rating') || v.contains('scale')) return QuestionType.rating;
    if (v.contains('yes')) return QuestionType.yesNo;
    if (v.contains('text') || v.contains('open')) return QuestionType.text;
    return QuestionType.mcq;
  }

  static DateTime? _getLastResponseTime(List<Map<String, dynamic>> responses) {
    DateTime? latest;
    for (final r in responses) {
      final t = r['timestamp'];
      if (t is DateTime) {
        if (latest == null || t.isAfter(latest)) latest = t;
      }
    }
    return latest;
  }
}
