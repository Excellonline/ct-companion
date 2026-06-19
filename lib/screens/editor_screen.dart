import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../models/folder.dart';
import '../models/note.dart';
import '../models/team_member.dart';
import '../providers/comments_provider.dart';
import '../providers/folders_provider.dart';
import '../providers/notes_provider.dart';
import '../providers/team_provider.dart';
import '../widgets/checklist_item_tile.dart';
import '../widgets/reminder_picker.dart';
import 'image_markup_screen.dart';

class EditorScreen extends ConsumerStatefulWidget {
  final Note? note;
  final NoteType initialType;
  final bool initialInPipeline;
  final PipelineStage initialPipelineStage;
  final String? initialTitle;
  final String? initialBody;
  final bool initialInInbox;

  const EditorScreen({
    super.key,
    this.note,
    this.initialType = NoteType.note,
    this.initialInPipeline = false,
    this.initialPipelineStage = PipelineStage.ideas,
    this.initialTitle,
    this.initialBody,
    this.initialInInbox = false,
  });

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  final _uuid = const Uuid();
  late final String _id;
  late final TextEditingController _title;
  late final TextEditingController _body;
  late final TextEditingController _tagInput;
  late NoteType _type;
  late List<ChecklistItem> _items;
  late List<_EditableNoteAttachment> _attachments;
  late List<String> _tags;
  late String? _folderId;
  late DateTime? _reminderAt;
  late NotePriority _priority;
  late bool _pinned;
  late String? _ownerUid;
  late String? _ownerName;
  late String? _ownerEmail;
  late DateTime? _dueAt;
  late DateTime? _archivedAt;
  late bool _inInbox;
  late DateTime? _pipelineAddedAt;
  late PipelineStage? _pipelineStage;
  late final DateTime _createdAt;
  bool _dirty = false;
  bool _saving = false;
  bool _closing = false;
  int? _newItemIndex;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    final n = widget.note;
    _id = n?.id ?? _uuid.v4();
    _title = TextEditingController(text: n?.title ?? widget.initialTitle ?? '');
    _body = TextEditingController(text: n?.body ?? widget.initialBody ?? '');
    _tagInput = TextEditingController();
    _type = n?.type ?? widget.initialType;
    _items = List<ChecklistItem>.from(n?.items ?? const []);
    _attachments = (n?.attachments ?? const [])
        .map(_EditableNoteAttachment.fromAttachment)
        .toList();
    _tags = List<String>.from(n?.tags ?? const []);
    _folderId = n?.folderId;
    _reminderAt = n?.reminderAt;
    _priority = n?.priority ?? NotePriority.medium;
    _pinned = n?.pinned ?? false;
    _ownerUid = n?.ownerUid;
    _ownerName = n?.ownerName;
    _ownerEmail = n?.ownerEmail;
    _dueAt = n?.dueAt;
    _archivedAt = n?.archivedAt;
    _inInbox = n?.inInbox ?? widget.initialInInbox;
    _pipelineAddedAt = n?.pipelineAddedAt ??
        (widget.initialInPipeline ? DateTime.now() : null);
    _pipelineStage = n?.pipelineStage ??
        (widget.initialInPipeline ? widget.initialPipelineStage : null);
    _createdAt = n?.createdAt ?? DateTime.now();

    _title.addListener(_markDirty);
    _body.addListener(_markDirty);

