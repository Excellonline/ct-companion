import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/chat_message.dart';
import '../models/chat_thread.dart';
import '../providers/chat_provider.dart';
import '../providers/team_provider.dart';

class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threadsAsync = ref.watch(chatThreadsProvider);
    final selectedId = ref.watch(selectedChatThreadIdProvider);

    return threadsAsync.when(
      data: (threads) {
        final effectiveId =
            selectedId ?? (threads.isNotEmpty ? threads.first.id : null);
        if (selectedId == null && effectiveId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(selectedChatThreadIdProvider.notifier).state = effectiveId;
          });
        }

        final size = MediaQuery.sizeOf(context);
        final messagesPane = effectiveId == null
            ? const _EmptyChat()
            : _MessagesPane(threadId: effectiveId);

        if (size.width < 600) {
          final threadPaneHeight = (size.height * 0.28)
              .clamp(136.0, 188.0)
              .toDouble();
          return Column(
            children: [
              SizedBox(
                height: threadPaneHeight,
                child: _ThreadsPane(threads: threads, selectedId: effectiveId),
              ),
              const Divider(height: 1),
              Expanded(child: messagesPane),
            ],
          );
        }

        return Row(
          children: [
            SizedBox(
              width: size.width < 720 ? 210 : 300,
              child: _ThreadsPane(threads: threads, selectedId: effectiveId),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: messagesPane),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Failed to load chat:\n$e', textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

class _ThreadsPane extends ConsumerWidget {
  final List<ChatThread> threads;
  final String? selectedId;

  const _ThreadsPane({required this.threads, required this.selectedId});

  Future<void> _createTopic(BuildContext context, WidgetRef ref) async {
    var topicName = '';
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New chat topic'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Topic name',
            border: OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.done,
          onChanged: (value) => topicName = value,
          onSubmitted: (value) => Navigator.pop(ctx, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, topicName.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (title == null || title.isEmpty) return;
    final id = await ref.read(chatServiceProvider).createThread(title);
    ref.read(selectedChatThreadIdProvider.notifier).state = id;
  }

  Future<void> _deleteTopic(
    BuildContext context,
    WidgetRef ref,
    ChatThread thread,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${thread.title}"?'),
        content: const Text(
          'The topic and its visible messages will be removed.',
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
    if (ok == true) {
      await ref.read(chatServiceProvider).deleteThread(thread.id);
      if (ref.read(selectedChatThreadIdProvider) == thread.id) {
        ref.read(selectedChatThreadIdProvider.notifier).state = null;
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Chat',
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_comment_outlined),
                tooltip: 'New topic',
                onPressed: () => _createTopic(context, ref),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: threads.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No topics yet', textAlign: TextAlign.center),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: threads.length,
                  itemBuilder: (ctx, index) {
                    final thread = threads[index];
                    final selected = thread.id == selectedId;
                    return ListTile(
                      selected: selected,
                      selectedTileColor: scheme.primary.withValues(alpha: 0.12),
                      leading: const Icon(Icons.forum_outlined),
                      title: Text(
                        thread.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: thread.lastMessagePreview.isEmpty
                          ? Text(
                              DateFormat.MMMd().format(thread.createdAt),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : Text(
                              thread.lastMessagePreview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                      trailing: isAdmin
                          ? IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Delete topic',
                              onPressed: () =>
                                  _deleteTopic(context, ref, thread),
                            )
                          : null,
                      onTap: () {
                        ref.read(selectedChatThreadIdProvider.notifier).state =
                            thread.id;
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _MessagesPane extends ConsumerStatefulWidget {
  final String threadId;
  const _MessagesPane({required this.threadId});

  @override
  ConsumerState<_MessagesPane> createState() => _MessagesPaneState();
}

class _MessagesPaneState extends ConsumerState<_MessagesPane> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  List<PlatformFile> _files = const [];
  ChatMessage? _replyTo;
  bool _sending = false;

  @override
  void didUpdateWidget(covariant _MessagesPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.threadId != widget.threadId) {
      _replyTo = null;
      _files = const [];
      _text.clear();
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _files = [..._files, ...result.files]);
  }

  Future<void> _send() async {
    if (_sending) return;
    if (_text.text.trim().isEmpty && _files.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(chatServiceProvider)
          .sendMessage(
            threadId: widget.threadId,
            text: _text.text,
            files: _files,
            replyTo: _replyTo,
          );
      _text.clear();
      setState(() {
        _files = const [];
        _replyTo = null;
      });
      _focus.requestFocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Message failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesProvider(widget.threadId));
    final currentUid = ref.watch(currentMemberProvider).valueOrNull?.uid;
    return Column(
      children: [
        Expanded(
          child: messagesAsync.when(
            data: (messages) => messages.isEmpty
                ? const _EmptyChat()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    itemCount: messages.length,
                    itemBuilder: (ctx, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _MessageBubble(
                        message: messages[index],
                        currentUid: currentUid,
                        onReply: (message) {
                          setState(() => _replyTo = message);
                          _focus.requestFocus();
                        },
                        onReaction: _toggleReaction,
                      ),
                    ),
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to load messages:\n$e',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_replyTo != null) ...[
                _ReplyComposerPreview(
                  message: _replyTo!,
                  onCancel: () => setState(() => _replyTo = null),
                ),
                const SizedBox(height: 8),
              ],
              if (_files.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final file in _files)
                      InputChip(
                        avatar: const Icon(Icons.attach_file, size: 16),
                        label: Text(file.name, overflow: TextOverflow.ellipsis),
                        onDeleted: () => setState(
                          () =>
                              _files = _files.where((f) => f != file).toList(),
                        ),
                      ),
                  ],
                ),
              if (_files.isNotEmpty) const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.attach_file),
                    tooltip: 'Attach files',
                    onPressed: _sending ? null : _pickFiles,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _text,
                      focusNode: _focus,
                      minLines: 1,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Message the team',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _sending ? null : _send,
                    style: FilledButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(14),
                    ),
                    child: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _toggleReaction(ChatMessage message, String reaction) async {
    try {
      await ref
          .read(chatServiceProvider)
          .toggleMessageReaction(
            threadId: widget.threadId,
            messageId: message.id,
            reaction: reaction,
          );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Reaction failed: $error')));
    }
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final String? currentUid;
  final ValueChanged<ChatMessage> onReply;
  final void Function(ChatMessage message, String reaction) onReaction;

  const _MessageBubble({
    required this.message,
    required this.currentUid,
    required this.onReply,
    required this.onReaction,
  });

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    final scheme = Theme.of(context).colorScheme;
    final currentReaction = message.reactionFor(currentUid);
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        message.senderName,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      DateFormat.MMMd().add_jm().format(message.createdAt),
                      style: TextStyle(fontSize: 11, color: hint),
                    ),
                  ],
                ),
                if (message.replyTo != null) ...[
                  const SizedBox(height: 8),
                  _ReplyReferenceCard(reply: message.replyTo!),
                ],
                if (message.text.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(message.text),
                ],
                if (message.attachments.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final attachment in message.attachments)
                        ActionChip(
                          avatar: const Icon(Icons.insert_drive_file, size: 16),
                          label: Text(attachment.name),
                          onPressed: () => _openAttachment(attachment),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _ReactionButton(
                      icon: currentReaction == 'up'
                          ? Icons.thumb_up_alt
                          : Icons.thumb_up_alt_outlined,
                      label: '${message.thumbsUpCount}',
                      tooltip: 'Thumbs up',
                      selected: currentReaction == 'up',
                      onPressed: () => onReaction(message, 'up'),
                    ),
                    _ReactionButton(
                      icon: currentReaction == 'down'
                          ? Icons.thumb_down_alt
                          : Icons.thumb_down_alt_outlined,
                      label: '${message.thumbsDownCount}',
                      tooltip: 'Thumbs down',
                      selected: currentReaction == 'down',
                      onPressed: () => onReaction(message, 'down'),
                    ),
                    TextButton.icon(
                      onPressed: () => onReply(message),
                      icon: const Icon(Icons.reply, size: 18),
                      label: const Text('Reply'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openAttachment(ChatAttachment attachment) async {
    final uri = Uri.tryParse(attachment.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _ReplyComposerPreview extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback onCancel;

  const _ReplyComposerPreview({required this.message, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: scheme.primary, width: 3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Replying to ${message.senderName}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _messagePreview(message),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cancel reply',
            onPressed: onCancel,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _ReplyReferenceCard extends StatelessWidget {
  final ChatReplyReference reply;

  const _ReplyReferenceCard({required this.reply});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: scheme.primary, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            reply.senderName,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            reply.text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
        ],
      ),
    );
  }
}

class _ReactionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final bool selected;
  final VoidCallback onPressed;

  const _ReactionButton({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.13)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? scheme.primary.withValues(alpha: 0.55)
                  : scheme.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}

String _messagePreview(ChatMessage message) {
  final text = message.text.trim();
  if (text.isNotEmpty) return text;
  if (message.attachments.isEmpty) return 'Message';
  if (message.attachments.length == 1) {
    return 'Attachment: ${message.attachments.single.name}';
  }
  return '${message.attachments.length} attachments';
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forum_outlined, size: 64, color: hint),
          const SizedBox(height: 16),
          const Text('No messages yet'),
          const SizedBox(height: 4),
          Text(
            'Start a topic or send an update',
            style: TextStyle(color: hint),
          ),
        ],
      ),
    );
  }
}
