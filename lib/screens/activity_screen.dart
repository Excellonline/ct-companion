import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/activity_item.dart';
import '../providers/activity_provider.dart';

class ActivityScreen extends ConsumerWidget {
  final bool embedded;
  const ActivityScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(activityStreamProvider);
    final body = activityAsync.when(
      data: (items) => items.isEmpty
          ? const _EmptyActivity()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) =>
                  _ActivityTile(item: items[index]),
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Failed to load activity:\n$e'),
        ),
      ),
    );
    if (embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: body,
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final ActivityItem item;
  const _ActivityTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 6),
      leading: CircleAvatar(child: Icon(_iconFor(item.type))),
      title: Text(item.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.body.isNotEmpty)
            Text(item.body, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(
            '${item.actorName} | ${DateFormat.MMMd().add_jm().format(item.createdAt)}',
            style: TextStyle(fontSize: 12, color: hint),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String type) {
    if (type.contains('pipeline')) return Icons.timeline;
    if (type.contains('chat')) return Icons.forum_outlined;
    if (type.contains('file')) return Icons.attach_file;
    if (type.contains('decision')) return Icons.fact_check_outlined;
    if (type.contains('comment')) return Icons.mode_comment_outlined;
    if (type.contains('archive')) return Icons.archive_outlined;
    return Icons.auto_awesome_motion_outlined;
  }
}

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity();

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_motion_outlined, size: 64, color: hint),
          const SizedBox(height: 16),
          const Text('No activity yet'),
          const SizedBox(height: 4),
          Text('Team updates will appear here', style: TextStyle(color: hint)),
        ],
      ),
    );
  }
}
