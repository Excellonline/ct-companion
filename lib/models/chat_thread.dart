import 'package:cloud_firestore/cloud_firestore.dart';

class ChatThread {
  final String id;
  final String title;
  final String createdByUid;
  final String createdByName;
  final String createdByEmail;
  final String updatedByUid;
  final String updatedByName;
  final String updatedByEmail;
  final String lastMessagePreview;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatThread({
    required this.id,
    required this.title,
    required this.createdByUid,
    required this.createdByName,
    required this.createdByEmail,
    required this.updatedByUid,
    required this.updatedByName,
    required this.updatedByEmail,
    required this.lastMessagePreview,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatThread.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? const {};
    return ChatThread(
      id: doc.id,
      title: data['title'] as String? ?? 'Untitled topic',
      createdByUid: data['createdByUid'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? '',
      createdByEmail: data['createdByEmail'] as String? ?? '',
      updatedByUid: data['updatedByUid'] as String? ?? '',
      updatedByName: data['updatedByName'] as String? ?? '',
      updatedByEmail: data['updatedByEmail'] as String? ?? '',
      lastMessagePreview: data['lastMessagePreview'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
