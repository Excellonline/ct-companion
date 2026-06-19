import 'dart:convert';
import 'dart:io' show File, Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;

import '../models/chat_message.dart';
import '../models/chat_thread.dart';
import 'activity_service.dart';
import 'mentions_service.dart';
import 'team_service.dart';

class ChatService {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _team = TeamService();
  final _activity = ActivityService();
  final _mentions = MentionsService();

  DocumentReference<Map<String, dynamic>> get _workspaceRef =>
      _db.collection('workspaces').doc(cardTroveWorkspaceId);

  CollectionReference<Map<String, dynamic>> get _threadsCol =>
      _workspaceRef.collection('chatThreads');

  CollectionReference<Map<String, dynamic>> _messagesCol(String threadId) =>
      _threadsCol.doc(threadId).collection('messages');

  Stream<List<ChatThread>> threadsStream() => _threadsCol
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(ChatThread.fromFirestore).toList());

  Stream<List<ChatMessage>> messagesStream(String threadId) =>
      _messagesCol(threadId)
          .orderBy('createdAt')
          .snapshots()
          .map((s) => s.docs.map(ChatMessage.fromFirestore).toList());

  Future<String> createThread(String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) throw ArgumentError('Topic title is required.');
    final actor = _team.currentActor();
    final now = FieldValue.serverTimestamp();
    final ref = _threadsCol.doc();
    await ref.set({
      'title': trimmed,
      ...actor.createdAuditFields(),
      ...actor.updatedAuditFields(),
      'lastMessagePreview': '',
      'createdAt': now,
      'updatedAt': now,
    });
    await _activity.log(
      type: 'chat_topic',
      title: 'Created chat topic',
      body: trimmed,
      entityType: 'chatThread',
      entityId: ref.id,
    );
    return ref.id;
  }

  Future<void> sendMessage({
    required String threadId,
    required String text,
    required List<PlatformFile> files,
    ChatMessage? replyTo,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && files.isEmpty) return;

    final actor = _team.currentActor();
    final messageRef = _messagesCol(threadId).doc();
    final attachments = <ChatAttachment>[];

    for (final file in files) {
      attachments.add(await _uploadAttachment(threadId, messageRef.id, file));
    }

    final now = FieldValue.serverTimestamp();
    final preview = trimmed.isNotEmpty
        ? trimmed
        : attachments.length == 1
        ? 'Shared ${attachments.single.name}'
        : 'Shared ${attachments.length} attachments';

    final batch = _db.batch();
    batch.set(messageRef, {
      'text': trimmed,
      'senderUid': actor.uid,
      'senderName': actor.label,
      'senderEmail': actor.email,
      'attachments': attachments.map((a) => a.toMap()).toList(),
      if (replyTo != null)
        'replyTo': ChatReplyReference(
          messageId: replyTo.id,
          senderName: replyTo.senderName,
          text: _replyPreview(replyTo),
        ).toMap(),
      'createdAt': now,
    });
    batch.set(_threadsCol.doc(threadId), {
      ...actor.updatedAuditFields(),
      'lastMessagePreview': preview,
      'updatedAt': now,
    }, SetOptions(merge: true));
    await batch.commit();
    await _activity.log(
      type: 'chat_message',
      title: 'Posted in chat',
      body: preview,
      entityType: 'chatThread',
      entityId: threadId,
    );
    await _mentions.notifyMentions(
      text: trimmed,
      title: '${actor.label} mentioned you in chat',
      body: preview,
      entityType: 'chatThread',
      entityId: threadId,
    );
  }

  Future<void> toggleMessageReaction({
    required String threadId,
    required String messageId,
    required String reaction,
  }) async {
    if (reaction != 'up' && reaction != 'down') {
      throw ArgumentError('Unsupported reaction.');
    }

    final actor = _team.currentActor();
    final ref = _messagesCol(threadId).doc(messageId);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final data = snapshot.data() ?? const <String, dynamic>{};
      final reactions = Map<String, dynamic>.from(
        data['reactions'] as Map? ?? const {},
      );
      final existing = reactions[actor.uid];
      final existingType = existing is Map
          ? existing['type'] as String?
          : existing is String
          ? existing
          : null;

      if (existingType == reaction) {
        transaction.update(ref, {
          'reactions.${actor.uid}': FieldValue.delete(),
        });
        return;
      }

      transaction.update(ref, {
        'reactions.${actor.uid}': {
          'type': reaction,
          'displayName': actor.label,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      });
    });
  }

  Future<void> deleteThread(String threadId) async {
    final messages = await _messagesCol(threadId).limit(450).get();
    final batch = _db.batch();
    for (final doc in messages.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_threadsCol.doc(threadId));
    await batch.commit();
  }

  String _replyPreview(ChatMessage message) {
    final text = message.text.trim();
    if (text.isNotEmpty) {
      return text.length > 160 ? '${text.substring(0, 157)}...' : text;
    }
    if (message.attachments.isEmpty) return 'Message';
    if (message.attachments.length == 1) {
      return 'Attachment: ${message.attachments.single.name}';
    }
    return '${message.attachments.length} attachments';
  }

  Future<ChatAttachment> _uploadAttachment(
    String threadId,
    String messageId,
    PlatformFile file,
  ) async {
    final safeName = _safeFileName(file.name);
    final storagePath =
        'workspaces/$cardTroveWorkspaceId/chat/$threadId/$messageId/$safeName';
    if (Platform.isWindows) {
      return _uploadAttachmentViaRest(storagePath, file);
    }

    final ref = _storage.ref(storagePath);
    final metadata = SettableMetadata(
      customMetadata: {
        'originalName': file.name,
        'workspaceId': cardTroveWorkspaceId,
        'threadId': threadId,
        'messageId': messageId,
      },
    );

    if (file.bytes != null) {
      await ref.putData(file.bytes!, metadata);
    } else if (file.path != null) {
      await ref.putFile(File(file.path!), metadata);
    } else {
      throw StateError('Could not read ${file.name}.');
    }

    return ChatAttachment(
      name: file.name,
      url: await ref.getDownloadURL(),
      storagePath: storagePath,
      sizeBytes: file.size,
      contentType: null,
    );
  }

  Future<ChatAttachment> _uploadAttachmentViaRest(
    String storagePath,
    PlatformFile file,
  ) async {
    final bucket = Firebase.app().options.storageBucket;
    if (bucket == null || bucket.isEmpty) {
      throw StateError('Firebase Storage bucket is not configured.');
    }

    final user = FirebaseAuth.instance.currentUser;
    final idToken = await user?.getIdToken();
    if (idToken == null) throw StateError('Not signed in.');

    final bytes =
        file.bytes ??
        (file.path == null ? null : await File(file.path!).readAsBytes());
    if (bytes == null) throw StateError('Could not read ${file.name}.');

    final uri = Uri.https('firebasestorage.googleapis.com', '/v0/b/$bucket/o', {
      'uploadType': 'media',
      'name': storagePath,
    });

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

    return ChatAttachment(
      name: file.name,
      url: downloadUrl,
      storagePath: storagePath,
      sizeBytes: file.size,
      contentType: null,
    );
  }

  String _safeFileName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    return cleaned.isEmpty ? 'attachment' : cleaned;
  }
}
