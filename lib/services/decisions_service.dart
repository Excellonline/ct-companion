import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/decision.dart';
import 'activity_service.dart';
import 'mentions_service.dart';
import 'team_service.dart';

class DecisionsService {
  final _db = FirebaseFirestore.instance;
  final _team = TeamService();
  final _activity = ActivityService();
  final _mentions = MentionsService();

  DocumentReference<Map<String, dynamic>> get _workspaceRef =>
      _db.collection('workspaces').doc(cardTroveWorkspaceId);

  CollectionReference<Map<String, dynamic>> get _decisionsCol =>
      _workspaceRef.collection('decisions');

  Stream<List<Decision>> decisionsStream({bool includeArchived = false}) =>
      _decisionsCol
          .orderBy('updatedAt', descending: true)
          .snapshots()
          .map(
            (s) => s.docs
                .map(Decision.fromFirestore)
                .where((d) => includeArchived || !d.isArchived)
                .toList(),
          );

  Future<void> createDecision({
    required String title,
    required String rationale,
  }) async {
    final trimmedTitle = title.trim();
    final trimmedRationale = rationale.trim();
    if (trimmedTitle.isEmpty) {
      throw ArgumentError('Decision title is required.');
    }

    final actor = _team.currentActor();
    final now = FieldValue.serverTimestamp();
    final ref = _decisionsCol.doc();
    await ref.set({
      'title': trimmedTitle,
      'rationale': trimmedRationale,
      'archivedAt': null,
      ...actor.createdAuditFields(),
      ...actor.updatedAuditFields(),
      'createdAt': now,
      'updatedAt': now,
    });
    await _activity.log(
      type: 'decision',
      title: 'Recorded a decision',
      body: trimmedTitle,
      entityType: 'decision',
      entityId: ref.id,
    );
    await _mentions.notifyMentions(
      text: '$trimmedTitle $trimmedRationale',
      title: '${actor.label} mentioned you in a decision',
      body: trimmedTitle,
      entityType: 'decision',
      entityId: ref.id,
    );
  }

  Future<void> archiveDecision(String id, {required bool archived}) async {
    final actor = _team.currentActor();
    await _decisionsCol.doc(id).set({
      'archivedAt': archived ? FieldValue.serverTimestamp() : null,
      ...actor.updatedAuditFields(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
