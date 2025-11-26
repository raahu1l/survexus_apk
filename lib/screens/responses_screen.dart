// survey_response_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SurveyResponseScreen extends StatefulWidget {
  final String surveyId;
  final String surveyTitle;
  final dynamic questions; // accept List or Map from Firestore (robust)

  const SurveyResponseScreen({
    super.key,
    required this.surveyId,
    required this.surveyTitle,
    required this.questions,
  });

  @override
  State<SurveyResponseScreen> createState() => _SurveyResponseScreenState();
}

class _SurveyResponseScreenState extends State<SurveyResponseScreen> {
  final Map<int, dynamic> _answers = {};
  late PageController _pageController;
  int _currentPage = 0;
  bool _isSubmitted = false;
  bool _isLoading = false;
  String? _errorText;

  final Map<int, TextEditingController> _textControllers = {};
  late final List<Map<String, dynamic>> _questions; // normalized local list

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // Normalize incoming questions into safe list-of-maps
    _questions = _normalizeQuestions(widget.questions);
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ---------------- Normalization helpers ----------------

  /// Convert whatever Firestore gave us (List or Map) into a stable,
  /// ordered List<Map<String, dynamic>> that the UI can depend on.
  List<Map<String, dynamic>> _normalizeQuestions(dynamic raw) {
    try {
      // 1) If it's already a List — convert each element to Map<String,dynamic>
      if (raw is List) {
        return raw.map<Map<String, dynamic>>((e) {
          if (e is Map<String, dynamic>) return Map<String, dynamic>.from(e);
          if (e is Map) return Map<String, dynamic>.from(e.cast());
          // fallback primitive -> text question
          return <String, dynamic>{
            'type': 'text',
            'question': e?.toString() ?? ''
          };
        }).toList();
      }

      // 2) If it's a Map (e.g. {"0": {...}, "1": {...}} ) — order by numeric key if possible
      if (raw is Map) {
        // collect entries where key is parseable to int
        final pairs = <MapEntry<int, dynamic>>[];
        final other = <MapEntry<String, dynamic>>[];

        raw.forEach((k, v) {
          // keys might be int, String like "0", or something else
          if (k is int) {
            pairs.add(MapEntry(k, v));
          } else if (k is String) {
            final parsed = int.tryParse(k);
            if (parsed != null) {
              pairs.add(MapEntry(parsed, v));
            } else {
              other.add(MapEntry(k, v));
            }
          } else {
            other.add(MapEntry(k.toString(), v));
          }
        });

        // sort numeric keys ascending
        pairs.sort((a, b) => a.key.compareTo(b.key));

        final out = <Map<String, dynamic>>[];

        // add numeric-keyed items first in order
        for (final p in pairs) {
          final v = p.value;
          if (v is Map<String, dynamic>) {
            out.add(Map<String, dynamic>.from(v));
          } else if (v is Map) {
            out.add(Map<String, dynamic>.from(v.cast()));
          } else {
            out.add(<String, dynamic>{
              'type': 'text',
              'question': v?.toString() ?? ''
            });
          }
        }

        // then append any other entries (non-numeric keys)
        for (final p in other) {
          final v = p.value;
          if (v is Map<String, dynamic>) {
            out.add(Map<String, dynamic>.from(v));
          } else if (v is Map) {
            out.add(Map<String, dynamic>.from(v.cast()));
          } else {
            out.add(<String, dynamic>{
              'type': 'text',
              'question': v?.toString() ?? ''
            });
          }
        }

        return out;
      }

      // 3) unknown type -> return empty list
      return <Map<String, dynamic>>[];
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  String _normalizeType(String raw) {
    final t = raw.toString().trim().toLowerCase();
    if (t.isEmpty) return 'text';
    if (t == 'mcq' ||
        t.contains('multiple') ||
        t.contains('choice') ||
        t.contains('select') ||
        t.contains('dropdown')) {
      return 'mcq';
    }
    if (t == 'yesno' ||
        t.contains('yes/no') ||
        t == 'yn' ||
        t.contains('yesno')) {
      return 'yesno';
    }
    if (t.contains('rating') || t.contains('rate') || t.contains('star')) {
      return 'rating';
    }
    if (t.contains('linear') || t.contains('scale')) return 'linearScale';
    if (t.contains('date')) return 'date';
    if (t.contains('short') ||
        t.contains('long') ||
        t.contains('text') ||
        t.contains('answer')) {
      return 'text';
    }
    return t;
  }

  bool _isAnsweredIndex(int idx) {
    if (idx < 0 || idx >= _questions.length) return false;
    final q = _questions[idx];
    final type = _normalizeType(q['type']?.toString() ?? '');
    final val = _answers[idx];

    switch (type) {
      case 'text':
        return val != null && val.toString().trim().isNotEmpty;
      case 'mcq':
      case 'yesno':
        return val != null;
      case 'rating':
      case 'linearScale':
        if (val == null) return false;
        final n = num.tryParse(val.toString());
        return n != null && n > 0;
      case 'date':
        return val != null && val.toString().isNotEmpty;
      default:
        return val != null;
    }
  }

  void _nextPage() {
    if (!_isAnsweredIndex(_currentPage)) {
      setState(() => _errorText = "Please answer this question.");
      return;
    }
    setState(() => _errorText = null);
    if (_currentPage < _questions.length - 1) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 280), curve: Curves.easeInOut);
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
          duration: const Duration(milliseconds: 280), curve: Curves.easeInOut);
    }
  }

  // ---------------- Submit ----------------

  Future<void> _submitAnswers() async {
    for (int i = 0; i < _questions.length; i++) {
      if (!_isAnsweredIndex(i)) {
        setState(() => _errorText = "Please answer all questions.");
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final user = _user;

      if (user != null) {
        final exists = await FirebaseFirestore.instance
            .collection('responses')
            .where("surveyId", isEqualTo: widget.surveyId)
            .where("respondedBy", isEqualTo: user.uid)
            .limit(1)
            .get();
        if (exists.docs.isNotEmpty) {
          setState(() {
            _errorText = "You have already responded.";
            _isLoading = false;
          });
          return;
        }
      }

      final Map<String, dynamic> ans = {};
      _answers.forEach((k, v) {
        final val = v;
        if (val is double) {
          ans[k.toString()] = (val % 1 == 0) ? val.toInt() : val;
        } else {
          ans[k.toString()] = val;
        }
      });

      final Map<String, dynamic> responseDoc = {
        "surveyId": widget.surveyId,
        "answers": ans,
        "timestamp": FieldValue.serverTimestamp(),
      };

      if (user != null) {
        responseDoc["respondedBy"] = user.uid;
        responseDoc["respondedName"] = user.displayName ?? user.email ?? "User";
      } else {
        responseDoc["respondedBy"] = "anonymous";
        responseDoc["respondedName"] = "Guest";
      }

      await FirebaseFirestore.instance.collection("responses").add(responseDoc);

      // increment safely
      final ref =
          FirebaseFirestore.instance.collection("surveys").doc(widget.surveyId);
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final data = snap.data() ?? {};
        final current =
            (data['responseCount'] is int) ? data['responseCount'] as int : 0;
        tx.update(ref, {"responseCount": current + 1});
      });

      setState(() {
        _isSubmitted = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorText = "Failed to submit response.";
        _isLoading = false;
      });
    }
  }

  // ---------------- Build single question ----------------

  Widget _buildQuestion(Map<String, dynamic> q, int index) {
    final rawType = q["type"]?.toString() ?? '';
    final type = _normalizeType(rawType);
    final text =
        (q["question"] ?? q["text"] ?? q["title"] ?? "Question").toString();
    final ans = _answers[index];

    // normalize options to List<String>
    List<String> options = [];
    final rawOptions = q["options"];
    if (rawOptions is List) {
      options = rawOptions.map<String>((e) {
        if (e == null) return '';
        if (e is String) return e;
        if (e is num) return e.toString();
        if (e is Map) {
          if (e.containsKey('text')) return e['text']?.toString() ?? '';
          if (e.containsKey('label')) return e['label']?.toString() ?? '';
          if (e.containsKey('value')) return e['value']?.toString() ?? '';
          final first = e.values.isNotEmpty ? e.values.first : '';
          return first?.toString() ?? '';
        }
        return e.toString();
      }).toList();
    } else if (rawOptions is Map) {
      options = rawOptions.values.map<String>((e) {
        if (e == null) return '';
        if (e is String) return e;
        if (e is Map && e.containsKey('text')) {
          return e['text']?.toString() ?? '';
        }
        return e.toString();
      }).toList();
    }

    switch (type) {
      case "mcq":
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 12),
            if (options.isEmpty)
              const Text("No options available",
                  style: TextStyle(color: Colors.grey))
            else
              ...options.map((op) {
                return RadioListTile<dynamic>(
                  value: op,
                  groupValue: ans,
                  title: Text(op),
                  onChanged: (v) => setState(() => _answers[index] = v),
                );
              }),
          ],
        );

      case "yesno":
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text, style: const TextStyle(fontSize: 20)),
            RadioListTile<String>(
              value: "Yes",
              groupValue: ans?.toString(),
              title: const Text("Yes"),
              onChanged: (v) => setState(() => _answers[index] = v),
            ),
            RadioListTile<String>(
              value: "No",
              groupValue: ans?.toString(),
              title: const Text("No"),
              onChanged: (v) => setState(() => _answers[index] = v),
            ),
          ],
        );

      case "rating":
        final max = int.tryParse(q["ratingMax"]?.toString() ?? "5") ?? 5;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text, style: const TextStyle(fontSize: 20)),
            _StarRating(
              rating: double.tryParse(ans?.toString() ?? "0") ?? 0,
              maxRating: max,
              onRatingChanged: (v) => setState(() => _answers[index] = v),
            ),
          ],
        );

      case "linearScale":
        final max = int.tryParse(
                q["max"]?.toString() ?? q["ratingMax"]?.toString() ?? "5") ??
            5;
        final min = int.tryParse(q["min"]?.toString() ?? "1") ?? 1;
        double value = double.tryParse(ans?.toString() ?? min.toString()) ??
            min.toDouble();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text, style: const TextStyle(fontSize: 20)),
            Slider(
              value: value,
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: (max - min) > 0 ? (max - min) : 1,
              label: "${ans ?? min}",
              onChanged: (v) => setState(() => _answers[index] = v.toInt()),
            ),
          ],
        );

      case "date":
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                    child: Text(ans == null ? "Select date" : ans.toString())),
                ElevatedButton(
                  onPressed: () async {
                    final pick = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (pick != null) {
                      setState(() => _answers[index] = pick.toIso8601String());
                    }
                  },
                  child: const Text("Pick"),
                )
              ],
            ),
          ],
        );

      case "text":
      default:
        final controller = _textControllers[index] ??=
            TextEditingController(text: ans?.toString() ?? "");
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: "Enter your answer",
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => _answers[index] = v,
            ),
          ],
        );
    }
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    if (_isSubmitted) {
      return Scaffold(
        appBar: AppBar(title: const Text("Thank You")),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, size: 80, color: Colors.green),
              const SizedBox(height: 12),
              const Text("Response Submitted!", style: TextStyle(fontSize: 22)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Back"),
              )
            ],
          ),
        ),
      );
    }

    // If no questions, show helpful message rather than crash
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.surveyTitle)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, size: 56, color: Colors.grey),
              const SizedBox(height: 12),
              const Text("No questions found for this survey.",
                  style: TextStyle(fontSize: 16)),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Back"),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.surveyTitle)),
      body: PageView.builder(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _questions.length,
        onPageChanged: (p) => setState(() {
          _currentPage = p;
          _errorText = null;
        }),
        itemBuilder: (_, index) {
          final q = _questions[index];
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: (_questions.isEmpty)
                      ? 0
                      : (index + 1) / _questions.length,
                  color: Colors.indigo,
                  backgroundColor: Colors.grey.shade300,
                ),
                const SizedBox(height: 20),
                Expanded(
                    child:
                        SingleChildScrollView(child: _buildQuestion(q, index))),
                if (_errorText != null)
                  Text(_errorText!, style: const TextStyle(color: Colors.red)),
                Row(
                  children: [
                    if (index > 0)
                      OutlinedButton(
                        onPressed: _previousPage,
                        child: const Text("Back"),
                      ),
                    const Spacer(),
                    index == _questions.length - 1
                        ? ElevatedButton(
                            onPressed: _isLoading ? null : _submitAnswers,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : const Text("Submit"),
                          )
                        : ElevatedButton(
                            onPressed: _nextPage,
                            child: const Text("Next"),
                          ),
                  ],
                )
              ],
            ),
          );
        },
      ),
    );
  }
}

// STAR RATING
class _StarRating extends StatelessWidget {
  final double rating;
  final int maxRating;
  final ValueChanged<double> onRatingChanged;

  const _StarRating({
    required this.rating,
    required this.maxRating,
    required this.onRatingChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(maxRating, (i) {
        return IconButton(
          icon: Icon(
            i < rating ? Icons.star : Icons.star_border,
            color: Colors.amber,
            size: 28,
          ),
          onPressed: () => onRatingChanged((i + 1).toDouble()),
        );
      }),
    );
  }
}
