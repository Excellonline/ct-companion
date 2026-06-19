import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/note.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback? onTogglePipeline;
  final bool showPipelineAudit;
  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    this.onTogglePipeline,
    this.showPipelineAudit = false,
  });

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    final priorityColor = _priorityColor(note.priority);
    final priorityBackground = Color.lerp(
      Theme.of(context).cardColor,
      priorityColor,
      0.16,
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      color: priorityBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: priorityColor.withValues(alpha: 0.55),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    note.type == NoteType.checklist
                        ? Icons.checklist
                        : Icons.notes,
                    size: 18,
                    color: hint,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      note.title.isEmpty ? '(untitled)' : note.title,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (note.pinned)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(Icons.push_pin, size: 16, color: hint),
                    ),
                  if (note.reminderAt != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(Icons.alarm, size: 16, color: hint),
                    ),
                  if (onTogglePipeline != null)
                    IconButton(
                      icon: Icon(
                        note.inPipeline ? Icons.task_alt : Icons.add_task,
                        size: 20,
                        color: note.inPipeline
                            ? Theme.of(context).colorScheme.primary
                            : hint,
                      ),
                      tooltip: note.inPipeline
                          ? 'Remove from pipeline'
                          : 'Add to pipeline',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      onPressed: onTogglePipeline,
                    ),
                ],
              ),
              if (note.type == NoteType.note &&
                  note.body.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(note.body, maxLines: 3, overflow: TextOverflow.ellipsis),
              ],
              if (note.type == NoteType.checklist && note.items.isNotEmpty) ...[
                const SizedBox(height: 6),
                ...note.items.take(4).map(
                      (i) => Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              i.done
                                  ? Icons.check_box
                                  : Icons.check_box_outline_blank,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                i.text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  decoration: i.done
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: i.done ? hint : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                if (note.items.length > 4)
                  Padding(
                    padding: const EdgeInsets.only(left: 22, top: 2),
                    child: Text(
                      '+ ${note.items.length - 4} more',
                      style: TextStyle(color: hint, fontSize: 12),
                    ),
                  ),
              ],
              if (note.attachments.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 56,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: note.attachments.length < 4
                        ? note.attachments.length
                        : 4,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final attachment = note.attachments[index];
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          width: 72,
                          height: 56,
                          child: _AttachmentThumb(attachment: attachment),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.flag,
                    size: 14,
                    color: priorityColor,
                  ),
                  const SizedBox(width: 6),
                  if (note.tags.isNotEmpty) ...[
                    Icon(Icons.label_outline, size: 14, color: hint),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        note.tags.join(', '),
                        style: TextStyle(fontSize: 12, color: hint),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ] else
                    const Spacer(),
                  Text(
                    DateFormat.MMMd().add_jm().format(note.updatedAt),
                    style: TextStyle(fontSize: 11, color: hint),
                  ),
                ],
              ),
              if (note.ownerUid != null || note.dueAt != null) ...[
                const SizedBox(height: 6),
                Text(
                  [
                    if (note.ownerUid != null) 'Owner: ${note.ownerLabel}',
                    if (note.dueAt != null)
                      'Due ${DateFormat.MMMd().add_jm().format(note.dueAt!)}',
                  ].join(' | '),
                  style: TextStyle(
                    fontSize: 11,
                    color: note.dueAt != null &&
                            note.dueAt!.isBefore(DateTime.now())
                        ? Theme.of(context).colorScheme.error
                        : hint,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (showPipelineAudit) ...[
                const SizedBox(height: 6),
                Text(
                  'Created by ${note.createdByLabel} | Updated by ${note.updatedByLabel}',
                  style: TextStyle(fontSize: 11, color: hint),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _priorityColor(NotePriority priority) {
    switch (priority) {
      case NotePriority.low:
        return Colors.green.shade600;
      case NotePriority.medium:
        return Colors.amber.shade700;
      case NotePriority.high:
        return Colors.red.shade600;
    }
  }
}

class _AttachmentThumb extends StatelessWidget {
  final NoteAttachment attachment;

  const _AttachmentThumb({required this.attachment});

  @override
  Widget build(BuildContext context) {
    final dataBase64 = attachment.dataBase64;
    if (attachment.isImage && dataBase64 != null && dataBase64.isNotEmpty) {
      return Image.memory(
        base64Decode(dataBase64),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _AttachmentThumbFallback(),
      );
    }
    if (attachment.isImage && attachment.url.isNotEmpty) {
      return Image.network(
        attachment.url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _AttachmentThumbFallback(),
      );
    }
    return const _AttachmentThumbFallback();
  }
}

class _AttachmentThumbFallback extends StatelessWidget {
  const _AttachmentThumbFallback();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.image_outlined, size: 18)),
    );
  }
}
