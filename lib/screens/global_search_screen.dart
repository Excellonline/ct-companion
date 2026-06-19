import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/note.dart';
import '../providers/chat_provider.dart';
import '../providers/decisions_provider.dart';
import '../providers/files_provider.dart';
import '../providers/notes_provider.dart';
import '../providers/quick_list_provider.dart';
import '../services/quick_list_service.dart';
import 'editor_screen.dart';

class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(notesStreamProvider).valueOrNull ?? const <Note>[];
    final files = ref.watch(sharedFilesProvider).valueOrNull ?? const [];
    final decisions = ref.watch(decisionsProvider).valueOrNull ?? const [];
    final threads = ref.watch(chatThreadsProvider).valueOrNull ?? const [];
    final todos =
        ref.watch(quickListItemsProvider(QuickListKind.todo)).valueOrNull ??
            const [];
    final q = _query.text.trim().toLowerCase();

    final results = <_SearchResult>[];
    if (q.isNotEmpty) {
      for (final note in notes.where((n) => !n.isArchived)) {
        if (_matches([
          note.title,
          note.body,
          note.ownerLabel,
          ...note.tags,
          ...note.items.map((i) => i.text),
        ], q)) {
          results.add(_SearchResult(
            icon: note.inPipeline ? Icons.timeline : Icons.notes,
            type: note.inInbox ? 'Idea' : 'Note',
            title: note.title.isEmpty ? '(untitled)' : note.title,
            subtitle: note.body,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => EditorScreen(note: note)),
            ),
          ));
        }
      }
      for (final todo in todos) {
        if (_matches([todo.text], q)) {
          results.add(_SearchResult(
            icon: todo.done ? Icons.task_alt : Icons.radio_button_unchecked,
            type: 'To-Do',
            title: todo.text,
            subtitle: todo.done ? 'Completed' : 'Open',
          ));
        }
      }
      for (final file in files) {
        if (_matches([file.name, file.createdByName], q)) {
          results.add(_SearchResult(
            icon: Icons.attach_file,
            type: file.kind.label,
            title: file.name,
            subtitle: file.createdByName,
            onTap: () => _openUrl(file.url),
          ));
        }
      }
      for (final decision in decisions) {
        if (_matches([decision.title, decision.rationale], q)) {
          results.add(_SearchResult(
            icon: Icons.fact_check_outlined,
            type: 'Decision',
            title: decision.title,
            subtitle: decision.rationale,
          ));
        }
      }
      for (final thread in threads) {
        if (_matches([thread.title, thread.lastMessagePreview], q)) {
          results.add(_SearchResult(
            icon: Icons.forum_outlined,
            type: 'Chat',
            title: thread.title,
            subtitle: thread.lastMessagePreview,
            onTap: () {
              ref.read(selectedChatThreadIdProvider.notifier).state = thread.id;
              Navigator.pop(context);
            },
          ));
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _query,
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search notes, todos, files, decisions, chat',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                suffixIcon: q.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(_query.clear),
                      ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: q.isEmpty
                ? const _SearchPrompt()
                : results.isEmpty
                    ? const Center(child: Text('No results'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: results.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) =>
                            _ResultTile(result: results[index]),
                      ),
          ),
        ],
      ),
    );
  }

  bool _matches(List<String> values, String query) {
    return values.any((value) => value.toLowerCase().contains(query));
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _SearchResult {
  final IconData icon;
  final String type;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  _SearchResult({
    required this.icon,
    required this.type,
    required this.title,
    required this.subtitle,
    this.onTap,
  });
}

class _ResultTile extends StatelessWidget {
  final _SearchResult result;
  const _ResultTile({required this.result});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(result.icon),
      title: Text(result.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${result.type}${result.subtitle.isEmpty ? "" : " | ${result.subtitle}"}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: result.onTap,
    );
  }
}

class _SearchPrompt extends StatelessWidget {
  const _SearchPrompt();

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.manage_search, size: 64, color: hint),
          const SizedBox(height: 16),
          const Text('Search the team workspace'),
        ],
      ),
    );
  }
}
