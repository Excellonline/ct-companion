import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/notes_provider.dart';
import '../widgets/note_card.dart';
import 'editor_screen.dart';

class ArchiveScreen extends ConsumerWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesStreamProvider);
    final archived = ref.watch(archivedNotesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Archive')),
      body: notesAsync.when(
        data: (_) => archived.isEmpty
            ? const _EmptyArchive()
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: archived.length,
                itemBuilder: (ctx, index) {
                  final note = archived[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: NoteCard(
                            note: note,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EditorScreen(note: note),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.unarchive_outlined),
                          tooltip: 'Restore',
                          onPressed: () => ref
                              .read(notesServiceProvider)
                              .archiveNote(note.id, archived: false),
                        ),
                      ],
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load archive:\n$e')),
      ),
    );
  }
}

class _EmptyArchive extends StatelessWidget {
  const _EmptyArchive();

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: hint),
          const SizedBox(height: 16),
          const Text('Archive is empty'),
        ],
      ),
    );
  }
}