    if (_type == NoteType.checklist && _items.isEmpty && widget.note == null) {
      _items = [ChecklistItem(id: _uuid.v4(), text: '', done: false)];
      _newItemIndex = 0;
    }
  }

  void _markDirty() {
    _dirty = true;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _title.dispose();
    _body.dispose();
    _tagInput.dispose();
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape ||
        ModalRoute.of(context)?.isCurrent != true) {
      return false;
    }
    _closeEditor();
    return true;
  }

  bool get _isEffectivelyEmpty =>
      _title.text.trim().isEmpty &&
      _body.text.trim().isEmpty &&
      _attachments.isEmpty &&
      _items.every((i) => i.text.trim().isEmpty);

  Future<bool> _save() async {
    if (_saving) return true;
    if (widget.note == null && _isEffectivelyEmpty) return true;
    if (!_dirty && widget.note != null) return true;
    setState(() => _saving = true);
    try {
      final cleanedItems =
          _items.where((i) => i.text.trim().isNotEmpty).toList(growable: false);
      final attachments = await _persistAttachments();
      final note = Note(
        id: _id,
        title: _title.text.trim(),
        body: _body.text,
        type: _type,
        items: cleanedItems,
        attachments: attachments,
        tags: _tags,
        folderId: _folderId,
        reminderAt: _reminderAt,
        priority: _priority,
        pinned: _pinned,
        ownerUid: _ownerUid,
        ownerName: _ownerName,
        ownerEmail: _ownerEmail,
        dueAt: _dueAt,
        archivedAt: _archivedAt,
        inInbox: _inInbox,
        pipelineAddedAt: _pipelineAddedAt,
        pipelineStage: _pipelineStage,
        createdByUid: widget.note?.createdByUid,
        createdByName: widget.note?.createdByName,
        createdByEmail: widget.note?.createdByEmail,
        updatedByUid: widget.note?.updatedByUid,
        updatedByName: widget.note?.updatedByName,
        updatedByEmail: widget.note?.updatedByEmail,
        createdAt: _createdAt,
        updatedAt: DateTime.now(),
      );
      await ref.read(notesServiceProvider).upsertNote(note);
      _dirty = false;
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<List<NoteAttachment>> _persistAttachments() async {
    final service = ref.read(notesServiceProvider);
    final persisted = <NoteAttachment>[];
    final updated = <_EditableNoteAttachment>[];

    for (final attachment in _attachments) {
      final pendingBytes = attachment.pendingBytes;
      if (pendingBytes == null) {
        final noteAttachment = attachment.toAttachment();
        persisted.add(noteAttachment);
        updated.add(attachment);
        continue;
      }

      final uploaded = await service.uploadImageAttachment(
        noteId: _id,
        name: attachment.name,
        bytes: pendingBytes,
        contentType: attachment.contentType ?? 'image/png',
      );
      persisted.add(uploaded);
      updated.add(_EditableNoteAttachment.fromAttachment(uploaded));
    }

    _attachments = updated;
    return persisted;
  }

  Future<void> _closeEditor() async {
    if (_closing) return;
    _closing = true;
    final navigator = Navigator.of(context);
    final ok = await _save();
    if (!mounted) return;
    if (ok) {
      navigator.pop();
    } else {
      _closing = false;
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this note?'),
        content: const Text('This cannot be undone.'),
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
    if (ok != true) return;
    try {
      await ref.read(notesServiceProvider).deleteNote(_id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  Future<void> _archive() async {
    if (widget.note == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive this note?'),
        content: const Text(
          'Archived notes leave the active notes list and pipeline, but can be restored later from archive views.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(notesServiceProvider).archiveNote(_id, archived: true);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Archive failed: $e')),
        );
      }
    }
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final initial = _dueAt ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueAt ?? DateTime(now.year)),
    );
    setState(() {
      _dueAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 9,
        time?.minute ?? 0,
      );
      _dirty = true;
    });
  }

  void _assignOwner(String? uid, List<TeamMember> members) {
    TeamMember? member;
    if (uid != null) {
      for (final candidate in members) {
        if (candidate.uid == uid) {
          member = candidate;
          break;
        }
      }
    }
    setState(() {
      _ownerUid = member?.uid;
      _ownerName = member?.label;
      _ownerEmail = member?.email;
      _dirty = true;
    });
  }

  void _addChecklistItem() {
    setState(() {
      _items.add(ChecklistItem(id: _uuid.v4(), text: '', done: false));
      _newItemIndex = _items.length - 1;
      _dirty = true;
    });
  }

  void _addTag() {
    final t = _tagInput.text.trim();
    if (t.isEmpty || _tags.contains(t)) {
      _tagInput.clear();
      return;
    }
    setState(() {
      _tags = [..._tags, t];
      _tagInput.clear();
      _dirty = true;
    });
  }

  void _toggleType() {
    setState(() {
      if (_type == NoteType.note) {
        final lines =
            _body.text.split('\n').where((l) => l.trim().isNotEmpty).toList();
        _items = lines
            .map(
              (l) => ChecklistItem(
                id: _uuid.v4(),
                text: l.trim(),
                done: false,
              ),
            )
            .toList();
        if (_items.isEmpty) {
          _items = [ChecklistItem(id: _uuid.v4(), text: '', done: false)];
          _newItemIndex = 0;
        }
        _type = NoteType.checklist;
      } else {
        _body.text =
            _items.map((i) => i.text).where((t) => t.isNotEmpty).join('\n');
        _items = const [];
        _type = NoteType.note;
      }
      _dirty = true;
    });
  }

  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final picked = <_EditableNoteAttachment>[];
    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) continue;
      picked.add(
        _EditableNoteAttachment.local(
          id: _uuid.v4(),
          name: file.name,
          bytes: bytes,
          contentType: _contentTypeForImageName(file.name),
        ),
      );
    }

    if (picked.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read the selected image.')),
      );
      return;
    }

    setState(() {
      _attachments = [..._attachments, ...picked];
      _dirty = true;
    });
  }

  Future<void> _markUpAttachment(int index) async {
    final attachment = _attachments[index];
    final bytes =
        attachment.pendingBytes ?? await _downloadAttachment(attachment);
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open that image for markup.')),
      );
      return;
    }

    if (!mounted) return;
    final result = await Navigator.of(context).push<MarkedUpImage>(
      MaterialPageRoute(
        builder: (_) => ImageMarkupScreen(
          imageBytes: bytes,
          fileName: attachment.name,
        ),
      ),
    );
    if (result == null) return;

    setState(() {
      _attachments[index] = attachment.copyWith(
        name: result.name,
        pendingBytes: result.bytes,
        sizeBytes: result.bytes.length,
        contentType: 'image/png',
      );
      _dirty = true;
    });
  }

  Future<Uint8List?> _downloadAttachment(
    _EditableNoteAttachment attachment,
  ) async {
    final dataBase64 = attachment.dataBase64;
    if (dataBase64 != null && dataBase64.isNotEmpty) {
      return base64Decode(dataBase64);
    }
    final url = attachment.url;
    if (url == null || url.isEmpty) return null;
    final response = await http.get(Uri.parse(url));
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    return response.bodyBytes;
  }

  Future<void> _previewAttachment(_EditableNoteAttachment attachment) async {
    if (attachment.isImage) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900, maxHeight: 720),
            child: attachment.pendingBytes != null
                ? Image.memory(attachment.pendingBytes!, fit: BoxFit.contain)
                : Image.network(attachment.url ?? '', fit: BoxFit.contain),
          ),
        ),
      );
      return;
    }

    final url = attachment.url;
    if (url == null || url.isEmpty) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachments = [
        for (var i = 0; i < _attachments.length; i++)
          if (i != index) _attachments[i],
      ];
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final foldersAsync = ref.watch(foldersStreamProvider);
    final folders = foldersAsync.value ?? const <Folder>[];
    final members = ref.watch(membersProvider).value ?? const <TeamMember>[];
    final isAdmin = ref.watch(isAdminProvider);
    final safeFolderId =
        (_folderId != null && folders.any((f) => f.id == _folderId))
            ? _folderId
            : null;
    final safeOwnerUid =
        (_ownerUid != null && members.any((m) => m.uid == _ownerUid))
            ? _ownerUid
            : null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _closeEditor();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _closeEditor,
          ),
          title: Text(widget.note == null ? 'New' : 'Edit'),
          actions: [
            IconButton(
              icon: Icon(
                _pipelineAddedAt != null ? Icons.task_alt : Icons.add_task,
                color: _pipelineAddedAt != null
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              tooltip: _pipelineAddedAt != null
                  ? 'Remove from pipeline'
                  : 'Add to pipeline',
              onPressed: () => setState(() {
                if (_pipelineAddedAt == null) {
                  _pipelineAddedAt = DateTime.now();
                  _pipelineStage = PipelineStage.ideas;
                  _inInbox = false;
                } else {
                  _pipelineAddedAt = null;
                  _pipelineStage = null;
                }
                _dirty = true;
              }),
            ),
            IconButton(
              icon: Icon(
                _pinned ? Icons.push_pin : Icons.push_pin_outlined,
              ),
              tooltip: _pinned ? 'Unpin' : 'Pin',
              onPressed: () => setState(() {
                _pinned = !_pinned;
                _dirty = true;
              }),
            ),
            IconButton(
              icon: Icon(
                _type == NoteType.checklist ? Icons.notes : Icons.checklist,
              ),
              tooltip: _type == NoteType.checklist
                  ? 'Convert to note'
                  : 'Convert to checklist',
              onPressed: _toggleType,
            ),
            if (widget.note != null)
              IconButton(
                icon: const Icon(Icons.archive_outlined),
                tooltip: 'Archive',
                onPressed: _archive,
              ),
            if (widget.note != null && isAdmin)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete',
                onPressed: _delete,
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Title',
                ),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Divider(),
              if (_type == NoteType.note)
                TextField(
                  controller: _body,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Write something...',
                  ),
                  maxLines: null,
                  minLines: 5,
                  keyboardType: TextInputType.multiline,
                )
              else
                Column(
                  children: [
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      itemCount: _items.length,
                      onReorderItem: (oldIndex, newIndex) {
                        setState(() {
                          final item = _items.removeAt(oldIndex);
                          _items.insert(newIndex, item);
                          _dirty = true;
                        });
                      },
                      itemBuilder: (ctx, i) => Row(
                        key: ValueKey(_items[i].id),
                        children: [
                          ReorderableDragStartListener(
                            index: i,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: Icon(
                                Icons.drag_indicator,
                                size: 18,
                                color: Theme.of(context).hintColor,
                              ),
                            ),
                          ),
                          Expanded(
                            child: ChecklistItemTile(
                              item: _items[i],
                              autoFocus: i == _newItemIndex,
                              onChanged: (updated) {
                                setState(() {
                                  _items[i] = updated;
                                  _newItemIndex = null;
                                  _dirty = true;
                                });
                              },
                              onSubmitted: _addChecklistItem,
                              onDelete: () => setState(() {
                                _items.removeAt(i);
                                _dirty = true;
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add item'),
                        onPressed: _addChecklistItem,
                      ),
                    ),
                  ],
                ),
              const Divider(),
              _NoteAttachmentsEditor(
                attachments: _attachments,
                onAddImages: _pickImages,
                onPreview: _previewAttachment,
                onMarkUp: _markUpAttachment,
                onRemove: _removeAttachment,
              ),
              const Divider(),
              ReminderPicker(
                value: _reminderAt,
                onChanged: (v) => setState(() {
                  _reminderAt = v;
                  _dirty = true;
                }),
              ),
              const Divider(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.flag_outlined, color: _priorityColor(_priority)),
                  const SizedBox(width: 12),
                  const Text('Priority'),
                ],
              ),
              const SizedBox(height: 8),
              SegmentedButton<NotePriority>(
                showSelectedIcon: false,
                segments: [
                  for (final priority in NotePriority.values)
                    ButtonSegment(
                      value: priority,
                      label: Text(priority.label),
                      icon: Icon(
                        Icons.flag,
                        color: _priorityColor(priority),
                      ),
                    ),
                ],
                selected: {_priority},
                onSelectionChanged: (values) => setState(() {
                  _priority = values.single;
                  _dirty = true;
                }),
              ),
              const Divider(),
              Row(
                children: [
                  const Icon(Icons.person_outline),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButton<String?>(
                      isExpanded: true,
                      value: safeOwnerUid,
                      hint: const Text('Unassigned'),
                      items: <DropdownMenuItem<String?>>[
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Unassigned'),
                        ),
                        for (final member in members)
                          DropdownMenuItem<String?>(
                            value: member.uid,
                            child: Text(member.label),
                          ),
                      ],
                      onChanged: (v) => _assignOwner(v, members),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.event_available_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _dueAt == null
                          ? 'No due date'
                          : 'Due ${DateFormat.MMMd().add_jm().format(_dueAt!)}',
                    ),
                  ),
                  if (_dueAt != null)
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Clear due date',
                      onPressed: () => setState(() {
                        _dueAt = null;
                        _dirty = true;
                      }),
                    ),
                  TextButton.icon(
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: const Text('Set due'),
                    onPressed: _pickDueDate,
                  ),
                ],
              ),
              CheckboxListTile(
                value: _inInbox,
                dense: true,
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.inbox_outlined),
                title: const Text('Keep in idea inbox'),
                onChanged: (value) => setState(() {
                  _inInbox = value ?? false;
                  _dirty = true;
                }),
              ),
              const Divider(),
              if (_pipelineAddedAt != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(Icons.timeline),
                    const SizedBox(width: 12),
                    const Text('Pipeline stage'),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final stage in PipelineStage.values)
                      ChoiceChip(
                        label: Text(stage.label),
                        selected: _pipelineStage == stage,
                        onSelected: (_) => setState(() {
                          _pipelineStage = stage;
                          _dirty = true;
                        }),
                      ),
                  ],
                ),
                const Divider(),
              ],
              Row(
                children: [
                  const Icon(Icons.folder_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButton<String?>(
                      isExpanded: true,
                      value: safeFolderId,
                      hint: const Text('No folder'),
                      items: <DropdownMenuItem<String?>>[
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('No folder'),
                        ),
                        for (final f in folders)
                          DropdownMenuItem<String?>(
                            value: f.id,
                            child: Text(f.name),
                          ),
                      ],
                      onChanged: (v) => setState(() {
                        _folderId = v;
                        _dirty = true;
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Icon(Icons.label_outline),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_tags.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                for (final t in _tags)
                                  Chip(
                                    label: Text(t),
                                    onDeleted: () => setState(() {
                                      _tags =
                                          _tags.where((x) => x != t).toList();
                                      _dirty = true;
                                    }),
                                  ),
                              ],
                            ),
                          ),
                        TextField(
                          controller: _tagInput,
                          decoration: InputDecoration(
                            hintText: 'Add tag',
                            isDense: true,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: _addTag,
                            ),
                          ),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _addTag(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (widget.note != null) ...[
                const Divider(height: 32),
                _NoteComments(
                  noteId: _id,
                  noteTitle: _title.text.trim(),
                ),
              ],
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 52,
            child: FilledButton.icon(
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check),
              label: Text(_saving ? 'Saving...' : 'Save'),
              onPressed: _saving ? null : _closeEditor,
            ),
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

class _NoteAttachmentsEditor extends StatelessWidget {
  final List<_EditableNoteAttachment> attachments;
  final VoidCallback onAddImages;
  final ValueChanged<_EditableNoteAttachment> onPreview;
  final ValueChanged<int> onMarkUp;
  final ValueChanged<int> onRemove;

  const _NoteAttachmentsEditor({
    required this.attachments,
    required this.onAddImages,
    required this.onPreview,
    required this.onMarkUp,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.image_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Images',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Add images'),
              onPressed: onAddImages,
            ),
          ],
        ),
        if (attachments.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 36, top: 4),
            child: Text(
              'No images attached',
              style: TextStyle(color: hint),
            ),
          )
        else ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < attachments.length; i++)
                _NoteAttachmentTile(
                  attachment: attachments[i],
                  onTap: () => onPreview(attachments[i]),
                  onMarkUp: () => onMarkUp(i),
                  onRemove: () => onRemove(i),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _NoteAttachmentTile extends StatelessWidget {
  final _EditableNoteAttachment attachment;
  final VoidCallback onTap;
  final VoidCallback onMarkUp;
  final VoidCallback onRemove;

  const _NoteAttachmentTile({
    required this.attachment,
    required this.onTap,
    required this.onMarkUp,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 188,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Material(
              color: scheme.surfaceContainerHighest,
              child: InkWell(
                onTap: onTap,
                child: SizedBox(
                  height: 126,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _AttachmentPreview(attachment: attachment),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _AttachmentIconButton(
                              tooltip: 'Mark up image',
                              icon: Icons.draw_outlined,
                              onPressed: onMarkUp,
                            ),
                            const SizedBox(width: 4),
                            _AttachmentIconButton(
                              tooltip: 'Remove image',
                              icon: Icons.close,
                              onPressed: onRemove,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            attachment.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          Text(
            _formatBytes(attachment.sizeBytes),
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: Theme.of(context).hintColor),
          ),
        ],
      ),
    );
  }
}

class _AttachmentPreview extends StatelessWidget {
  final _EditableNoteAttachment attachment;

  const _AttachmentPreview({required this.attachment});

  @override
  Widget build(BuildContext context) {
    final pendingBytes = attachment.pendingBytes;
    if (pendingBytes != null) {
      return Image.memory(
        pendingBytes,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _AttachmentFallback(),
      );
    }

    final dataBase64 = attachment.dataBase64;
    if (dataBase64 != null && dataBase64.isNotEmpty) {
      return Image.memory(
        base64Decode(dataBase64),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _AttachmentFallback(),
      );
    }

    final url = attachment.url;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _AttachmentFallback(),
      );
    }

    return const _AttachmentFallback();
  }
}

