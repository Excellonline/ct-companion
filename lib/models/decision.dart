import 'package:cloud_firestore/cloud_firestore.dart';

class Decision {
  final String id;
  final String title;
  final String rationale;
  final String createdByUid;
  final String createdByName;
  final String createdByEmail;
  final String updatedByUid;
  final String updatedByName;
  final String updatedByEmail;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Decision({
    required this.id,
    required this.title,
    required this.rationale,
    required this.createdByUid,
    required this.createdByName,
    required this.createdByEmail,
    required this.updatedByUid,
    required this.updatedByName,
    required this.updatedByEmail,
    required this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isArchived => archivedAt != null;

  factory Decision.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? const {};
    return Decision(
      id: doc.id,
      title: data['title'] as String? ?? 'Untitled decision',
      rationale: data['rationale'] as String? ?? '',
      createdByUid: data['createdByUid'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? 'Team member',
      createdByEmail: data['createdByEmail'] as String? ?? '',
      updatedByUid: data['updatedByUid'] as String? ?? '',
      updatedByName: data['updatedByName'] as String? ?? 'Team member',
      updatedByEmail: data['updatedByEmail'] as String? ?? '',
      archivedAt: (data['archivedAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
