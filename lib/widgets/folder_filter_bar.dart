import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/folders_provider.dart';
import '../providers/notes_provider.dart';

class FolderFilterBar extends ConsumerWidget {
  const FolderFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foldersAsync = ref.watch(foldersStreamProvider);
    final selected = ref.watch(folderFilterProvider);

    return foldersAsync.when(
      data: (folders) {
        if (folders.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: const Text('All'),
                  selected: selected == null,
                  onSelected: (_) =>
                      ref.read(folderFilterProvider.notifier).state = null,
                ),
              ),
              for (final f in folders)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(f.name),
                    selected: selected == f.id,
                    onSelected: (_) => ref
                        .read(folderFilterProvider.notifier)
                        .state = selected == f.id ? null : f.id,
                  ),
                ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(height: 44),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
