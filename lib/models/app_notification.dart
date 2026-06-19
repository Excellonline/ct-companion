import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String uid;
  final String title;
  final String body;
  final String entityType;
  final String entityId;
  final bool read;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.uid,
    required this.title,
    required this.body,
    required this.entityType,
    required this.entityId,
    required this.read,
    required this.createdAt,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? const {};
    return AppNotification(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      title: data['title'] as String? ?? 'Notification',
      body: data['body'] as String? ?? '',
      entityType: data['entityType'] as String? ?? '',
      entityId: data['entityId'] as String? ?? '',
      read: data['read'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
