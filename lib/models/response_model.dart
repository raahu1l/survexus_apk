import 'package:cloud_firestore/cloud_firestore.dart';

class ResponseModel {
  final String id;
  final String surveyId;
  final String userId;
  final Map<String, dynamic> answers;
  final DateTime? timestamp;

  ResponseModel({
    required this.id,
    required this.surveyId,
    required this.userId,
    required this.answers,
    this.timestamp,
  });

  factory ResponseModel.fromMap(String id, Map<String, dynamic> map) {
    return ResponseModel(
      id: id,
      surveyId: map['surveyId'] ?? '',
      userId: map['userId'] ?? '',
      answers: Map<String, dynamic>.from(map['answers'] ?? {}),
      timestamp: map['timestamp'] is Timestamp
          ? (map['timestamp'] as Timestamp).toDate()
          : map['timestamp'] is DateTime
              ? map['timestamp'] as DateTime
              : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'surveyId': surveyId,
      'userId': userId,
      'answers': answers,
      'timestamp': timestamp != null
          ? Timestamp.fromDate(timestamp!)
          : FieldValue.serverTimestamp(),
    };
  }
}
