import 'package:cloud_firestore/cloud_firestore.dart';

enum NoteType { note, checklist }

enum NotePriority {
  low('low', 'Low'),
  medium('medium', 'Medium'),
  high('high', 'High');

  const NotePriority(this.id, this.label);
  final String id;
  final String label;

  static NotePriority fromId(String? id) {
    for (final p in NotePriority.values) {
      if (p.id == id) return p;
    }
    return NotePriority.medium;
  }
}

enum PipelineStage {
  ideas('ideas', 'Ideas'),
  planning('planning', 'Planning'),
  inProgress('in_progress', 'In Progress'),
  finalStages('final_stages', 'Final Stages'),
  complete('complete', 'Complete');

  const PipelineStage(this.id, this.label);
  final String id;
  final String label;

  static PipelineStage? fromId(String? id) {
    if (id == null) return null;
    for (final s in PipelineStage.values) {
      if (s.id == id) return s;
    }
    return null;
  }
}

class ChecklistItem {
  final String id;
  final String text;
  final bool done;

  ChecklistItem({required this.id, required this.text, required this.done});

  ChecklistItem copyWith({String? text, bool? done}) => ChecklistItem(
        id: id,
        text: text ?? this.text,
        done: done ?? this.done,
      );

  factory ChecklistItem.fromMap(Map<String, dynamic> map) => ChecklistItem(
        id: map['id'] as String,
        text: map['text'] as String? ?? '',
        done: map['done'] as bool? ?? false,
      );

  Map<String, dynamic> toMap() => {'id': id, 'text': text, 'done': done};
}

class NoteAttachment {
  final String id;
  final String name;
  final String url;
  final String storagePath;
  final String? dataBase64;
  final int sizeBytes;
  final String? contentType;
  final DateTime? createdAt;

  const NoteAttachment({
    required this.id,
    required this.name,
    required this.url,
    required this.storagePath,
    this.dataBase64,
    required this.sizeBytes,
    required this.contentType,
    required this.createdAt,
  });

  bool get isImage {
    final type = contentType?.toLowerCase() ?? '';
    if (type.startsWith('image/')) return true;
    final lowerName = name.toLowerCase();
    return lowerName.endsWith('.png') ||
        lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.gif') ||
        lowerName.endsWith('.webp') ||
        lowerName.endsWith('.heic') ||
        lowerName.endsWith('.heif');
  }

