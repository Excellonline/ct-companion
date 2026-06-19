import 'package:cloud_firestore/cloud_firestore.dart';

class NoteComment {
  final String id;
  final String noteId;
  final String text;
  final String createdByUid;
  final String createdByName;
  final String createdByEmail;
  final DateTime createdAt;

  NoteComment({
    required this.id,
    required this.noteId,
    required this.text,
    required this.createdByUid,
    required this.createdByName,
    required this.createdByEmail,
    required this.createdAt,
  });

  factory NoteComment.fromFirestore(String noteId, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? const {};
    return NoteComment(
      id: doc.id,
      noteId: noteId,
      text: data['text'] as String? ?? '',
      createdByUid: data['createdByUid'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? 'Team member',
      createdByEmail: data['createdByEmail'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
