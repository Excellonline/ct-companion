// Pure tests for the Note + ChecklistItem models.
// We round-trip toFirestore() -> a Map -> manually re-read into a Note to
// verify nothing is silently lost or coerced.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cardtrove_companion/models/note.dart';

void main() {
  group('ChecklistItem', () {
    test('toMap / fromMap roundtrip', () {
      final item = ChecklistItem(id: 'abc', text: 'buy milk', done: true);
      final map = item.toMap();
      final roundtripped = ChecklistItem.fromMap(map);
      expect(roundtripped.id, item.id);
      expect(roundtripped.text, item.text);
      expect(roundtripped.done, item.done);
    });

    test('copyWith preserves id', () {
      final item = ChecklistItem(id: 'abc', text: 'old', done: false);
      final updated = item.copyWith(text: 'new', done: true);
      expect(updated.id, 'abc');
      expect(updated.text, 'new');
      expect(updated.done, true);
    });

    test('fromMap is defensive against missing fields', () {
      final item = ChecklistItem.fromMap({'id': 'x'});
      expect(item.id, 'x');
      expect(item.text, '');
      expect(item.done, false);
    });
  });

  group('Note.toFirestore', () {
    final base = Note(
      id: 'note-1',
      title: 'Trip',
      body: 'Pack light',
      type: NoteType.note,
      items: const [],
      tags: const ['travel', 'urgent'],
      folderId: 'folder-1',
      reminderAt: DateTime(2026, 5, 10, 9, 0),
      priority: NotePriority.high,
      pinned: true,
      ownerUid: null,
      ownerName: null,
      ownerEmail: null,
      dueAt: null,
      archivedAt: null,
      inInbox: false,
      pipelineAddedAt: null,
      pipelineStage: null,
      createdByUid: 'user-1',
      createdByName: 'Sev',
      createdByEmail: 'sev@example.com',
      updatedByUid: 'user-1',
      updatedByName: 'Sev',
      updatedByEmail: 'sev@example.com',
      createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 5),
    );

    test('preserves scalar fields', () {
      final m = base.toFirestore();
      expect(m['title'], 'Trip');
      expect(m['body'], 'Pack light');
      expect(m['type'], 'note');
      expect(m['folderId'], 'folder-1');
      expect(m['priority'], 'high');
      expect(m['pinned'], true);
      expect(m['tags'], ['travel', 'urgent']);
    });

    test('encodes DateTime as Timestamp', () {
      final m = base.toFirestore();
      expect(m['reminderAt'], isA<Timestamp>());
      expect(m['createdAt'], isA<Timestamp>());
      expect(m['updatedAt'], isA<Timestamp>());
      expect(
          (m['reminderAt'] as Timestamp).toDate(), DateTime(2026, 5, 10, 9, 0));
    });

    test('null reminderAt stays null', () {
      final note = Note(
        id: 'x',
        title: '',
        body: '',
        type: NoteType.note,
        items: const [],
        tags: const [],
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
        pipelineAddedAt: null,
        pipelineStage: null,
        createdByUid: null,
        createdByName: null,
        createdByEmail: null,
        updatedByUid: null,
        updatedByName: null,
        updatedByEmail: null,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      expect(note.toFirestore()['reminderAt'], isNull);
    });

    test('checklist items serialize to list of maps', () {
      final checklist = Note(
        id: 'c',
        title: 'Supplies',
        body: '',
        type: NoteType.checklist,
        items: [
          ChecklistItem(id: '1', text: 'eggs', done: false),
          ChecklistItem(id: '2', text: 'bread', done: true),
        ],
        tags: const [],
        folderId: null,
        reminderAt: null,
        priority: NotePriority.low,
        pinned: false,
        ownerUid: null,
        ownerName: null,
        ownerEmail: null,
        dueAt: null,
        archivedAt: null,
        inInbox: false,
        pipelineAddedAt: null,
        pipelineStage: null,
        createdByUid: null,
        createdByName: null,
        createdByEmail: null,
        updatedByUid: null,
        updatedByName: null,
        updatedByEmail: null,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      final m = checklist.toFirestore();
      expect(m['type'], 'checklist');
      expect(m['items'], hasLength(2));
      expect((m['items'] as List)[0]['text'], 'eggs');
      expect((m['items'] as List)[1]['done'], true);
    });

    test('image attachments serialize to list of maps', () {
      final note = Note(
        id: 'with-image',
        title: 'Counter issue',
        body: '',
        type: NoteType.note,
        items: const [],
        attachments: [
          NoteAttachment(
            id: 'image-1',
            name: 'counter-marked.png',
            url: 'https://example.com/counter-marked.png',
            storagePath: 'workspaces/cardtrove-team/notes/note/image.png',
            sizeBytes: 2048,
            contentType: 'image/png',
            createdAt: DateTime(2026, 6, 14),
          ),
        ],
        tags: const [],
        folderId: null,
        reminderAt: null,
        priority: NotePriority.low,
        pinned: false,
        ownerUid: null,
        ownerName: null,
        ownerEmail: null,
        dueAt: null,
        archivedAt: null,
        inInbox: false,
        pipelineAddedAt: null,
        pipelineStage: null,
        createdByUid: null,
        createdByName: null,
        createdByEmail: null,
        updatedByUid: null,
        updatedByName: null,
        updatedByEmail: null,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      final attachments = note.toFirestore()['attachments'] as List;
      expect(attachments, hasLength(1));
      expect(attachments.single['name'], 'counter-marked.png');
      expect(attachments.single['contentType'], 'image/png');
      expect(attachments.single['createdAt'], isA<Timestamp>());
    });
  });

  group('Note.empty', () {
    test('produces a valid blank note', () {
      final n = Note.empty(id: 'new', type: NoteType.checklist);
      expect(n.id, 'new');
      expect(n.type, NoteType.checklist);
      expect(n.title, '');
      expect(n.items, isEmpty);
      expect(n.tags, isEmpty);
      expect(n.priority, NotePriority.medium);
      expect(n.pinned, false);
    });
  });

  group('NotePriority', () {
    test('fromId falls back to medium for old or unknown data', () {
      expect(NotePriority.fromId(null), NotePriority.medium);
      expect(NotePriority.fromId('surprise'), NotePriority.medium);
    });

    test('fromId reads saved priority ids', () {
      expect(NotePriority.fromId('low'), NotePriority.low);
      expect(NotePriority.fromId('medium'), NotePriority.medium);
      expect(NotePriority.fromId('high'), NotePriority.high);
    });
  });
}