class _AttachmentFallback extends StatelessWidget {
  const _AttachmentFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Icon(Icons.broken_image_outlined));
  }
}

class _AttachmentIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const _AttachmentIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.58),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
        icon: Icon(icon, size: 18, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }
}

class _EditableNoteAttachment {
  final String id;
  final String name;
  final String? url;
  final String? storagePath;
  final String? dataBase64;
  final int sizeBytes;
  final String? contentType;
  final DateTime? createdAt;
  final Uint8List? pendingBytes;

  const _EditableNoteAttachment({
    required this.id,
    required this.name,
    required this.url,
    required this.storagePath,
    required this.dataBase64,
    required this.sizeBytes,
    required this.contentType,
    required this.createdAt,
    required this.pendingBytes,
  });

  factory _EditableNoteAttachment.fromAttachment(NoteAttachment attachment) =>
      _EditableNoteAttachment(
        id: attachment.id,
        name: attachment.name,
        url: attachment.url,
        storagePath: attachment.storagePath,
        dataBase64: attachment.dataBase64,
        sizeBytes: attachment.sizeBytes,
        contentType: attachment.contentType,
        createdAt: attachment.createdAt,
        pendingBytes: null,
      );

  factory _EditableNoteAttachment.local({
    required String id,
    required String name,
    required Uint8List bytes,
    required String contentType,
  }) =>
      _EditableNoteAttachment(
        id: id,
        name: name,
        url: null,
        storagePath: null,
        dataBase64: null,
        sizeBytes: bytes.length,
        contentType: contentType,
        createdAt: DateTime.now(),
        pendingBytes: bytes,
      );

