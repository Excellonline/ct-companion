import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/live_share.dart';
import '../models/note.dart';
import 'activity_service.dart';
import 'image_data_service.dart';
import 'notes_service.dart';
import 'team_service.dart';

class LiveShareService {
  final _db = FirebaseFirestore.instance;
  final _team = TeamService();
  final _activity = ActivityService();
  final _notes = NotesService();
  final _uuid = const Uuid();

  DocumentReference<Map<String, dynamic>> get _workspaceRef =>
      _db.collection('workspaces').doc(cardTroveWorkspaceId);

  CollectionReference<Map<String, dynamic>> get _boardsCol =>
      _workspaceRef.collection('liveShares');

  CollectionReference<Map<String, dynamic>> _strokesCol(String boardId) =>
      _boardsCol.doc(boardId).collection('strokes');

  Stream<List<LiveShareBoard>> boardsStream() => _boardsCol
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(LiveShareBoard.fromFirestore).toList());

  Stream<LiveShareBoard?> boardStream(String boardId) => _boardsCol
      .doc(boardId)
      .snapshots()
      .map((doc) => doc.exists ? LiveShareBoard.fromFirestore(doc) : null);

  Stream<List<LiveShareStroke>> strokesStream(String boardId) =>
      _strokesCol(boardId)
          .orderBy('createdAt')
          .snapshots()
          .map((s) => s.docs.map(LiveShareStroke.fromFirestore).toList());

  Future<String> createBoard({String title = 'Untitled live share'}) async {
    final actor = _team.currentActor();
    final ref = _boardsCol.doc();
    final now = FieldValue.serverTimestamp();
    await ref.set({
      'title': title,
      'imageName': '',
      'imageDataBase64': '',
      'imageMimeType': 'image/jpeg',
      'imageWidth': 0,
      'imageHeight': 0,
      ...actor.createdAuditFields(),
      ...actor.updatedAuditFields(),
      'savedAt': null,
      'createdAt': now,
      'updatedAt': now,
    });
    await _activity.log(
      type: 'live_share_created',
      title: 'Started a live share',
      body: title,
      entityType: 'liveShare',
      entityId: ref.id,
    );
    return ref.id;
  }

  Future<void> updateBoardTitle(String boardId, String title) async {
    final actor = _team.currentActor();
    await _boardsCol.doc(boardId).set({
      'title': title.trim().isEmpty ? 'Untitled live share' : title.trim(),
      ...actor.updatedAuditFields(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateBoardImage({
    required String boardId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final actor = _team.currentActor();
    final prepared = ImageDataService.prepareForRealtime(bytes);
    await _boardsCol.doc(boardId).set({
      'imageName': fileName,
      'imageDataBase64': base64Encode(prepared.bytes),
      'imageMimeType': prepared.mimeType,
      'imageWidth': prepared.width,
      'imageHeight': prepared.height,
      ...actor.updatedAuditFields(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> saveBoard(String boardId) async {
    final actor = _team.currentActor();
    await _boardsCol.doc(boardId).set({
      ...actor.updatedAuditFields(),
      'savedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  String newStrokeId(String boardId) => _strokesCol(boardId).doc().id;

  Future<void> upsertStroke(String boardId, LiveShareStroke stroke) async {
    await _strokesCol(
      boardId,
    ).doc(stroke.id).set(stroke.toFirestore(), SetOptions(merge: true));
    final actor = _team.currentActor();
    await _boardsCol.doc(boardId).set({
      ...actor.updatedAuditFields(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteStroke(String boardId, String strokeId) async {
    await _strokesCol(boardId).doc(strokeId).delete();
  }

  Future<void> clearStrokes(String boardId) async {
    final strokes = await _strokesCol(boardId).limit(450).get();
    final batch = _db.batch();
    for (final doc in strokes.docs) {
      batch.delete(doc.reference);
    }
    batch.set(_boardsCol.doc(boardId), {
      ..._team.currentActor().updatedAuditFields(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  Future<String> pushToPipeline({
    required LiveShareBoard board,
    required Uint8List renderedBytes,
  }) async {
    final prepared = ImageDataService.prepareForRealtime(renderedBytes);
    final now = DateTime.now();
    final noteId = _uuid.v4();
    final title = board.title.trim().isEmpty
        ? 'Live Share markup'
        : board.title;
    final note = Note(
      id: noteId,
      title: title,
      body:
          'Pushed from Live Share. Open Live Share to continue collaborating on the original board.',
      type: NoteType.note,
      items: const [],
      attachments: [
        NoteAttachment(
          id: _uuid.v4(),
          name: '${_safeFileName(title)}-live-share.jpg',
          url: '',
          storagePath: '',
          dataBase64: base64Encode(prepared.bytes),
          sizeBytes: prepared.bytes.length,
          contentType: prepared.mimeType,
          createdAt: now,
        ),
      ],
      tags: const ['live-share'],
      folderId: null,
      reminderAt: null,
      priority: NotePriority.medium,
      pinned: false,
      ownerUid: null,
      ownerName: null,
      ownerEmail: null,
      dueAt: null,
      archivedAt: null,
      inInbox: false,
      pipelineAddedAt: now,
      pipelineStage: PipelineStage.ideas,
      createdByUid: null,
      createdByName: null,
      createdByEmail: null,
      updatedByUid: null,
      updatedByName: null,
      updatedByEmail: null,
      createdAt: now,
      updatedAt: now,
    );
    await _notes.upsertNote(note);
    await _activity.log(
      type: 'live_share_pushed',
      title: 'Pushed a live share to pipeline',
      body: title,
      entityType: 'note',
      entityId: noteId,
    );
    return noteId;
  }

  String _safeFileName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    return cleaned.isEmpty ? 'live-share' : cleaned;
  }
}
