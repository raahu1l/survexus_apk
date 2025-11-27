// lib/screens/survey_creation_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'vip_pricing_screen.dart';

enum QuestionType { mcq, yesno, rating, text, date }

class SurveyCreationScreen extends StatefulWidget {
  const SurveyCreationScreen({super.key});

  @override
  State<SurveyCreationScreen> createState() => _SurveyCreationScreenState();
}

class _SurveyCreationScreenState extends State<SurveyCreationScreen> {
  final _titleController = TextEditingController();
  final List<SurveyQuestion> _questions = [];
  bool _loading = false;

  bool _isVIP = false; // live
  Color? _selectedColor;
  String? _bannerUrl;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _vipSub;
  StreamSubscription<User?>? _authSub;

  // avoid showing the “VIP activated” snackbar on the initial snapshot load
  bool _initialVipSnapshotSeen = false;

  @override
  void initState() {
    super.initState();
    _attachAuthListener(); // handles user switches & reattaches VIP listener
  }

  @override
  void dispose() {
    _titleController.dispose();
    _vipSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  void _attachAuthListener() {
    // Listen to auth state — if user changes, rebind to the correct user doc.
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      // reset snapshot gate for new user session
      _initialVipSnapshotSeen = false;

      // clear previous VIP subscription safely
      await _vipSub?.cancel();
      _vipSub = null;

      if (user == null) {
        if (!mounted) return;
        setState(() {
          _isVIP = false;
          _selectedColor = null;
          _bannerUrl = null;
        });
        return;
      }

      // Set initial (non-stream) value to avoid flicker
      await _checkVIP(user);

      // Attach live listener
      _listenVipRealtime(user);
    });
  }

  Future<void> _checkVIP(User user) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final vip = _readVip(doc.data());
      if (!mounted) return;
      setState(() => _isVIP = vip);
    } catch (_) {
      // swallow — keep previous UI state
    }
  }

  bool _readVip(Map<String, dynamic>? data) {
    // Support both `isVIP` and `premium` flags; treat true as VIP.
    if (data == null) return false;
    final v1 = data['isVIP'];
    final v2 = data['premium'];
    if (v1 is bool) return v1;
    if (v2 is bool) return v2;
    return false;
  }

  void _listenVipRealtime(User user) {
    _vipSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;

      final vip = _readVip(snap.data());
      final wasVip = _isVIP;

      // Update state first
      if (vip != wasVip) {
        setState(() {
          _isVIP = vip;
          // If VIP was revoked, clean VIP-only selections to prevent stale data.
          if (!vip) {
            _selectedColor = null;
            _bannerUrl = null;
          }
        });

        // Snackbar feedback (avoid on the very first snapshot we see)
        if (_initialVipSnapshotSeen) {
          if (vip) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🎉 VIP activated! Premium tools unlocked.'),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('VIP removed. Premium tools have been disabled.'),
              ),
            );
          }
        }
      }

      // Mark that we’ve processed the first incoming snapshot for this session.
      _initialVipSnapshotSeen = true;
    }, onError: (_) {
      // ignore stream errors; optional: show a non-blocking message
    });
  }

  void _addQuestion(QuestionType type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: QuestionDialog(
          type: type,
          onSaved: (q) => setState(() => _questions.add(q)),
        ),
      ),
    );
  }

  void _removeQuestion(int index) {
    setState(() => _questions.removeAt(index));
  }

  // Serialize a SurveyQuestion to a safe, normalized Map.
  Map<String, Object?> _serializeQuestion(SurveyQuestion q) {
    return <String, Object?>{
      'question': q.question,
      'type': q.type.name,
      'options': q.options.map((e) => e.toString()).toList(),
      'ratingMax': q.ratingMax < 1 ? 5 : q.ratingMax,
    };
  }

  // ------------------ FIXED _submit() + TEAM SUPPORT ------------------
  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty) {
      _showSnack('Please enter a survey title.');
      return;
    }
    if (_questions.isEmpty) {
      _showSnack('Please add at least one question.');
      return;
    }

    if (!mounted) return;
    setState(() => _loading = true);
    try {
      // --- Prepare base data ---
      final user = FirebaseAuth.instance.currentUser;

      // default creator info
      String creatorId = 'guest';
      String creatorName = 'Unknown';
      String? creatorEmail;

      if (user != null) {
        creatorId = user.uid;
        creatorEmail = user.email;
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          final userData = userDoc.data();
          if (userData != null) {
            if (userData['name'] is String &&
                (userData['name'] as String).trim().isNotEmpty) {
              creatorName = userData['name'] as String;
            } else if (userData['fullName'] is String &&
                (userData['fullName'] as String).trim().isNotEmpty) {
              creatorName = userData['fullName'] as String;
            } else if (user.email != null && user.email!.isNotEmpty) {
              creatorName = user.email!;
            } else if (user.displayName != null &&
                user.displayName!.isNotEmpty) {
              creatorName = user.displayName!;
            }
          } else {
            if (user.displayName != null && user.displayName!.isNotEmpty) {
              creatorName = user.displayName!;
            } else if (user.email != null) {
              creatorName = user.email!;
            }
          }
        } catch (_) {
          if (user.displayName != null && user.displayName!.isNotEmpty) {
            creatorName = user.displayName!;
          } else if (user.email != null) {
            creatorName = user.email!;
          }
        }
      } else {
        creatorName = 'Guest';
      }

      final serializedQuestions =
          _questions.map((q) => _serializeQuestion(q)).toList();

      final Map<String, Object?> data = {
        'title': _titleController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'questions': serializedQuestions,
        'status': 'pending',
        'creatorId': creatorId,
        'creatorName': creatorName,
        'creatorEmail': creatorEmail,
        'questionCount': serializedQuestions.length,
        'responseCount': 0,
        'createdBy': creatorId,
        'createdByName': creatorName,
      };

      if (_isVIP) {
        if (_selectedColor != null) data['themeColor'] = _selectedColor!.value;
        if (_bannerUrl != null) data['bannerUrl'] = _bannerUrl!;
      }

      // write to Firestore (still in top-level surveys)
      final docRef =
          await FirebaseFirestore.instance.collection('surveys').add(data);

      // ensure id is stored
      await docRef.update({'id': docRef.id, 'surveyId': docRef.id});

      if (!mounted) return;

      if (mounted) setState(() => _loading = false);

      await showDialog(
        context: context,
        useRootNavigator: true,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Survey saved'),
            content: const Text(
                '✅ Survey created successfully and is waiting for approval.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;
      try {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        }
      } catch (_) {
        // swallow navigation errors — do not crash app
      }

      _vipSub?.cancel();
      _authSub?.cancel();
      _vipSub = null;
      _authSub = null;
    } catch (e) {
      if (mounted) {
        _showSnack('❌ Failed to create survey: $e');
        setState(() => _loading = false);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ------------------ end _submit() ------------------

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBar(
        title: const Text('🧾 Create Survey'),
        elevation: 0,
        backgroundColor: Colors.blue.shade700,
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            onPressed: _loading ? null : _submit,
            tooltip: 'Save Survey',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddQuestionSheet,
        icon: const Icon(Icons.add),
        label: const Text('Add Question'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Survey Title',
                prefixIcon: const Icon(Icons.title),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildVipSection(),
            const SizedBox(height: 20),
            Expanded(
              child: _questions.isEmpty
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.library_add_outlined,
                            size: 80, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'No questions yet.\nTap “Add Question” to begin!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 18, color: Colors.grey.shade600),
                        ),
                      ],
                    )
                  : ReorderableListView.builder(
                      itemCount: _questions.length,
                      onReorder: (oldIndex, newIndex) {
                        if (oldIndex < newIndex) newIndex--;
                        final item = _questions.removeAt(oldIndex);
                        _questions.insert(newIndex, item);
                        setState(() {});
                      },
                      itemBuilder: (context, index) {
                        final q = _questions[index];
                        return AnimatedContainer(
                          key: ValueKey(q),
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    Colors.grey.withAlpha((0.2 * 255).toInt()),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              )
                            ],
                          ),
                          child: ListTile(
                            leading: Icon(
                              _iconForType(q.type),
                              color: Colors.blueAccent,
                            ),
                            title: Text(
                              q.question,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 16),
                            ),
                            subtitle: Text(
                              'Type: ${q.type.name.toUpperCase()}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.redAccent),
                              onPressed: () => _removeQuestion(index),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────
  // VIP FEATURES
  // ───────────────────────────────
  Widget _buildVipSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isVIP)
          Card(
            color: Colors.blue.shade50,
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("✨ AI & Branding Tools (VIP)",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),

                  // ⬇️ Template picker (name + icon only)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text("Generate AI Survey Template"),
                    onPressed: _openTemplatePicker,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text("🎨 Theme Color: "),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _pickColor,
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor:
                              _selectedColor ?? Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.image),
                    label: const Text("Add Banner Image"),
                    onPressed: () {
                      setState(() =>
                          _bannerUrl = "https://via.placeholder.com/400x120");
                      _showSnack("Banner image added (sample)");
                    },
                  ),
                ],
              ),
            ),
          )
        else
          Card(
            color: Colors.grey.shade200,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("🔒 VIP Features Locked",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                      "Get AI-generated templates and custom branding tools by upgrading to VIP."),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const VipPricingScreen(dialogMode: false),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber[700],
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("Upgrade to VIP"),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ───────────────────────────────
  // TEMPLATE PICKER (name + icon only)
  // ───────────────────────────────
  void _openTemplatePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TemplatePicker(
        onPick: (templateKey) {
          Navigator.pop(context);
          _applyTemplate(templateKey);
          _showSnack(
              "✨ '${_templateDefs[templateKey]!.name}' template applied!");
        },
      ),
    );
  }

  // Definitions
  final Map<String, _TemplateDef> _templateDefs = {
    'feedback': _TemplateDef(
      name: 'Feedback',
      icon: Icons.rate_review_rounded,
    ),
    'product': _TemplateDef(
      name: 'Product',
      icon: Icons.shopping_bag_rounded,
    ),
    'event': _TemplateDef(
      name: 'Event',
      icon: Icons.event_available_rounded,
    ),
    'employee': _TemplateDef(
      name: 'Employee',
      icon: Icons.badge_rounded,
    ),
  };

  void _applyTemplate(String key) {
    final defs = _templateDefs[key];
    if (defs == null) return;

    final List<SurveyQuestion> generated;
    switch (key) {
      case 'feedback':
        generated = [
          SurveyQuestion.rating('How satisfied are you with our service?', 5),
          SurveyQuestion.mcq('How did you hear about us?',
              ['Friends/Family', 'Social Media', 'Search Engine', 'Other']),
          SurveyQuestion.text('What can we improve?'),
          SurveyQuestion.yesno('Would you recommend us to others?'),
        ];
        break;
      case 'product':
        generated = [
          SurveyQuestion.rating('Rate the product quality', 5),
          SurveyQuestion.mcq(
              'Primary use case?', ['Personal', 'Work', 'Education', 'Other']),
          SurveyQuestion.text('What feature do you want next?'),
          SurveyQuestion.yesno('Was setup easy?'),
        ];
        break;
      case 'event':
        generated = [
          SurveyQuestion.rating('Rate the event overall', 5),
          SurveyQuestion.mcq('Which sessions did you attend?',
              ['Keynote', 'Workshop', 'Networking', 'Expo']),
          SurveyQuestion.date('When did you attend?'),
          SurveyQuestion.text('Any suggestions for the next event?'),
        ];
        break;
      case 'employee':
        generated = [
          SurveyQuestion.rating('Rate your work-life balance', 5),
          SurveyQuestion.mcq('How often do you receive feedback?',
              ['Weekly', 'Monthly', 'Quarterly', 'Rarely']),
          SurveyQuestion.yesno('Do you have growth opportunities?'),
          SurveyQuestion.text('What can management do better?'),
        ];
        break;
      default:
        generated = [];
    }

    setState(() {
      _questions
        ..clear()
        ..addAll(generated);
    });
  }

  void _pickColor() async {
    final colors = [Colors.blue, Colors.green, Colors.red, Colors.orange];
    final chosen = await showDialog<Color>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text("Pick Theme Color"),
        children: colors
            .map((c) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, c),
                  child: Container(height: 30, color: c),
                ))
            .toList(),
      ),
    );
    if (chosen != null && mounted) setState(() => _selectedColor = chosen);
  }

  IconData _iconForType(QuestionType type) {
    switch (type) {
      case QuestionType.mcq:
        return Icons.list_alt;
      case QuestionType.yesno:
        return Icons.check_circle_outline;
      case QuestionType.rating:
        return Icons.star_rate;
      case QuestionType.text:
        return Icons.text_fields;
      case QuestionType.date:
        return Icons.date_range;
    }
  }

  void _showAddQuestionSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Choose Question Type',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87),
                ),
              ),
              const Divider(),
              _typeTile(Icons.list_alt, 'Multiple Choice',
                  () => _addQuestion(QuestionType.mcq)),
              _typeTile(Icons.check_box, 'Yes / No',
                  () => _addQuestion(QuestionType.yesno)),
              _typeTile(Icons.star, 'Rating (1–5)',
                  () => _addQuestion(QuestionType.rating)),
              _typeTile(Icons.text_fields, 'Short Answer',
                  () => _addQuestion(QuestionType.text)),
              _typeTile(Icons.date_range, 'Date Question',
                  () => _addQuestion(QuestionType.date)),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  ListTile _typeTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.blueAccent),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }
}

