import 'package:cloud_firestore/cloud_firestore.dart';

enum TeamRole {
  pending('pending', 'Pending'),
  member('member', 'Member'),
  admin('admin', 'Admin');

  const TeamRole(this.id, this.label);
  final String id;
  final String label;

  static TeamRole? tryFromId(String? id) {
    for (final role in TeamRole.values) {
      if (role.id == id) return role;
    }
    return null;
  }

  static TeamRole fromId(String? id) {
    return tryFromId(id) ?? TeamRole.pending;
  }
}

class TeamMember {
  final String uid;
  final String email;
  final String displayName;
  final TeamRole role;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastSeenAt;

  TeamMember({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
    required this.lastSeenAt,
  });

  bool get isAdmin => role == TeamRole.admin;
  bool get isPending => role == TeamRole.pending;

  String get label {
    final trimmed = displayName.trim();
    if (trimmed.isNotEmpty) return trimmed;
    return email.isNotEmpty ? email : 'Team member';
  }

  factory TeamMember.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? const {};
    return TeamMember(
      uid: doc.id,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      role: TeamRole.fromId(data['role'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastSeenAt: (data['lastSeenAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'email': email,
        'displayName': displayName,
        'role': role.id,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'lastSeenAt':
            lastSeenAt == null ? null : Timestamp.fromDate(lastSeenAt!),
      };
}
