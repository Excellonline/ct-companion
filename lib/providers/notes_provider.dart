import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/note.dart';
import '../services/notes_service.dart';
import '../services/search_service.dart';
import 'auth_provider.dart';
import 'settings_provider.dart';
import 'team_provider.dart';

final notesServiceProvider = Provider<NotesService>((ref) => NotesService());

final notesStreamProvider = StreamProvider<List<Note>>((ref) {
  // Recreate when auth changes so signing out doesn't leave a broken stream.
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream<List<Note>>.value(const []);
  ref.watch(memberBootstrapProvider);
  return ref.watch(notesServiceProvider).notesStream();
});

final searchQueryProvider = StateProvider<String>((ref) => '');
final folderFilterProvider = StateProvider<String?>((ref) => null);

/// Notes currently in the pipeline, sorted by when they were added (newest first).
final pipelineNotesProvider = Provider<List<Note>>((ref) {
  final notesAsync = ref.watch(notesStreamProvider);
  return notesAsync.maybeWhen(
    data: (notes) {
      final list = notes.where((n) => n.inPipeline && !n.isArchived).toList()
        ..sort((a, b) {
          if (a.pinned && !b.pinned) return -1;
          if (!a.pinned && b.pinned) return 1;
          return b.pipelineAddedAt!.compareTo(a.pipelineAddedAt!);
        });
      return list;
    },
    orElse: () => const <Note>[],
  );
});

/// Notes grouped by pipeline stage, each list sorted newest-first.
final pipelineByStageProvider = Provider<Map<PipelineStage, List<Note>>>((ref) {
  final notes = ref.watch(pipelineNotesProvider);
  final grouped = <PipelineStage, List<Note>>{
    for (final s in PipelineStage.values) s: <Note>[],
  };
  for (final n in notes) {
    final stage = n.pipelineStage ?? PipelineStage.ideas;
    grouped[stage]!.add(n);
  }
  return grouped;
});

final inboxNotesProvider = Provider<List<Note>>((ref) {
  final notesAsync = ref.watch(notesStreamProvider);
  return notesAsync.maybeWhen(
    data: (notes) {
      final list = notes.where((n) => n.inInbox && !n.isArchived).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return list;
    },
    orElse: () => const <Note>[],
  );
});

final archivedNotesProvider = Provider<List<Note>>((ref) {
  final notesAsync = ref.watch(notesStreamProvider);
  return notesAsync.maybeWhen(
    data: (notes) {
      final list = notes.where((n) => n.isArchived).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return list;
    },
    orElse: () => const <Note>[],
  );
});

final filteredNotesProvider = Provider<List<Note>>((ref) {
  final notesAsync = ref.watch(notesStreamProvider);
  final query = ref.watch(searchQueryProvider);
  final folder = ref.watch(folderFilterProvider);
  final sort = ref.watch(sortOrderProvider);

  return notesAsync.maybeWhen(
    data: (notes) {
      var list = notes.where((n) => !n.isArchived && !n.inInbox).toList();
      if (folder != null) {
        list = list.where((n) => n.folderId == folder).toList();
      }
      list = SearchService.filter(list, query);
      list = [...list]
        ..sort((a, b) {
          if (a.pinned && !b.pinned) return -1;
          if (!a.pinned && b.pinned) return 1;
          switch (sort) {
            case SortOrder.updatedDesc:
              return b.updatedAt.compareTo(a.updatedAt);
            case SortOrder.createdDesc:
              return b.createdAt.compareTo(a.createdAt);
            case SortOrder.titleAsc:
              return a.title.toLowerCase().compareTo(b.title.toLowerCase());
          }
        });
      return list;
    },
    orElse: () => const <Note>[],
  );
});
