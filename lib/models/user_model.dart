import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final String role; // 'admin', 'user', 'guest', etc.
  final bool premium;
  final DateTime? createdAt;

  UserModel({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.role = 'user',
    this.premium = false,
    this.createdAt,
  });

  factory UserModel.fromMap(String id, Map<String, dynamic> map) {
    return UserModel(
      id: id,
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? map['name'],
      photoUrl: map['photoUrl'],
      role: map['role'] ?? 'user',
      premium: map['premium'] ?? false,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : map['createdAt'] is DateTime
              ? map['createdAt'] as DateTime
              : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'role': role,
      'premium': premium,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }
}
