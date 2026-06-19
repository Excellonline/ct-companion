import 'package:cloud_firestore/cloud_firestore.dart';

class Folder {
  final String id;
  final String name;
  final String color;
  final DateTime createdAt;

  Folder({
    required this.id,
    required this.name,
    required this.color,
    required this.createdAt,
  });

  factory Folder.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Folder(
      id: doc.id,
      name: d['name'] as String? ?? '',
      color: d['color'] as String? ?? '#3F51B5',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'color': color,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}