// ──────────────────────────────────────
// TEMPLATE PICKER SHEET (name + icon)
// ──────────────────────────────────────
class _TemplatePicker extends StatelessWidget {
  final void Function(String key) onPick;
  const _TemplatePicker({required this.onPick});

  @override
  Widget build(BuildContext context) {
    final items = const [
      _TemplateItem('feedback', 'Feedback', Icons.rate_review_rounded),
      _TemplateItem('product', 'Product', Icons.shopping_bag_rounded),
      _TemplateItem('event', 'Event', Icons.event_available_rounded),
      _TemplateItem('employee', 'Employee', Icons.badge_rounded),
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: MediaQuery.of(context).viewInsets,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Pick a Template',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              itemCount: items.length,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisExtent: 92,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (_, i) {
                final it = items[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onPick(it.key),
                  child: Ink(
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x11000000),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(it.icon, size: 28, color: Colors.blue.shade700),
                          const SizedBox(height: 8),
                          Text(
                            it.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateItem {
  final String key;
  final String name;
  final IconData icon;
  const _TemplateItem(this.key, this.name, this.icon);
}

class _TemplateDef {
  final String name;
  final IconData icon;
  const _TemplateDef({required this.name, required this.icon});
}

// ──────────────────────────────────────
// MODEL
// ──────────────────────────────────────
class SurveyQuestion {
  final QuestionType type;
  String question;
  List<String> options;
  int ratingMax;

  SurveyQuestion.mcq(this.question, [List<String>? options])
      : type = QuestionType.mcq,
        options = options ?? [],
        ratingMax = 5;

  SurveyQuestion.yesno(this.question)
      : type = QuestionType.yesno,
        options = const ['Yes', 'No'],
        ratingMax = 2;

  SurveyQuestion.rating(this.question, [this.ratingMax = 5])
      : type = QuestionType.rating,
        options = [];

  SurveyQuestion.text(this.question)
      : type = QuestionType.text,
        options = [],
        ratingMax = 5; // safe default (prevents 0 being stored)

  SurveyQuestion.date(this.question)
      : type = QuestionType.date,
        options = [],
        ratingMax = 5; // safe default

  Map<String, Object?> toMap() => {
        'type': type.name,
        'question': question,
        'options': (type == QuestionType.mcq && options.isEmpty)
            ? ['Option 1', 'Option 2']
            : options,
        'ratingMax': ratingMax,
      };
}

// ──────────────────────────────────────
// QUESTION DIALOG
// ──────────────────────────────────────
class QuestionDialog extends StatefulWidget {
  final QuestionType type;
  final void Function(SurveyQuestion) onSaved;

  const QuestionDialog({required this.type, required this.onSaved, super.key});

  @override
  State<QuestionDialog> createState() => _QuestionDialogState();
}

class _QuestionDialogState extends State<QuestionDialog> {
  final _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [];
  int _ratingMax = 5;

  @override
  void initState() {
    super.initState();
    if (widget.type == QuestionType.mcq) {
      _optionControllers.addAll([
        TextEditingController(),
        TextEditingController(),
      ]);
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Wrap(
        children: [
          Text(
            'Add ${widget.type.name.toUpperCase()} Question',
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _questionController,
            decoration: const InputDecoration(
              labelText: 'Question Text',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          if (widget.type == QuestionType.mcq)
            Column(
              children: [
                ..._optionControllers.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final ctrl = entry.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: ctrl,
                            decoration: InputDecoration(
                              labelText: 'Option ${idx + 1}',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle,
                              color: Colors.redAccent),
                          onPressed: () {
                            if (_optionControllers.length > 2) {
                              setState(() => _optionControllers.removeAt(idx));
                            }
                          },
                        ),
                      ],
                    ),
                  );
                }),
                TextButton.icon(
                  onPressed: () => setState(
                      () => _optionControllers.add(TextEditingController())),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Option'),
                ),
              ],
            ),
          if (widget.type == QuestionType.rating)
            Row(
              children: [
                const Text('Max Rating:'),
                Expanded(
                  child: Slider(
                    min: 3,
                    max: 10,
                    divisions: 7,
                    value: _ratingMax.toDouble(),
                    label: _ratingMax.toString(),
                    onChanged: (v) => setState(() => _ratingMax = v.toInt()),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Add Question'),
              onPressed: _onSave,
            ),
          ),
        ],
      ),
    );
  }

  void _onSave() {
    final text = _questionController.text.trim();
    if (text.isEmpty) return;

    switch (widget.type) {
      case QuestionType.mcq:
        final opts = _optionControllers
            .map((c) => c.text.trim())
            .where((t) => t.isNotEmpty)
            .toList();
        if (opts.length < 2) return;
        widget.onSaved(SurveyQuestion.mcq(text, opts));
        break;
      case QuestionType.yesno:
        widget.onSaved(SurveyQuestion.yesno(text));
        break;
      case QuestionType.rating:
        widget.onSaved(SurveyQuestion.rating(text, _ratingMax));
        break;
      case QuestionType.text:
        widget.onSaved(SurveyQuestion.text(text));
        break;
      case QuestionType.date:
        widget.onSaved(SurveyQuestion.date(text));
        break;
    }
    Navigator.pop(context);
  }
}
