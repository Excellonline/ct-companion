import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/team_member.dart';
import '../providers/team_provider.dart';

class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(membersProvider);
    final currentMember = ref.watch(currentMemberProvider).valueOrNull;
    final isAdmin = currentMember?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Team & Roles')),
      body: membersAsync.when(
        data: (members) {
          final sortedMembers = [...members]..sort(_sortMembers);
          final admins = members.where((m) => m.isAdmin).length;
          final pending = members.where((m) => m.isPending).length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
            children: [
              _TeamSummary(
                members: members.length,
                admins: admins,
                pending: pending,
                currentRole: currentMember?.role.label ?? 'Member',
                canManage: isAdmin,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Members',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  if (pending > 0)
                    Chip(
                      avatar: const Icon(Icons.schedule, size: 18),
                      label: Text('$pending pending'),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (sortedMembers.isEmpty)
                const Center(child: Text('No team members yet'))
              else
                for (final member in sortedMembers)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _MemberRow(
                      member: member,
                      isSelf: member.uid == currentMember?.uid,
                      canManage: isAdmin,
                    ),
                  ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('$e', textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}

int _sortMembers(TeamMember a, TeamMember b) {
  final rank = {
    TeamRole.pending: 0,
    TeamRole.admin: 1,
    TeamRole.member: 2,
  };
  final roleCompare = rank[a.role]!.compareTo(rank[b.role]!);
  if (roleCompare != 0) return roleCompare;
  return a.label.toLowerCase().compareTo(b.label.toLowerCase());
}

class _TeamSummary extends StatelessWidget {
  final int members;
  final int admins;
  final int pending;
  final String currentRole;
  final bool canManage;

  const _TeamSummary({
    required this.members,
    required this.admins,
    required this.pending,
    required this.currentRole,
    required this.canManage,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 14,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _Metric(label: 'Members', value: '$members'),
          _Metric(label: 'Pending', value: '$pending'),
          _Metric(label: 'Admins', value: '$admins'),
          _Metric(label: 'Your role', value: currentRole),
          Chip(
            avatar: Icon(
              canManage ? Icons.lock_open_outlined : Icons.lock_outline,
              size: 18,
            ),
            label: Text(canManage ? 'Admin controls enabled' : 'View only'),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).hintColor,
                  letterSpacing: 0.7,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _MemberRow extends ConsumerWidget {
  final TeamMember member;
  final bool isSelf;
  final bool canManage;

  const _MemberRow({
    required this.member,
    required this.isSelf,
    required this.canManage,
  });

  Future<void> _runAction(
    BuildContext context,
    Future<void> Function() action,
    String successMessage,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _editDisplayName(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: member.displayName);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit member'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Display name'),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => Navigator.pop(ctx, controller.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (result == null) return;
    if (!context.mounted) return;
    await _runAction(
      context,
      () => isSelf
          ? ref.read(teamServiceProvider).updateCurrentUserDisplayName(result)
          : ref
              .read(teamServiceProvider)
              .updateMemberDisplayName(member.uid, result),
      'Member updated.',
    );
  }

  Future<void> _removeMember(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove workspace access?'),
        content: Text(
          '${member.label} will lose access to CardTrove Companion. Their Firebase sign-in account is not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.person_remove_outlined),
            label: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;

    await _runAction(
      context,
      () => ref.read(teamServiceProvider).removeMember(member.uid),
      'Workspace access removed.',
    );
  }

  Future<void> _setRole(
    BuildContext context,
    WidgetRef ref,
    TeamRole role,
  ) async {
    await _runAction(
      context,
      () => ref.read(teamServiceProvider).setMemberRole(member.uid, role),
      role == TeamRole.pending
          ? 'Member moved to pending.'
          : 'Member role updated.',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final icon = member.isAdmin
        ? Icons.admin_panel_settings_outlined
        : member.isPending
            ? Icons.person_add_alt_1_outlined
            : Icons.person_outline;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: member.isPending
                      ? scheme.tertiary.withValues(alpha: 0.14)
                      : scheme.primary.withValues(alpha: 0.13),
                  foregroundColor:
                      member.isPending ? scheme.tertiary : scheme.primary,
                  child: Icon(icon),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              member.label,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSelf) ...[
                            const SizedBox(width: 8),
                            const Chip(
                              label: Text('You'),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        member.email,
                        style: TextStyle(color: Theme.of(context).hintColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (member.lastSeenAt != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          'Last seen ${DateFormat.MMMd().add_jm().format(member.lastSeenAt!)}',
                          style: TextStyle(
                            color: Theme.of(context).hintColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Chip(label: Text(member.role.label)),
              ],
            ),
            if (canManage) ...[
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (member.isPending)
                    FilledButton.icon(
                      onPressed: () => _setRole(context, ref, TeamRole.member),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Approve'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => _editDisplayName(context, ref),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                  SizedBox(
                    width: 160,
                    child: DropdownButtonFormField<TeamRole>(
                      initialValue: member.role,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onChanged: isSelf
                          ? null
                          : (role) {
                              if (role == null || role == member.role) return;
                              _setRole(context, ref, role);
                            },
                      items: [
                        for (final role in TeamRole.values)
                          DropdownMenuItem(
                            value: role,
                            child: Text(role.label),
                          ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: isSelf ? 'You cannot remove yourself' : 'Remove',
                    onPressed:
                        isSelf ? null : () => _removeMember(context, ref),
                    icon: const Icon(Icons.person_remove_outlined),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
