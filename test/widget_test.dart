// Smoke tests for CardTrove Companion.
//
// The full app boots Firebase, which requires a real Firebase project, so we
// only test pure logic here (no widget tests that would need Firebase mocks).

import 'package:flutter_test/flutter_test.dart';
import 'package:cardtrove_companion/models/note.dart';
import 'package:cardtrove_companion/services/search_service.dart';

void main() {
  group('SearchService.filter', () {
    final notes = <Note>[
      Note(
        id: '1',
        title: 'Supplies',
        body: 'sleeves, labels, boxes',
        type: NoteType.note,
        items: const [],
        attachments: [
          NoteAttachment(
            id: 'image-1',
            name: 'display-case-marked.png',
            url: 'https://example.com/display-case-marked.png',
            storagePath: 'workspaces/cardtrove-team/notes/1/image.png',
            sizeBytes: 1024,
            contentType: 'image/png',
            createdAt: DateTime(2026, 1, 1),
          ),
        ],
        tags: const ['shopping'],
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
      ),
      Note(
        id: '2',
        title: 'Project ideas',
        body: '',
        type: NoteType.checklist,
        items: [ChecklistItem(id: 'a', text: 'Build a notes app', done: false)],
        tags: const [],
        folderId: null,
        reminderAt: null,
        priority: NotePriority.high,
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
        createdAt: DateTime(2026, 1, 2),
        updatedAt: DateTime(2026, 1, 2),
      ),
    ];

    test('empty query returns all', () {
      expect(SearchService.filter(notes, '').length, 2);
    });

    test('matches title', () {
      expect(SearchService.filter(notes, 'sup').length, 1);
    });

    test('matches body', () {
      expect(SearchService.filter(notes, 'labels').single.id, '1');
    });

    test('matches tag', () {
      expect(SearchService.filter(notes, 'shopping').single.id, '1');
    });

    test('matches checklist item', () {
      expect(SearchService.filter(notes, 'notes app').single.id, '2');
    });

    test('matches attachment file name', () {
      expect(SearchService.filter(notes, 'display-case').single.id, '1');
    });

    test('case insensitive', () {
      expect(SearchService.filter(notes, 'SUPPLIES').length, 1);
    });
  });
}
