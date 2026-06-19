import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/folders_provider.dart';
import '../providers/notes_provider.dart';
import '../providers/team_provider.dart';

class FoldersScreen extends ConsumerWidget {
  const FoldersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foldersAsync = ref.watch(foldersStreamProvider);
    final svc = ref.read(notesServiceProvider);
    final isAdmin = ref.watch(isAdminProvider);

    Future<void> addFolder() async {
      var folderName = '';
      final name = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('New folder'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Folder name'),
            onChanged: (value) => folderName = value,
            onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, folderName.trim()),
              child: const Text('Create'),
            ),
          ],
        ),
      );
      if (name != null && name.isNotEmpty) {
        await svc.createFolder(name, '#3F51B5');
      }
    }

    Future<void> confirmDelete(String id, String name) async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Delete "$name"?'),
          content: const Text(
            'Notes in this folder will remain but lose the folder.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (ok == true) await svc.deleteFolder(id);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Folders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New folder',
            onPressed: addFolder,
          ),
        ],
      ),
      body: foldersAsync.when(
        data: (folders) => folders.isEmpty
            ? const Center(child: Text('No folders yet'))
            : ListView.builder(
                itemCount: folders.length,
                itemBuilder: (_, i) {
                  final f = folders[i];
                  return ListTile(
                    leading: const Icon(Icons.folder),
                    title: Text(f.name),
                    trailing: isAdmin
                        ? IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => confirmDelete(f.id, f.name),
                          )
                        : null,
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}
