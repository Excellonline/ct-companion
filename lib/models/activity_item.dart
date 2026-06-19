import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityItem {
  final String id;
  final String type;
  final String title;
  final String body;
  final String entityType;
  final String entityId;
  final String actorUid;
  final String actorName;
  final String actorEmail;
  final DateTime createdAt;

  ActivityItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.entityType,
    required this.entityId,
    required this.actorUid,
    required this.actorName,
    required this.actorEmail,
    required this.createdAt,
  });

  factory ActivityItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? const {};
    return ActivityItem(
      id: doc.id,
      type: data['type'] as String? ?? 'activity',
      title: data['title'] as String? ?? 'Activity',
      body: data['body'] as String? ?? '',
      entityType: data['entityType'] as String? ?? '',
      entityId: data['entityId'] as String? ?? '',
      actorUid: data['actorUid'] as String? ?? '',
      actorName: data['actorName'] as String? ?? 'Team member',
      actorEmail: data['actorEmail'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