  factory NoteAttachment.fromMap(Map<String, dynamic> map) {
    final createdAt = map['createdAt'];
    return NoteAttachment(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Attachment',
      url: map['url'] as String? ?? '',
      storagePath: map['storagePath'] as String? ?? '',
      dataBase64: map['dataBase64'] as String?,
      sizeBytes: map['sizeBytes'] as int? ?? 0,
      contentType: map['contentType'] as String?,
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'url': url,
        'storagePath': storagePath,
        'dataBase64': dataBase64,
        'sizeBytes': sizeBytes,
        'contentType': contentType,
        'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      };
}

class Note {
  final String id;
  final String title;
  final String body;
  final NoteType type;
  final List<ChecklistItem> items;
  final List<NoteAttachment> attachments;
  final List<String> tags;
  final String? folderId;
  final DateTime? reminderAt;
  final NotePriority priority;
  final bool pinned;
  final String? ownerUid;
  final String? ownerName;
  final String? ownerEmail;
  final DateTime? dueAt;
  final DateTime? archivedAt;
  final bool inInbox;
  final DateTime? pipelineAddedAt;
  final PipelineStage? pipelineStage;
  final String? createdByUid;
  final String? createdByName;
  final String? createdByEmail;
  final String? updatedByUid;
  final String? updatedByName;
  final String? updatedByEmail;
  final DateTime createdAt;
  final DateTime updatedAt;

  Note({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.items,
    this.attachments = const [],
    required this.tags,
    required this.folderId,
    required this.reminderAt,
    required this.priority,
    required this.pinned,
    required this.ownerUid,
    required this.ownerName,
    required this.ownerEmail,
    required this.dueAt,
    required this.archivedAt,
    required this.inInbox,
    required this.pipelineAddedAt,
    required this.pipelineStage,
    required this.createdByUid,
    required this.createdByName,
    required this.createdByEmail,
    required this.updatedByUid,
    required this.updatedByName,
    required this.updatedByEmail,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get inPipeline => pipelineAddedAt != null;
  bool get isArchived => archivedAt != null;

  String get createdByLabel => _actorLabel(createdByName, createdByEmail);
  String get updatedByLabel => _actorLabel(updatedByName, updatedByEmail);
  String get ownerLabel {
    if (ownerUid == null || ownerUid!.trim().isEmpty) return 'Unassigned';
    return _actorLabel(ownerName, ownerEmail);
  }

  static String _actorLabel(String? name, String? email) {
    final n = name?.trim() ?? '';
    if (n.isNotEmpty) return n;
    final e = email?.trim() ?? '';
    if (e.isNotEmpty) return e;
    return 'Unknown';
  }

  factory Note.empty({required String id, NoteType type = NoteType.note}) =>
      Note(
        id: id,
        title: '',
        body: '',
        type: type,
        items: const [],
        attachments: const [],
        tags: const [],
        folderId: null,
        reminderAt: null,
        priority: NotePriority.medium,
        pinned: false,
        ownerUid: null,
        ownerName: null,
        ownerEmail: null,
        dueAt: null,
        archivedAt: null,
        inInbox: false,
        pipelineAddedAt: null,
        pipelineStage: null,
        createdByUid: null,
        createdByName: null,
        createdByEmail: null,
        updatedByUid: null,
        updatedByName: null,
        updatedByEmail: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  factory Note.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final addedAt = (data['pipelineAddedAt'] as Timestamp?)?.toDate();
    return Note(
      id: doc.id,
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      type: data['type'] == 'checklist' ? NoteType.checklist : NoteType.note,
      items: ((data['items'] as List?) ?? const [])
          .map(
              (e) => ChecklistItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      attachments: ((data['attachments'] as List?) ?? const [])
          .map(
            (e) => NoteAttachment.fromMap(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
      tags: ((data['tags'] as List?) ?? const []).cast<String>(),
      folderId: data['folderId'] as String?,
      reminderAt: (data['reminderAt'] as Timestamp?)?.toDate(),
      priority: NotePriority.fromId(data['priority'] as String?),
      pinned: data['pinned'] as bool? ?? false,
      ownerUid: data['ownerUid'] as String?,
      ownerName: data['ownerName'] as String?,
      ownerEmail: data['ownerEmail'] as String?,
      dueAt: (data['dueAt'] as Timestamp?)?.toDate(),
      archivedAt: (data['archivedAt'] as Timestamp?)?.toDate(),
      inInbox: data['inInbox'] as bool? ?? false,
      pipelineAddedAt: addedAt,
      pipelineStage: addedAt == null
          ? null
          : PipelineStage.fromId(data['pipelineStage'] as String?) ??
              PipelineStage.ideas,
      createdByUid: data['createdByUid'] as String?,
      createdByName: data['createdByName'] as String?,
      createdByEmail: data['createdByEmail'] as String?,
      updatedByUid: data['updatedByUid'] as String?,
      updatedByName: data['updatedByName'] as String?,
      updatedByEmail: data['updatedByEmail'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'body': body,
        'type': type.name,
        'items': items.map((i) => i.toMap()).toList(),
        'attachments': attachments.map((a) => a.toMap()).toList(),
        'tags': tags,
        'folderId': folderId,
        'reminderAt':
            reminderAt == null ? null : Timestamp.fromDate(reminderAt!),
        'priority': priority.id,
        'pinned': pinned,
        'ownerUid': ownerUid,
        'ownerName': ownerName,
        'ownerEmail': ownerEmail,
        'dueAt': dueAt == null ? null : Timestamp.fromDate(dueAt!),
        'archivedAt':
            archivedAt == null ? null : Timestamp.fromDate(archivedAt!),
        'inInbox': inInbox,
        'pipelineAddedAt': pipelineAddedAt == null
            ? null
            : Timestamp.fromDate(pipelineAddedAt!),
        'pipelineStage': pipelineStage?.id,
        'createdByUid': createdByUid,
        'createdByName': createdByName,
        'createdByEmail': createdByEmail,
        'updatedByUid': updatedByUid,
        'updatedByName': updatedByName,
        'updatedByEmail': updatedByEmail,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };
}
