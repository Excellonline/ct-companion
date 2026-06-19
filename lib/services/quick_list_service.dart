import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/quick_item.dart';
import 'activity_service.dart';
import 'team_service.dart';

/// Identifies which simple checklist the items live in.
enum QuickListKind {
  todo('todoItems', 'To-Do');

  const QuickListKind(this.collection, this.label);
  final String collection;
  final String label;
}

class QuickListService {
  final QuickListKind kind;
  final _db = FirebaseFirestore.instance;
  final _team = TeamService();
  final _activity = ActivityService();

  QuickListService(this.kind);

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('workspaces').doc(cardTroveWorkspaceId).collection(
            kind.collection,
          );

  Stream<List<QuickItem>> stream() => _col
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs.map(QuickItem.fromFirestore).toList());

  Future<void> add(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final actor = _team.currentActor();
    final now = FieldValue.serverTimestamp();
    final ref = await _col.add({
      'text': trimmed,
      'done': false,
      ...actor.createdAuditFields(),
      ...actor.updatedAuditFields(),
      'createdAt': now,
      'updatedAt': now,
    });
    await _activity.log(
      type: 'todo_created',
      title: 'Added a to-do',
      body: trimmed,
      entityType: 'todo',
      entityId: ref.id,
    );
  }

  Future<void> setDone(String id, bool done) async {
    final actor = _team.currentActor();
    await _col.doc(id).update({
      'done': done,
      ...actor.updatedAuditFields(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _activity.log(
      type: done ? 'todo_completed' : 'todo_reopened',
      title: done ? 'Completed a to-do' : 'Reopened a to-do',
      entityType: 'todo',
      entityId: id,
    );
  }

  Future<void> delete(String id) => _col.doc(id).delete();
}
