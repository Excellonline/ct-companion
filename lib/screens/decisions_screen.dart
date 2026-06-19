import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/decision.dart';
import '../providers/decisions_provider.dart';
import '../providers/team_provider.dart';

class DecisionsScreen extends ConsumerWidget {
  final bool embedded;
  const DecisionsScreen({super.key, this.embedded = false});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    var titleText = '';
    var rationaleText = '';
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record decision'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Decision',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => titleText = value,
              ),
              const SizedBox(height: 12),
              TextField(
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Rationale / context',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => rationaleText = value,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != true || titleText.trim().isEmpty) return;
    await ref
        .read(decisionsServiceProvider)
        .createDecision(title: titleText, rationale: rationaleText);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decisionsAsync = ref.watch(decisionsProvider);
    final includeArchived = ref.watch(showArchivedDecisionsProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final body = Column(
      children: [
        if (embedded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Text(
                  'Decisions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    includeArchived
                        ? Icons.inventory_2
                        : Icons.inventory_2_outlined,
                  ),
                  tooltip: includeArchived ? 'Hide archived' : 'Show archived',
                  onPressed: () =>
                      ref.read(showArchivedDecisionsProvider.notifier).state =
                          !includeArchived,
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Record'),
                  onPressed: () => _create(context, ref),
                ),
              ],
            ),
          ),
        Expanded(
          child: decisionsAsync.when(
            data: (decisions) => decisions.isEmpty
                ? const _EmptyDecisions()
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: decisions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _DecisionTile(
                      decision: decisions[index],
                      isAdmin: isAdmin,
                    ),
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text('Failed to load decisions:\n$e')),
          ),
        ),
      ],
    );
    if (embedded) return body;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Decisions'),
        actions: [
          IconButton(
            icon: Icon(
              includeArchived ? Icons.inventory_2 : Icons.inventory_2_outlined,
            ),
            tooltip: includeArchived ? 'Hide archived' : 'Show archived',
            onPressed: () =>
                ref.read(showArchivedDecisionsProvider.notifier).state =
                    !includeArchived,
          ),
        ],
      ),
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.fact_check_outlined),
        label: const Text('Record'),
        onPressed: () => _create(context, ref),
      ),
    );
  }
}

class _DecisionTile extends ConsumerWidget {
  final Decision decision;
  final bool isAdmin;

  const _DecisionTile({required this.decision, required this.isAdmin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hint = Theme.of(context).hintColor;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(
          decision.isArchived
              ? Icons.inventory_2_outlined
              : Icons.fact_check_outlined,
        ),
        title: Text(decision.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (decision.rationale.isNotEmpty)
              Text(
                decision.rationale,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 4),
            Text(
              '${decision.createdByName} | ${DateFormat.MMMd().add_jm().format(decision.createdAt)}',
              style: TextStyle(color: hint, fontSize: 12),
            ),
          ],
        ),
        isThreeLine: decision.rationale.isNotEmpty,
        trailing: isAdmin
            ? IconButton(
                icon: Icon(
                  decision.isArchived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                ),
                tooltip: decision.isArchived ? 'Restore' : 'Archive',
                onPressed: () => ref
                    .read(decisionsServiceProvider)
                    .archiveDecision(
                      decision.id,
                      archived: !decision.isArchived,
                    ),
              )
            : null,
      ),
    );
  }
}

class _EmptyDecisions extends StatelessWidget {
  const _EmptyDecisions();

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fact_check_outlined, size: 64, color: hint),
          const SizedBox(height: 16),
          const Text('No decisions recorded'),
          const SizedBox(height: 4),
          Text(
            'Save important calls so the team keeps context',
            style: TextStyle(color: hint),
          ),
        ],
      ),
    );
  }
}
