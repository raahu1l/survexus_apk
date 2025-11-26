// lib/screens/survey_respond_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SurveyRespondScreen extends StatefulWidget {
  final String surveyId;
  final String surveyTitle;
  final List<dynamic> questions;

  const SurveyRespondScreen({
    super.key,
    required this.surveyId,
    required this.surveyTitle,
    required this.questions,
  });

  @override
  State<SurveyRespondScreen> createState() => _SurveyRespondScreenState();
}

class _SurveyRespondScreenState extends State<SurveyRespondScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _answers = {};
  bool _isSubmitting = false;

  // ------------------------------------------------------------------------------------------------
  // DATE PICKER
  // ------------------------------------------------------------------------------------------------
  Future<void> _pickDate(String qText) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 3),
      initialDate: now,
    );

    if (selected != null && mounted) {
      setState(() {
        _answers[qText] = "${selected.day}/${selected.month}/${selected.year}";
      });
    }
  }

  // ------------------------------------------------------------------------------------------------
  // SUBMIT RESPONSE
  // ------------------------------------------------------------------------------------------------
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Manual validation for rating questions
    for (final q in widget.questions) {
      final qMap = _safeQuestionMap(q);
      final qText = qMap['question'].toString();
      final qType = qMap['type'].toString().toLowerCase();

      if (qType == 'rating' &&
          (_answers[qText] == null || _answers[qText] is! int)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Please rate: $qText")),
        );
        return;
      }
    }

    _formKey.currentState!.save();
    setState(() => _isSubmitting = true);

    try {
      // ----------------------------------------------------------------------
      // Ensure user or guest exists
      // ----------------------------------------------------------------------
      User? user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        try {
          final creds = await FirebaseAuth.instance.signInAnonymously();
          user = creds.user;
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Could not create guest session: $e")),
          );
          setState(() => _isSubmitting = false);
          return;
        }
      }

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Unable to identify user.")),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      final uid = user.uid;
      final String userName = user.isAnonymous
          ? "Guest"
          : (user.displayName?.trim().isNotEmpty == true
              ? user.displayName!
              : user.email ?? "User");

      // ----------------------------------------------------------------------
      // Prevent duplicates (uid based)
      // ----------------------------------------------------------------------
      final existing = await FirebaseFirestore.instance
          .collection('responses')
          .where('surveyId', isEqualTo: widget.surveyId)
          .where('userId', isEqualTo: uid)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("You have already responded to this survey."),
          ),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      // ----------------------------------------------------------------------
      // Clean Option B Response Format
      // ----------------------------------------------------------------------
      final responseData = {
        'surveyId': widget.surveyId,
        'userId': uid,
        'userName': userName,
        'answers': _answers,
        'timestamp': FieldValue.serverTimestamp(),
      };

      // ----------------------------------------------------------------------
      // Batch write: save response + increment count
      // ----------------------------------------------------------------------
      final batch = FirebaseFirestore.instance.batch();

      final responseRef =
          FirebaseFirestore.instance.collection('responses').doc();
      final surveyRef =
          FirebaseFirestore.instance.collection('surveys').doc(widget.surveyId);

      batch.set(responseRef, responseData);
      batch.update(surveyRef, {
        'responseCount': FieldValue.increment(1),
      });

      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ Response submitted successfully!"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error submitting response: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ------------------------------------------------------------------------------------------------
  // SAFELY PARSE QUESTION MAP
  // ------------------------------------------------------------------------------------------------
  Map<String, dynamic> _safeQuestionMap(dynamic question) {
    if (question is Map<String, dynamic>) return question;
    if (question is Map) return Map<String, dynamic>.from(question);

    return {
      'type': 'text',
      'question': question.toString(),
      'options': [],
      'ratingMax': 5,
    };
  }

  // ------------------------------------------------------------------------------------------------
  // UI
  // ------------------------------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.surveyTitle),
        backgroundColor: const Color(0xFF6366F1),
        elevation: 2,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (int i = 0; i < widget.questions.length; i++)
              _buildQuestionField(i, widget.questions[i]),
            const SizedBox(height: 20),
            _isSubmitting
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    icon: const Icon(Icons.send_rounded),
                    label: const Text("Submit"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _submit,
                  ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------------------------------------
  // RENDER QUESTION FIELD
  // ------------------------------------------------------------------------------------------------
  Widget _buildQuestionField(int index, dynamic question) {
    final qMap = _safeQuestionMap(question);

    final qText = (qMap['question'] ?? "Question ${index + 1}").toString();
    final qType = (qMap['type'] ?? "text").toString().toLowerCase();

    final int ratingMax = (qMap['ratingMax'] is int)
        ? qMap['ratingMax']
        : int.tryParse(qMap['ratingMax'].toString()) ?? 5;

    // MCQ options
    final List<dynamic> raw = qMap['options'] is List ? qMap['options'] : [];
    final List<String> options = raw.map((e) => e.toString()).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(qText,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              )),
          const SizedBox(height: 8),

          // TEXT
          if (qType == "text")
            TextFormField(
              decoration: _inputDecoration(),
              validator: (v) => (v == null || v.isEmpty) ? "Required" : null,
              onSaved: (v) => _answers[qText] = v ?? "",
            )

          // YES/NO
          else if (qType == "yesno")
            DropdownButtonFormField<String>(
              decoration: _inputDecoration(),
              items: ["Yes", "No"]
                  .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                  .toList(),
              onChanged:
                  (val) {}, // required param — noop (validation uses onSaved)
              validator: (v) => v == null ? "Required" : null,
              onSaved: (v) => _answers[qText] = v,
            )

          // MCQ
          else if (qType == "mcq")
            DropdownButtonFormField<String>(
              decoration: _inputDecoration(),
              items: options
                  .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                  .toList(),
              onChanged:
                  (val) {}, // required param — noop (validation uses onSaved)
              validator: (v) => v == null ? "Required" : null,
              onSaved: (v) => _answers[qText] = v,
            )

          // NUMBER
          else if (qType == "number")
            TextFormField(
              decoration: _inputDecoration(),
              keyboardType: TextInputType.number,
              validator: (v) => (v == null || v.isEmpty) ? "Required" : null,
              onSaved: (v) => _answers[qText] = v ?? "",
            )

          // RATING
          else if (qType == "rating")
            Column(
              children: [
                for (int v = 1; v <= ratingMax; v++)
                  RadioListTile<int>(
                    value: v,
                    groupValue: _answers[qText] is int ? _answers[qText] : null,
                    title: Text("$v / $ratingMax"),
                    onChanged: (val) {
                      setState(() => _answers[qText] = val);
                    },
                  )
              ],
            )

          // DATE
          else if (qType == "date")
            InkWell(
              onTap: () => _pickDate(qText),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade500),
                ),
                child: Text(
                  _answers[qText] ?? "Tap to select date",
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            )

          // UNKNOWN TYPE
          else
            const Text(
              "⚠ Unsupported question type",
              style: TextStyle(color: Colors.red),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------------------------------------
  // INPUT DECORATION
  // ------------------------------------------------------------------------------------------------
  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.grey.withOpacity(0.1),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
