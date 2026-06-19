import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.done_all),
            label: const Text('Mark read'),
            onPressed: () =>
                ref.read(notificationsServiceProvider).markAllRead(),
          ),
        ],
      ),
      body: notificationsAsync.when(
        data: (items) => items.isEmpty
            ? const _EmptyNotifications()
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ListTile(
                    leading: Icon(
                      item.read
                          ? Icons.notifications_none
                          : Icons.notifications_active,
                    ),
                    title: Text(item.title),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.body.isNotEmpty)
                          Text(item.body,
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                        Text(
                          DateFormat.MMMd().add_jm().format(item.createdAt),
                          style: TextStyle(
                            color: Theme.of(context).hintColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    onTap: () => ref
                        .read(notificationsServiceProvider)
                        .markRead(item.id),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('Failed to load notifications:\n$e')),
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none, size: 64, color: hint),
          const SizedBox(height: 16),
          const Text('All caught up'),
          const SizedBox(height: 4),
          Text('Mentions and team alerts will show here',
              style: TextStyle(color: hint)),
        ],
      ),
    );
  }
}