  bool get isImage {
    final type = contentType?.toLowerCase() ?? '';
    if (type.startsWith('image/')) return true;
    return _isImageFileName(name);
  }

  _EditableNoteAttachment copyWith({
    String? name,
    int? sizeBytes,
    String? contentType,
    Uint8List? pendingBytes,
    String? dataBase64,
  }) =>
      _EditableNoteAttachment(
        id: id,
        name: name ?? this.name,
        url: url,
        storagePath: storagePath,
        dataBase64: dataBase64 ?? this.dataBase64,
        sizeBytes: sizeBytes ?? this.sizeBytes,
        contentType: contentType ?? this.contentType,
        createdAt: createdAt,
        pendingBytes: pendingBytes ?? this.pendingBytes,
      );

  NoteAttachment toAttachment() => NoteAttachment(
        id: id,
        name: name,
        url: url ?? '',
        storagePath: storagePath ?? '',
        dataBase64: dataBase64,
        sizeBytes: sizeBytes,
        contentType: contentType,
        createdAt: createdAt,
      );
}

String _contentTypeForImageName(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.heic')) return 'image/heic';
  if (lower.endsWith('.heif')) return 'image/heif';
  return 'image/png';
}

bool _isImageFileName(String name) {
  final lower = name.toLowerCase();
  return lower.endsWith('.png') ||
      lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.gif') ||
      lower.endsWith('.webp') ||
      lower.endsWith('.heic') ||
      lower.endsWith('.heif');
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '0 KB';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.ceil()} KB';
  return '${(kb / 1024).toStringAsFixed(1)} MB';
}

