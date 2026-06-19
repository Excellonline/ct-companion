import 'package:cloud_firestore/cloud_firestore.dart';

/// A single row in the shared team to-do list.
class QuickItem {
  final String id;
  final String text;
  final bool done;
  final String? createdByUid;
  final String? createdByName;
  final String? updatedByUid;
  final String? updatedByName;
  final DateTime createdAt;
  final DateTime updatedAt;

  QuickItem({
    required this.id,
    required this.text,
    required this.done,
    required this.createdByUid,
    required this.createdByName,
    required this.updatedByUid,
    required this.updatedByName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory QuickItem.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return QuickItem(
      id: doc.id,
      text: d['text'] as String? ?? '',
      done: d['done'] as bool? ?? false,
      createdByUid: d['createdByUid'] as String?,
      createdByName: d['createdByName'] as String?,
      updatedByUid: d['updatedByUid'] as String?,
      updatedByName: d['updatedByName'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'text': text,
    'done': done,
    'createdByUid': createdByUid,
    'createdByName': createdByName,
    'updatedByUid': updatedByUid,
    'updatedByName': updatedByName,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };
}
