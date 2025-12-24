import 'package:cloud_firestore/cloud_firestore.dart';

class TeamAccessService {
  static final _db = FirebaseFirestore.instance;

  static Stream<QuerySnapshot<Map<String, dynamic>>> userTeamsStream(
      String uid) {
    return _db.collection('teams').where('members',
        arrayContains: {'uid': uid, 'role': 'admin'}).snapshots();
  }
}
