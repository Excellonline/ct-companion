import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/shared_file.dart';
import '../providers/files_provider.dart';
import '../providers/team_provider.dart';

class FilesScreen extends ConsumerStatefulWidget {
  const FilesScreen({super.key});

  @override
  ConsumerState<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends ConsumerState<FilesScreen> {
  bool _uploading = false;

  Future<void> _upload() async {
    if (_uploading) return;
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() => _uploading = true);
    try {
      await ref.read(filesServiceProvider).uploadFiles(result.files);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filesAsync = ref.watch(sharedFilesProvider);
    final files = ref.watch(filteredSharedFilesProvider);
    final filter = ref.watch(sharedFilesFilterProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FilesHeader(
          filter: filter,
          uploading: _uploading,
          onUpload: _upload,
        ),
        const Divider(height: 1),
        Expanded(
          child: filesAsync.when(
            data: (_) => files.isEmpty
                ? _EmptyFiles(filter: filter)
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final grid = constraints.maxWidth >= 900;
                      if (!grid) {
                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: files.length,
                          itemBuilder: (context, index) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _FileTile(file: files[index]),
                          ),
                        );
                      }
                      return GridView.builder(
                        padding: const EdgeInsets.all(18),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 360,
                          mainAxisExtent: 150,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                        ),
                        itemCount: files.length,
                        itemBuilder: (context, index) =>
                            _FileTile(file: files[index]),
                      );
                    },
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Failed to load files:\n$e',
                    textAlign: TextAlign.center),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilesHeader extends ConsumerWidget {
  final SharedFilesFilter filter;
  final bool uploading;
  final VoidCallback onUpload;

  const _FilesHeader({
    required this.filter,
    required this.uploading,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Shared Files',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  'Docs, references, exports, and team handoffs',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).hintColor,
                      ),
                ),
              ],
            ),
          ),
          SegmentedButton<SharedFilesFilter>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: SharedFilesFilter.all,
                label: Text('All'),
                icon: Icon(Icons.inventory_2_outlined),
              ),
              ButtonSegment(
                value: SharedFilesFilter.docs,
                label: Text('Docs'),
                icon: Icon(Icons.description_outlined),
              ),
              ButtonSegment(
                value: SharedFilesFilter.files,
                label: Text('Files'),
                icon: Icon(Icons.folder_copy_outlined),
              ),
            ],
            selected: {filter},
            onSelectionChanged: (value) {
              ref.read(sharedFilesFilterProvider.notifier).state = value.single;
            },
          ),
          FilledButton.icon(
            icon: uploading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.upload_file),
            label: Text(uploading ? 'Uploading' : 'Upload'),
            onPressed: uploading ? null : onUpload,
          ),
        ],
      ),
    );
  }
}

class _FileTile extends ConsumerWidget {
  final SharedFile file;
  const _FileTile({required this.file});

  Future<void> _open() async {
    final uri = Uri.tryParse(file.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${file.name}"?'),
        content: const Text('The shared file record will be removed.'),
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
    if (ok == true) {
      await ref.read(filesServiceProvider).deleteFile(file);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    final scheme = Theme.of(context).colorScheme;
    final icon = file.kind == SharedFileKind.document
        ? Icons.description_outlined
        : Icons.insert_drive_file_outlined;
    return Card(
      child: InkWell(
        onTap: _open,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: scheme.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      file.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isAdmin)
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Delete file',
                      onPressed: () => _delete(context, ref),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                '${file.kind.label} | ${file.sizeLabel}',
                style:
                    TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
              ),
              const SizedBox(height: 4),
              Text(
                'Shared by ${file.createdByName} on ${DateFormat.MMMd().add_jm().format(file.createdAt)}',
                style:
                    TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyFiles extends StatelessWidget {
  final SharedFilesFilter filter;
  const _EmptyFiles({required this.filter});

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    final label = switch (filter) {
      SharedFilesFilter.all => 'No shared files yet',
      SharedFilesFilter.docs => 'No shared docs yet',
      SharedFilesFilter.files => 'No shared files in this view',
    };
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder_open_outlined, size: 64, color: hint),
                  const SizedBox(height: 16),
                  Text(label),
                  const SizedBox(height: 4),
                  Text(
                    'Upload references, exports, or team docs',
                    style: TextStyle(color: hint),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
