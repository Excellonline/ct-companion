import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/activity_item.dart';
import 'team_service.dart';

class ActivityService {
  final _db = FirebaseFirestore.instance;
  final _team = TeamService();

  DocumentReference<Map<String, dynamic>> get _workspaceRef =>
      _db.collection('workspaces').doc(cardTroveWorkspaceId);

  CollectionReference<Map<String, dynamic>> get _activityCol =>
      _workspaceRef.collection('activity');

  Stream<List<ActivityItem>> activityStream() => _activityCol
      .orderBy('createdAt', descending: true)
      .limit(150)
      .snapshots()
      .map((s) => s.docs.map(ActivityItem.fromFirestore).toList());

  Future<void> log({
    required String type,
    required String title,
    String body = '',
    required String entityType,
    required String entityId,
  }) async {
    final actor = _team.currentActor();
    await _activityCol.add({
      'type': type,
      'title': title,
      'body': body,
      'entityType': entityType,
      'entityId': entityId,
      'actorUid': actor.uid,
      'actorName': actor.label,
      'actorEmail': actor.email,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
