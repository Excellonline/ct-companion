import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/note_comment.dart';
import 'activity_service.dart';
import 'mentions_service.dart';
import 'team_service.dart';

class CommentsService {
  final _db = FirebaseFirestore.instance;
  final _team = TeamService();
  final _activity = ActivityService();
  final _mentions = MentionsService();

  DocumentReference<Map<String, dynamic>> get _workspaceRef =>
      _db.collection('workspaces').doc(cardTroveWorkspaceId);

  CollectionReference<Map<String, dynamic>> get _notesCol =>
      _workspaceRef.collection('notes');

  CollectionReference<Map<String, dynamic>> _commentsCol(String noteId) =>
      _notesCol.doc(noteId).collection('comments');

  Stream<List<NoteComment>> commentsStream(String noteId) =>
      _commentsCol(noteId).orderBy('createdAt').snapshots().map((s) =>
          s.docs.map((doc) => NoteComment.fromFirestore(noteId, doc)).toList());

  Future<void> addComment({
    required String noteId,
    required String noteTitle,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final actor = _team.currentActor();
    final ref = _commentsCol(noteId).doc();
    await ref.set({
      'text': trimmed,
      ...actor.createdAuditFields(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _notesCol.doc(noteId).set({
      'commentCount': FieldValue.increment(1),
      ...actor.updatedAuditFields(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _activity.log(
      type: 'comment',
      title: 'Commented on ${noteTitle.isEmpty ? "a note" : noteTitle}',
      body: trimmed,
      entityType: 'note',
      entityId: noteId,
    );
    await _mentions.notifyMentions(
      text: trimmed,
      title: '${actor.label} mentioned you',
      body: trimmed,
      entityType: 'note',
      entityId: noteId,
    );
  }

  Future<void> deleteComment(String noteId, String commentId) async {
    await _commentsCol(noteId).doc(commentId).delete();
    await _notesCol.doc(noteId).set({
      'commentCount': FieldValue.increment(-1),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
