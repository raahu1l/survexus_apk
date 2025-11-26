import 'package:cloud_firestore/cloud_firestore.dart';

class SurveyModel {
  final String id;
  final String title;
  final List<Map<String, dynamic>> questions;
  final String status;
  final String? createdBy;
  final DateTime? createdAt;

  SurveyModel({
    required this.id,
    required this.title,
    required this.questions,
    this.status = 'pending',
    this.createdBy,
    this.createdAt,
  });

  factory SurveyModel.fromMap(String id, Map<String, dynamic> map) {
    return SurveyModel(
      id: id,
      title: map['title'] ?? '',
      questions: List<Map<String, dynamic>>.from(map['questions'] ?? []),
      status: map['status'] ?? 'pending',
      createdBy: map['createdBy'] ?? '',
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : map['createdAt'] is DateTime
              ? map['createdAt'] as DateTime
              : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'questions': questions,
      'status': status,
      'createdBy': createdBy,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }
}