class _NoteComments extends ConsumerStatefulWidget {
  final String noteId;
  final String noteTitle;

  const _NoteComments({
    required this.noteId,
    required this.noteTitle,
  });

  @override
  ConsumerState<_NoteComments> createState() => _NoteCommentsState();
}

class _NoteCommentsState extends ConsumerState<_NoteComments> {
  final _comment = TextEditingController();
  bool _posting = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    if (_posting || _comment.text.trim().isEmpty) return;
    setState(() => _posting = true);
    try {
      await ref.read(commentsServiceProvider).addComment(
            noteId: widget.noteId,
            noteTitle: widget.noteTitle,
            text: _comment.text,
          );
      _comment.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Comment failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(noteCommentsProvider(widget.noteId));
    final isAdmin = ref.watch(isAdminProvider);
    final hint = Theme.of(context).hintColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.mode_comment_outlined),
            const SizedBox(width: 12),
            Text(
              'Discussion',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: 12),
        commentsAsync.when(
          data: (comments) => comments.isEmpty
              ? Text('No comments yet', style: TextStyle(color: hint))
              : Column(
                  children: [
                    for (final comment in comments)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          child: Icon(Icons.person_outline),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                comment.createdByName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              DateFormat.MMMd()
                                  .add_jm()
                                  .format(comment.createdAt),
                              style: TextStyle(fontSize: 11, color: hint),
                            ),
                          ],
                        ),
                        subtitle: Text(comment.text),
                        trailing: isAdmin
                            ? IconButton(
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Delete comment',
                                onPressed: () => ref
                                    .read(commentsServiceProvider)
                                    .deleteComment(
                                      widget.noteId,
                                      comment.id,
                                    ),
                              )
                            : null,
                      ),
                  ],
                ),
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Could not load comments: $e'),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _comment,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Add a comment or @mention someone',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _post(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _posting ? null : _post,
              child: _posting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ],
    );
  }
}
