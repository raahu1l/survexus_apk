class TeamMember {
  final String uid;
  final String email;
  final String role;

  TeamMember({
    required this.uid,
    required this.email,
    required this.role,
  });

  factory TeamMember.fromMap(Map<String, dynamic> data) {
    return TeamMember(
      uid: data['uid'],
      email: data['email'],
      role: data['role'],
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'role': role,
      };
}

class TeamModel {
  final String id;
  final String name;
  final String ownerId;
  final List<TeamMember> members;

  TeamModel({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.members,
  });

  factory TeamModel.fromFirestore(String id, Map<String, dynamic> data) {
    return TeamModel(
      id: id,
      name: data['name'],
      ownerId: data['ownerId'],
      members: (data['members'] as List)
          .map((e) => TeamMember.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
