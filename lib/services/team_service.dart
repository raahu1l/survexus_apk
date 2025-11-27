import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/team_model.dart';
import '../models/invite_model.dart';

class TeamService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static const String _teamsCol = 'teams';
  static const String _invitesCol = 'team_invites';

  // ✅ CREATE TEAM
  static Future<void> createTeam(String name) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Not logged in");

    final teamRef = _db.collection(_teamsCol).doc();

    await teamRef.set({
      'name': name,
      'ownerId': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'members': [
        {
          'uid': user.uid,
          'email': user.email?.toLowerCase() ?? '',
          'role': 'admin',
          'joinedAt': DateTime.now().toIso8601String(),
        }
      ],
    });
  }

  // ✅ LIVE TEAMS STREAM
  static Stream<List<TeamModel>> myTeamsStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    final uid = user.uid;
    final email = (user.email ?? '').toLowerCase();

    return _db.collection(_teamsCol).snapshots().map((snap) {
      return snap.docs
          .map((d) => TeamModel.fromFirestore(d.id, d.data()))
          .where((team) =>
              team.ownerId == uid ||
              team.members
                  .any((m) => m.uid == uid || m.email.toLowerCase() == email))
          .toList();
    });
  }

  // ✅ SEND INVITE
  static Future<void> sendInvite({
    required String teamId,
    required String teamName,
    required String emailToInvite,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Not logged in");

    final email = emailToInvite.trim().toLowerCase();
    if (email.isEmpty) throw Exception("Invalid email");

    if ((user.email ?? '').toLowerCase() == email) {
      throw Exception("You cannot invite yourself");
    }

    final existing = await _db
        .collection(_invitesCol)
        .where('teamId', isEqualTo: teamId)
        .where('email', isEqualTo: email)
        .where('accepted', isEqualTo: false)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception("Invite already sent");
    }

    await _db.collection(_invitesCol).add({
      'teamId': teamId,
      'teamName': teamName,
      'email': email,
      'invitedByUid': user.uid,
      'invitedByEmail': user.email?.toLowerCase(),
      'accepted': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ✅ LOAD INVITES
  static Stream<List<InviteModel>> myPendingInvitesStream() {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return const Stream.empty();

    return _db
        .collection(_invitesCol)
        .where('email', isEqualTo: user.email!.toLowerCase())
        .where('accepted', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.map(InviteModel.fromFirestore).toList());
  }

  // ✅ ACCEPT INVITE
  static Future<void> acceptInvite(InviteModel invite) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Not logged in");

    final teamRef = _db.collection(_teamsCol).doc(invite.teamId);
    final inviteRef = _db.collection(_invitesCol).doc(invite.id);

    await _db.runTransaction((tx) async {
      final teamSnap = await tx.get(teamRef);
      if (!teamSnap.exists) throw Exception("Team missing");

      final data = teamSnap.data()!;
      final members = (data['members'] as List).cast<Map<String, dynamic>>();

      final already = members.any((m) => m['uid'] == user.uid);

      if (!already) {
        members.add({
          'uid': user.uid,
          'email': user.email!.toLowerCase(),
          'role': 'member',
          'joinedAt': DateTime.now().toIso8601String(),
        });

        tx.update(teamRef, {'members': members});
      }

      tx.update(inviteRef, {
        'accepted': true,
        'acceptedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // ✅ DECLINE INVITE
  static Future<void> declineInvite(InviteModel invite) async {
    await _db.collection(_invitesCol).doc(invite.id).delete();
  }

  // ✅ DELETE TEAM (OWNER ONLY)
  static Future<void> deleteTeam(String teamId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Not logged in");

    final teamRef = _db.collection(_teamsCol).doc(teamId);
    final team = await teamRef.get();

    if (!team.exists) throw Exception("Team not found");
    if (team['ownerId'] != user.uid) {
      throw Exception("Only owner can delete");
    }

    final invites = await _db
        .collection(_invitesCol)
        .where('teamId', isEqualTo: teamId)
        .get();

    for (final d in invites.docs) {
      await d.reference.delete();
    }

    await teamRef.delete();
  }
}
