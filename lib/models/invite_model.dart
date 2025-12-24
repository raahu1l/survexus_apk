// lib/models/invite_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class InviteModel {
  final String id;
  final String teamId;
  final String email; // invited email
  final String? teamName;
  final String? invitedByUid;
  final String? invitedByEmail;
  final bool accepted;
  final DateTime? createdAt;
  final DateTime? acceptedAt;

  InviteModel({
    required this.id,
    required this.teamId,
    required this.email,
    this.teamName,
    this.invitedByUid,
    this.invitedByEmail,
    this.accepted = false,
    this.createdAt,
    this.acceptedAt,
  });

  factory InviteModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final createdRaw = data['createdAt'];
    final acceptedRaw = data['acceptedAt'];

    DateTime? created;
    if (createdRaw is Timestamp) created = createdRaw.toDate();
    DateTime? acceptedAt;
    if (acceptedRaw is Timestamp) acceptedAt = acceptedRaw.toDate();

    return InviteModel(
      id: doc.id,
      teamId: data['teamId'] ?? '',
      email: (data['email'] ?? '').toString(),
      teamName: data['teamName'] as String?,
      invitedByUid: data['invitedByUid'] as String?,
      invitedByEmail: data['invitedByEmail'] as String?,
      accepted: data['accepted'] == true,
      createdAt: created,
      acceptedAt: acceptedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'teamId': teamId,
      'email': email.toLowerCase(),
      'teamName': teamName,
      'invitedByUid': invitedByUid,
      'invitedByEmail': invitedByEmail,
      'accepted': accepted,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      if (acceptedAt != null) 'acceptedAt': Timestamp.fromDate(acceptedAt!),
    };
  }
}
