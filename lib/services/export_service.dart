import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'team_service.dart';

class ExportService {
  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _workspaceRef =>
      _db.collection('workspaces').doc(cardTroveWorkspaceId);

  Future<String> buildBackupJson() async {
    final notes = await _readCollection('notes');
    final todos = await _readCollection('todoItems');
    final files = await _readCollection('sharedFiles');
    final decisions = await _readCollection('decisions');
    final members = await _readCollection('members');
    final activity = await _readCollection('activity');
    final threadsSnapshot = await _workspaceRef
        .collection('chatThreads')
        .orderBy('updatedAt')
        .get();

    final threads = <Map<String, dynamic>>[];
    for (final thread in threadsSnapshot.docs) {
      final messages = await thread.reference
          .collection('messages')
          .orderBy('createdAt')
          .get();
      threads.add({
        'id': thread.id,
        ..._cleanMap(thread.data()),
        'messages': [
          for (final message in messages.docs)
            {'id': message.id, ..._cleanMap(message.data())},
        ],
      });
    }

    final backup = {
      'workspaceId': cardTroveWorkspaceId,
      'exportedAt': DateTime.now().toIso8601String(),
      'notes': notes,
      'todoItems': todos,
      'sharedFiles': files,
      'decisions': decisions,
      'members': members,
      'activity': activity,
      'chatThreads': threads,
    };

    return const JsonEncoder.withIndent('  ').convert(backup);
  }

  Future<List<Map<String, dynamic>>> _readCollection(String name) async {
    final snapshot = await _workspaceRef.collection(name).get();
    return [
      for (final doc in snapshot.docs) {'id': doc.id, ..._cleanMap(doc.data())},
    ];
  }

  Map<String, dynamic> _cleanMap(Map<String, dynamic> map) => {
        for (final entry in map.entries) entry.key: _cleanValue(entry.value),
      };

  Object? _cleanValue(Object? value) {
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is DocumentReference) return value.path;
    if (value is Iterable) return value.map(_cleanValue).toList();
    if (value is Map) {
      return {
        for (final entry in value.entries)
          entry.key.toString(): _cleanValue(entry.value),
      };
    }
    return value;
  }
}
