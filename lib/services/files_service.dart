import 'dart:convert';
import 'dart:io' show File, Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;

import '../models/shared_file.dart';
import 'activity_service.dart';
import 'team_service.dart';

class _UploadedFile {
  final String url;
  final String storagePath;
  final int sizeBytes;
  final String? contentType;

  _UploadedFile({
    required this.url,
    required this.storagePath,
    required this.sizeBytes,
    required this.contentType,
  });
}

class FilesService {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _team = TeamService();
  final _activity = ActivityService();

  DocumentReference<Map<String, dynamic>> get _workspaceRef =>
      _db.collection('workspaces').doc(cardTroveWorkspaceId);

  CollectionReference<Map<String, dynamic>> get _filesCol =>
      _workspaceRef.collection('sharedFiles');

  Stream<List<SharedFile>> filesStream() => _filesCol
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(SharedFile.fromFirestore).toList());

  Future<void> uploadFiles(List<PlatformFile> files) async {
    if (files.isEmpty) return;
    final actor = _team.currentActor();

    for (final file in files) {
      final doc = _filesCol.doc();
      final kind = SharedFileKind.fromName(file.name);
      final uploaded = await _upload(file, doc.id);
      await doc.set({
        'name': file.name,
        'url': uploaded.url,
        'storagePath': uploaded.storagePath,
        'sizeBytes': uploaded.sizeBytes,
        'contentType': uploaded.contentType,
        'kind': kind.id,
        ...actor.createdAuditFields(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      await _activity.log(
        type: 'file_uploaded',
        title: 'Uploaded ${file.name}',
        entityType: 'sharedFile',
        entityId: doc.id,
      );
    }
  }

  Future<void> deleteFile(SharedFile file) async {
    await _filesCol.doc(file.id).delete();
    if (file.storagePath.isEmpty) return;
    if (Platform.isWindows) {
      await _deleteViaRest(file.storagePath);
    } else {
      await _storage.ref(file.storagePath).delete();
    }
  }

  Future<_UploadedFile> _upload(PlatformFile file, String fileId) async {
    final safeName = _safeFileName(file.name);
    final storagePath =
        'workspaces/$cardTroveWorkspaceId/shared-files/$fileId/$safeName';
    if (Platform.isWindows) {
      return _uploadViaRest(file, storagePath);
    }

    final ref = _storage.ref(storagePath);
    final metadata = SettableMetadata(customMetadata: {
      'originalName': file.name,
      'workspaceId': cardTroveWorkspaceId,
      'sharedFileId': fileId,
    });

    if (file.bytes != null) {
      await ref.putData(file.bytes!, metadata);
    } else if (file.path != null) {
      await ref.putFile(File(file.path!), metadata);
    } else {
      throw StateError('Could not read ${file.name}.');
    }

    return _UploadedFile(
      url: await ref.getDownloadURL(),
      storagePath: storagePath,
      sizeBytes: file.size,
      contentType: null,
    );
  }

  Future<_UploadedFile> _uploadViaRest(
    PlatformFile file,
    String storagePath,
  ) async {
    final bucket = Firebase.app().options.storageBucket;
    if (bucket == null || bucket.isEmpty) {
      throw StateError('Firebase Storage bucket is not configured.');
    }

    final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (idToken == null) throw StateError('Not signed in.');

    final bytes = file.bytes ??
        (file.path == null ? null : await File(file.path!).readAsBytes());
    if (bytes == null) throw StateError('Could not read ${file.name}.');

    final uri = Uri.https(
      'firebasestorage.googleapis.com',
      '/v0/b/$bucket/o',
      {
        'uploadType': 'media',
        'name': storagePath,
      },
    );

    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/octet-stream',
      },
      body: bytes,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Storage upload failed: ${response.body}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final token = body['downloadTokens'] as String?;
    final encodedPath = Uri.encodeComponent(storagePath);
    final downloadUrl = token == null || token.isEmpty
        ? 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encodedPath?alt=media'
        : 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encodedPath?alt=media&token=$token';

    return _UploadedFile(
      url: downloadUrl,
      storagePath: storagePath,
      sizeBytes: file.size,
      contentType: null,
    );
  }

  Future<void> _deleteViaRest(String storagePath) async {
    final bucket = Firebase.app().options.storageBucket;
    final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (bucket == null || bucket.isEmpty || idToken == null) return;
    final uri = Uri.https(
      'firebasestorage.googleapis.com',
      '/v0/b/$bucket/o/${Uri.encodeComponent(storagePath)}',
    );
    await http.delete(uri, headers: {'Authorization': 'Bearer $idToken'});
  }

  String _safeFileName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    return cleaned.isEmpty ? 'shared-file' : cleaned;
  }
}
