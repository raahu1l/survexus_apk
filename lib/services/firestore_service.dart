import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Typed collection references
  CollectionReference<Map<String, dynamic>> get surveysRef =>
      _db.collection('surveys');

  CollectionReference<Map<String, dynamic>> get responsesRef =>
      _db.collection('responses');

  CollectionReference<Map<String, dynamic>> get usersRef =>
      _db.collection('users');

  // -------------------------
  // Generic safe query wrapper
  // -------------------------
  /// Runs [queryFn] and converts FirebaseExceptions into a clearer exception
  /// that includes the composite index link when available.
  Future<T> _safeRun<T>(Future<T> Function() queryFn) async {
    try {
      return await queryFn();
    } on FirebaseException catch (fe) {
      // Firestore composite index errors usually contain a direct URL to create the index.
      final link = _extractIndexLink(fe.message);
      if (link != null) {
        // Re-throw with a clearer message containing the index creation link
        throw Exception(
          'Firestore query requires a composite index. Open this link to create it: $link\nOriginal error: ${fe.message}',
        );
      }
      // Generic FirebaseException fallback
      throw Exception('Firestore error: ${fe.message}');
    } catch (e) {
      rethrow;
    }
  }

  String? _extractIndexLink(String? message) {
    if (message == null) return null;
    // Firestore usually embeds a URL starting with "https://console.firebase.google.com/..." or "https://console.firebase.google.com/..." or a long googleapis link.
    final urlRegex = RegExp(r'https?://[^\s]+');
    final match = urlRegex.firstMatch(message);
    return match?.group(0);
  }

  // -------------------------
  // Survey fetchers
  // -------------------------
  /// Get all surveys ordered by createdAt (descending).
  Future<QuerySnapshot<Map<String, dynamic>>> getSurveys({int limit = 50}) {
    return _safeRun(
      () =>
          surveysRef.orderBy('createdAt', descending: true).limit(limit).get(),
    );
  }

  /// Stream all surveys ordered by createdAt (descending).
  Stream<QuerySnapshot<Map<String, dynamic>>> streamSurveys({int limit = 50}) {
    // Streams cannot be wrapped by _safeRun, so we return the stream directly,
    // callers should handle FirebaseException from the stream listener.
    return surveysRef
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  /// Get surveys filtered by status (e.g. 'active', 'closed', 'pending') ordered by createdAt.
  /// Note: Combining .where('status', ...) with .orderBy('createdAt') may require a composite index.
  Future<QuerySnapshot<Map<String, dynamic>>> getSurveysByStatus(
    String status, {
    int limit = 50,
  }) {
    return _safeRun(
      () => surveysRef
          .where('status', isEqualTo: status)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get(),
    );
  }

  /// Stream surveys filtered by status.
  Stream<QuerySnapshot<Map<String, dynamic>>> streamSurveysByStatus(
    String status, {
    int limit = 50,
  }) {
    return surveysRef
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  /// Get surveys created by a specific user (creatorId or legacy createdBy).
  /// This will try both fields to maximize compatibility.
  Future<QuerySnapshot<Map<String, dynamic>>> getSurveysByCreator(
    String creatorId, {
    int limit = 50,
  }) {
    // Prefer the modern field 'creatorId' — but many older documents may use 'createdBy'.
    // We issue a query against 'creatorId' and if it returns empty we fallback to 'createdBy'.
    return _safeRun(() async {
      final primary = await surveysRef
          .where('creatorId', isEqualTo: creatorId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      if (primary.docs.isNotEmpty) {
        return primary;
      }

      // Fallback to legacy field
      return surveysRef
          .where('createdBy', isEqualTo: creatorId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
    });
  }

  /// Stream surveys created by a user (tries creatorId first).
  Stream<QuerySnapshot<Map<String, dynamic>>> streamSurveysByCreator(
    String creatorId, {
    int limit = 50,
  }) {
    // Streams don't support easy fallback; prefer 'creatorId' stream (recommended).
    return surveysRef
        .where('creatorId', isEqualTo: creatorId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  /// Get a single survey by id
  Future<DocumentSnapshot<Map<String, dynamic>>> getSurveyById(
    String surveyId,
  ) {
    return _safeRun(() => surveysRef.doc(surveyId).get());
  }

  /// Stream a single survey by id
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamSurveyById(
    String surveyId,
  ) {
    return surveysRef.doc(surveyId).snapshots();
  }

  // -------------------------
  // Other operations
  // -------------------------
  Future<void> updateSurveyStatus(String surveyId, String status) {
    return _safeRun(() => surveysRef.doc(surveyId).update({'status': status}));
  }

  Future<void> submitResponse(
    String surveyId,
    Map<String, dynamic> answers,
    String userId,
  ) {
    final doc = responsesRef.doc();
    return _safeRun(
      () => doc.set({
        'surveyId': surveyId,
        'userId': userId,
        'answers': answers,
        'timestamp': FieldValue.serverTimestamp(),
      }),
    );
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getUser(String userId) {
    return _safeRun(() => usersRef.doc(userId).get());
  }
}
