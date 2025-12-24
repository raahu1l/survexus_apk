import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CommentService {
  static final _db = FirebaseFirestore.instance;

  static Stream<QuerySnapshot<Map<String, dynamic>>> commentsForSurvey(
      String surveyId) {
    return _db
        .collection('comments')
        .where('surveyId', isEqualTo: surveyId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  static Future<void> addComment(String surveyId, String text) async {
    final user = FirebaseAuth.instance.currentUser!;
    await _db.collection('comments').add({
      'surveyId': surveyId,
      'uid': user.uid,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
