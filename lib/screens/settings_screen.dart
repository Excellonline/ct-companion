import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../providers/settings_provider.dart';
import '../providers/team_provider.dart';
import '../services/credential_store.dart';
import '../services/update_service.dart';
import 'archive_screen.dart';
import 'export_screen.dart';
import 'team_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _updateService = const UpdateService();
  UpdateCheckResult? _updateResult;
  String? _updateError;
  bool _checkingForUpdates = false;
  bool _openingUpdater = false;
  bool _savingDisplayName = false;

  Future<void> _checkForUpdates() async {
    setState(() {
      _checkingForUpdates = true;
      _updateError = null;
    });

    try {
      final result = await _updateService.checkForUpdates();
      if (!mounted) return;
      setState(() {
        _updateResult = result;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _updateError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _checkingForUpdates = false;
        });
      }
    }
  }

  Future<void> _downloadUpdate() async {
    final result = _updateResult;
    if (result == null || result.status != UpdateCheckStatus.available) {
      await _checkForUpdates();
      return;
    }

    setState(() {
      _openingUpdater = true;
      _updateError = null;
    });

    try {
      final launchMode = await _updateService.downloadAndInstall(result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            launchMode == UpdateLaunchMode.nativeUpdater
                ? 'Update window opened. If nothing appears, use the downloads page.'
                : 'Download page opened in your browser.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _updateError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _openingUpdater = false;
        });
      }
    }
  }

  Future<void> _editDisplayName(String currentName) async {
    final controller = TextEditingController(text: currentName);
    final nextName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change display name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Display name',
            helperText: 'Used on notes, comments, chat, and activity.',
          ),
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

    final trimmed = nextName?.trim();
    if (trimmed == null) return;
    if (trimmed.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Display name cannot be empty.')),
      );
      return;
    }
    if (trimmed == currentName.trim()) return;

    setState(() {
      _savingDisplayName = true;
    });
    try {
      await ref.read(teamServiceProvider).updateCurrentUserDisplayName(trimmed);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Display name updated.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) {
        setState(() {
          _savingDisplayName = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final sort = ref.watch(sortOrderProvider);
    final member = ref.watch(currentMemberProvider).valueOrNull;
    final isAdmin = member?.isAdmin ?? false;
    final user = FirebaseAuth.instance.currentUser;
    final authDisplayName = user?.displayName?.trim() ?? '';
    final memberDisplayName = member?.displayName.trim() ?? '';
    final displayName = memberDisplayName.isNotEmpty
        ? memberDisplayName
        : authDisplayName.isNotEmpty
        ? authDisplayName
        : '';

    Future<void> confirmSignOut() async {
      final navigator = Navigator.of(context);
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Sign out?'),
          content: const Text(
            'Shared CardTrove notes, todos, chat, and pipeline items will stay synced in the cloud.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sign out'),
            ),
          ],
        ),
      );
      if (ok == true) {
        await CredentialStore.clear();
        await FirebaseAuth.instance.signOut();
        navigator.pop();
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Account'),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Signed in as'),
            subtitle: Text(user?.email ?? '(unknown)'),
          ),
          ListTile(
            leading: const Icon(Icons.drive_file_rename_outline),
            title: const Text('Display name'),
            subtitle: Text(
              displayName.isEmpty ? 'Tap to set display name' : displayName,
            ),
            trailing: _savingDisplayName
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.edit_outlined),
            onTap: _savingDisplayName
                ? null
                : () => _editDisplayName(displayName),
          ),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('Workspace role'),
            subtitle: Text(member?.role.label ?? 'Member'),
          ),
          ListTile(
            leading: const Icon(Icons.groups_outlined),
            title: const Text('Team & Roles'),
            subtitle: const Text(
              'Approve users, edit profiles, and manage roles',
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TeamScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: const Text('Archive'),
            subtitle: const Text('Restore archived notes'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ArchiveScreen()),
            ),
          ),
          if (isAdmin)
            ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: const Text('Backup Export'),
              subtitle: const Text('Copy a JSON backup of the workspace'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExportScreen()),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: confirmSignOut,
          ),
          const Divider(),
          const _SectionHeader('Appearance'),
          RadioGroup<ThemeMode>(
            groupValue: themeMode,
            onChanged: (v) {
              if (v != null) ref.read(themeModeProvider.notifier).set(v);
            },
            child: const Column(
              children: [
                RadioListTile<ThemeMode>(
                  title: Text('Follow system'),
                  value: ThemeMode.system,
                ),
                RadioListTile<ThemeMode>(
                  title: Text('Light'),
                  value: ThemeMode.light,
                ),
                RadioListTile<ThemeMode>(
                  title: Text('Dark'),
                  value: ThemeMode.dark,
                ),
              ],
            ),
          ),
          const Divider(),
          const _SectionHeader('Sort'),
          RadioGroup<SortOrder>(
            groupValue: sort,
            onChanged: (v) {
              if (v != null) ref.read(sortOrderProvider.notifier).set(v);
            },
            child: const Column(
              children: [
                RadioListTile<SortOrder>(
                  title: Text('Recently updated'),
                  value: SortOrder.updatedDesc,
                ),
                RadioListTile<SortOrder>(
                  title: Text('Recently created'),
                  value: SortOrder.createdDesc,
                ),
                RadioListTile<SortOrder>(
                  title: Text('Title (A-Z)'),
                  value: SortOrder.titleAsc,
                ),
              ],
            ),
          ),
          const Divider(),
          const _SectionHeader('About'),
          if (UpdateService.isDesktopUpdateSupported) ...[
            _DesktopUpdateTile(
              result: _updateResult,
              error: _updateError,
              isChecking: _checkingForUpdates,
              isOpening: _openingUpdater,
              onCheck: _checkForUpdates,
              onDownload: _downloadUpdate,
            ),
            const Divider(),
          ],
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final info = snapshot.data;
              return ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('CardTrove Companion'),
                subtitle: Text(
                  info == null
                      ? 'Loading...\nBuilt for CardTrove'
                      : 'Version ${info.version} (build ${info.buildNumber})\nBuilt for CardTrove',
                ),
                isThreeLine: true,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DesktopUpdateTile extends StatelessWidget {
  final UpdateCheckResult? result;
  final String? error;
  final bool isChecking;
  final bool isOpening;
  final VoidCallback onCheck;
  final VoidCallback onDownload;

  const _DesktopUpdateTile({
    required this.result,
    required this.error,
    required this.isChecking,
    required this.isOpening,
    required this.onCheck,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final hasUpdate = result?.status == UpdateCheckStatus.available;
    final isUpToDate = result?.status == UpdateCheckStatus.upToDate;
    final busy = isChecking || isOpening;

    return ListTile(
      leading: const Icon(Icons.system_update_alt_outlined),
      title: const Text('Desktop updates'),
      subtitle: Text(_subtitle),
      isThreeLine: true,
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 144),
        child: FilledButton.icon(
          onPressed: busy || isUpToDate
              ? null
              : hasUpdate
              ? onDownload
              : onCheck,
          icon: busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(hasUpdate ? Icons.download_outlined : Icons.search),
          label: Text(_buttonLabel),
        ),
      ),
    );
  }

  String get _buttonLabel {
    if (isChecking) {
      return 'Checking...';
    }
    if (isOpening) {
      return 'Opening...';
    }
    if (result?.status == UpdateCheckStatus.available) {
      return 'Download update';
    }
    if (result?.status == UpdateCheckStatus.upToDate) {
      return 'Up to date';
    }
    if (error != null) {
      return 'Search again';
    }
    return 'Search for updates';
  }

  String get _subtitle {
    final result = this.result;
    final error = this.error;

    if (isChecking) {
      return 'Checking cardtrove.help for the newest desktop release.';
    }
    if (isOpening) {
      return 'Opening the desktop updater for the newest release.';
    }
    if (error != null) {
      return error;
    }
    if (result?.status == UpdateCheckStatus.available) {
      final latest = result?.release?.displayVersion ?? 'a newer version';
      return 'Update available: $latest.\nCurrent: ${result?.currentDisplayVersion ?? 'unknown'}.';
    }
    if (result?.status == UpdateCheckStatus.upToDate) {
      final current = result?.currentDisplayVersion ?? 'this version';
      return 'Current: $current.\nNo newer desktop release is available.';
    }
    return 'Check for the latest macOS or Windows release.';
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
