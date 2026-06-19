import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;

import '../models/folder.dart';
import '../models/note.dart';
import 'activity_service.dart';
import 'team_service.dart';

class NotesService {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _team = TeamService();
  final _activity = ActivityService();

  void _requireSignedIn() {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) throw StateError('Not signed in');
  }

  DocumentReference<Map<String, dynamic>> get _workspaceRef =>
      _db.collection('workspaces').doc(cardTroveWorkspaceId);

  CollectionReference<Map<String, dynamic>> get _notesCol =>
      _workspaceRef.collection('notes');

  CollectionReference<Map<String, dynamic>> get _foldersCol =>
      _workspaceRef.collection('folders');

  Stream<List<Note>> notesStream() => _notesCol
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Note.fromFirestore).toList());

  Stream<List<Folder>> foldersStream() => _foldersCol
      .orderBy('name')
      .snapshots()
      .map((s) => s.docs.map(Folder.fromFirestore).toList());

  Future<void> upsertNote(Note note) async {
    _requireSignedIn();
    final actor = _team.currentActor();
    final isNew = note.createdByUid == null;
    final data = note.toFirestore();
    data.addAll(actor.updatedAuditFields());
    data['updatedAt'] = FieldValue.serverTimestamp();
    if (note.createdByUid == null) {
      data.addAll(actor.createdAuditFields());
      data['createdAt'] = FieldValue.serverTimestamp();
    }
    await _notesCol.doc(note.id).set(data);
    await _activity.log(
      type: isNew ? 'note_created' : 'note_updated',
      title: isNew ? 'Created a note' : 'Updated a note',
      body: note.title.isEmpty ? 'Untitled note' : note.title,
      entityType: 'note',
      entityId: note.id,
    );
  }

  Future<NoteAttachment> uploadImageAttachment({
    required String noteId,
    required String name,
    required Uint8List bytes,
    String contentType = 'image/png',
  }) async {
    _requireSignedIn();
    final attachmentId = _notesCol.doc().id;
    final safeName = _safeFileName(name);
    final storagePath =
        'workspaces/$cardTroveWorkspaceId/notes/$noteId/$attachmentId/$safeName';

    if (Platform.isWindows) {
      return _uploadImageAttachmentViaRest(
        attachmentId: attachmentId,
        name: name,
        storagePath: storagePath,
        bytes: bytes,
        contentType: contentType,
      );
    }

    final ref = _storage.ref(storagePath);
    try {
      await ref.putData(
        bytes,
        SettableMetadata(
          contentType: contentType,
          customMetadata: {
            'originalName': name,
            'workspaceId': cardTroveWorkspaceId,
            'noteId': noteId,
            'attachmentId': attachmentId,
          },
        ),
      );
    } on FirebaseException catch (error) {
      throw StateError(_storageFailureMessage(error.message ?? error.code));
    }

    return NoteAttachment(
      id: attachmentId,
      name: name,
      url: await ref.getDownloadURL(),
      storagePath: storagePath,
      sizeBytes: bytes.length,
      contentType: contentType,
      createdAt: DateTime.now(),
    );
  }

  Future<void> deleteNote(String id) {
    _requireSignedIn();
    return _notesCol.doc(id).delete();
  }

  /// Add the note to the pipeline (sets pipelineAddedAt to now and defaults to
  /// the Ideas stage) or remove it (both fields cleared).
  Future<void> togglePipeline(String id, {required bool add}) async {
    final actor = _team.currentActor();
    await _notesCol.doc(id).update({
      'pipelineAddedAt': add ? FieldValue.serverTimestamp() : null,
      'pipelineStage': add ? PipelineStage.ideas.id : null,
      'inInbox': add ? false : FieldValue.delete(),
      ...actor.updatedAuditFields(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _activity.log(
      type: add ? 'pipeline_added' : 'pipeline_removed',
      title: add ? 'Added a note to pipeline' : 'Removed a note from pipeline',
      entityType: 'note',
      entityId: id,
    );
  }

  /// Move a note to a different pipeline stage.
  Future<void> setPipelineStage(String id, PipelineStage stage) async {
    final actor = _team.currentActor();
    await _notesCol.doc(id).update({
      'pipelineStage': stage.id,
      ...actor.updatedAuditFields(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _activity.log(
      type: 'pipeline_moved',
      title: 'Moved a pipeline card to ${stage.label}',
      entityType: 'note',
      entityId: id,
    );
  }

  Future<void> archiveNote(String id, {required bool archived}) async {
    final actor = _team.currentActor();
    await _notesCol.doc(id).set({
      'archivedAt': archived ? FieldValue.serverTimestamp() : null,
      ...actor.updatedAuditFields(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _activity.log(
      type: archived ? 'note_archived' : 'note_restored',
      title: archived ? 'Archived a note' : 'Restored a note',
      entityType: 'note',
      entityId: id,
    );
  }

  Future<void> promoteInboxToPipeline(String id) async {
    final actor = _team.currentActor();
    await _notesCol.doc(id).set({
      'inInbox': false,
      'pipelineAddedAt': FieldValue.serverTimestamp(),
      'pipelineStage': PipelineStage.ideas.id,
      ...actor.updatedAuditFields(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _activity.log(
      type: 'inbox_promoted',
      title: 'Promoted an idea to pipeline',
      entityType: 'note',
      entityId: id,
    );
  }

  Future<String> createFolder(String name, String color) async {
    final ref = _foldersCol.doc();
    final f = Folder(
      id: ref.id,
      name: name,
      color: color,
      createdAt: DateTime.now(),
    );
    await ref.set(f.toFirestore());
    return ref.id;
  }

  Future<void> deleteFolder(String id) async {
    final batch = _db.batch();
    final affected = await _notesCol.where('folderId', isEqualTo: id).get();
    for (final d in affected.docs) {
      batch.update(d.reference, {'folderId': null});
    }
    batch.delete(_foldersCol.doc(id));
    await batch.commit();
  }

  Future<NoteAttachment> _uploadImageAttachmentViaRest({
    required String attachmentId,
    required String name,
    required String storagePath,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final bucket = Firebase.app().options.storageBucket;
    if (bucket == null || bucket.isEmpty) {
      throw StateError('Firebase Storage bucket is not configured.');
    }

    final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (idToken == null) throw StateError('Not signed in.');

    final uri = Uri.https('firebasestorage.googleapis.com', '/v0/b/$bucket/o', {
      'uploadType': 'media',
      'name': storagePath,
    });

    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': contentType,
      },
      body: bytes,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(_storageFailureMessage(response.body));
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final token = body['downloadTokens'] as String?;
    final encodedPath = Uri.encodeComponent(storagePath);
    final downloadUrl = token == null || token.isEmpty
        ? 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encodedPath?alt=media'
        : 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encodedPath?alt=media&token=$token';

    return NoteAttachment(
      id: attachmentId,
      name: name,
      url: downloadUrl,
      storagePath: storagePath,
      sizeBytes: bytes.length,
      contentType: contentType,
      createdAt: DateTime.now(),
    );
  }

  String _safeFileName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    return cleaned.isEmpty ? 'note-image.png' : cleaned;
  }

  String _storageFailureMessage(String detail) {
    final lower = detail.toLowerCase();
    if (lower.contains('bucket') ||
        lower.contains('not found') ||
        lower.contains('not been set up')) {
      return 'Firebase Storage is not set up for CardTrove yet. Enable Storage in Firebase, then try attaching images again.';
    }
    return 'Image upload failed: $detail';
  }
}
