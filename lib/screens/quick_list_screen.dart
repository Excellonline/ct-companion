import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/quick_item.dart';
import '../providers/quick_list_provider.dart';
import '../providers/team_provider.dart';
import '../services/quick_list_service.dart';

/// Shared team checklist screen for the CardTrove workspace.
class QuickListScreen extends ConsumerStatefulWidget {
  final QuickListKind kind;
  const QuickListScreen({super.key, required this.kind});

  @override
  ConsumerState<QuickListScreen> createState() => _QuickListScreenState();
}

class _QuickListScreenState extends ConsumerState<QuickListScreen> {
  final _addCtl = TextEditingController();
  final _addFocus = FocusNode();
  bool _adding = false;

  @override
  void dispose() {
    _addCtl.dispose();
    _addFocus.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final text = _addCtl.text.trim();
    if (text.isEmpty) return;
    setState(() => _adding = true);
    try {
      await ref.read(quickListServiceProvider(widget.kind)).add(text);
      _addCtl.clear();
      _addFocus.requestFocus();
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(quickListItemsProvider(widget.kind));

    return Column(
      children: [
        Expanded(
          child: itemsAsync.when(
            data: (items) => items.isEmpty
                ? _Empty(label: widget.kind.label)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: items.length,
                    itemBuilder: (ctx, i) =>
                        _ItemTile(item: items[i], kind: widget.kind),
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Failed to load:\n$e', textAlign: TextAlign.center),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _addCtl,
                  focusNode: _addFocus,
                  decoration: InputDecoration(
                    hintText: 'Add a task',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _add(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _adding ? null : _add,
                style: FilledButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(14),
                ),
                child: _adding
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.add),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ItemTile extends ConsumerWidget {
  final QuickItem item;
  final QuickListKind kind;
  const _ItemTile({required this.item, required this.kind});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final svc = ref.read(quickListServiceProvider(kind));
    final isAdmin = ref.watch(isAdminProvider);
    return Dismissible(
      key: ValueKey(item.id),
      direction: isAdmin ? DismissDirection.endToStart : DismissDirection.none,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        color: Theme.of(context).colorScheme.error,
        child: Icon(Icons.delete, color: Theme.of(context).colorScheme.onError),
      ),
      onDismissed: isAdmin ? (_) => svc.delete(item.id) : null,
      child: ListTile(
        leading: Checkbox(
          value: item.done,
          onChanged: (v) => svc.setDone(item.id, v ?? false),
        ),
        title: Text(
          item.text,
          style: TextStyle(
            decoration: item.done ? TextDecoration.lineThrough : null,
            color: item.done ? Theme.of(context).hintColor : null,
          ),
        ),
        subtitle: item.createdByName?.isNotEmpty == true
            ? Text('Created by ${item.createdByName}')
            : null,
        trailing: isAdmin
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Delete',
                onPressed: () => svc.delete(item.id),
              )
            : null,
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String label;
  const _Empty({required this.label});

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: hint),
          const SizedBox(height: 16),
          Text('$label is empty'),
          const SizedBox(height: 4),
          Text('Add a task from the box below', style: TextStyle(color: hint)),
        ],
      ),
    );
  }
}
