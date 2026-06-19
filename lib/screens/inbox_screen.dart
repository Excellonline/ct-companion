import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../widgets/note_card.dart';
import 'editor_screen.dart';

class InboxScreen extends ConsumerWidget {
  final bool embedded;
  const InboxScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesStreamProvider);
    final inbox = ref.watch(inboxNotesProvider);
    void newIdea() => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const EditorScreen(
          initialType: NoteType.note,
          initialInInbox: true,
        ),
      ),
    );

    final body = notesAsync.when(
      data: (_) => inbox.isEmpty
          ? _EmptyInbox(onNewIdea: newIdea)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: inbox.length,
              itemBuilder: (ctx, index) {
                final note = inbox[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: NoteCard(
                    note: note,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditorScreen(note: note),
                      ),
                    ),
                    onTogglePipeline: () => ref
                        .read(notesServiceProvider)
                        .promoteInboxToPipeline(note.id),
                  ),
                );
              },
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Failed to load inbox:\n$e')),
    );
    if (embedded) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Text(
                  'Idea Inbox',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                FilledButton.icon(
                  icon: const Icon(Icons.lightbulb_outline),
                  label: const Text('New idea'),
                  onPressed: newIdea,
                ),
              ],
            ),
          ),
          Expanded(child: body),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Idea Inbox')),
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.lightbulb_outline),
        label: const Text('New idea'),
        onPressed: newIdea,
      ),
    );
  }
}

class _EmptyInbox extends StatelessWidget {
  final VoidCallback onNewIdea;

  const _EmptyInbox({required this.onNewIdea});

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: hint),
          const SizedBox(height: 16),
          const Text('No inbox ideas'),
          const SizedBox(height: 4),
          Text(
            'Capture rough ideas before they become pipeline work',
            style: TextStyle(color: hint),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.lightbulb_outline),
            label: const Text('New idea'),
            onPressed: onNewIdea,
          ),
        ],
      ),
    );
  }
}
