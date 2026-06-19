import 'package:cloud_firestore/cloud_firestore.dart';

enum SharedFileKind {
  document('document', 'Docs'),
  file('file', 'Files');

  const SharedFileKind(this.id, this.label);
  final String id;
  final String label;

  static SharedFileKind fromId(String? id) {
    for (final kind in SharedFileKind.values) {
      if (kind.id == id) return kind;
    }
    return SharedFileKind.file;
  }

  static SharedFileKind fromName(String name) {
    final lower = name.toLowerCase();
    const docExtensions = [
      '.pdf',
      '.doc',
      '.docx',
      '.xls',
      '.xlsx',
      '.ppt',
      '.pptx',
      '.txt',
      '.md',
      '.csv',
      '.rtf',
    ];
    return docExtensions.any(lower.endsWith)
        ? SharedFileKind.document
        : SharedFileKind.file;
  }
}

class SharedFile {
  final String id;
  final String name;
  final String url;
  final String storagePath;
  final int sizeBytes;
  final String? contentType;
  final SharedFileKind kind;
  final String createdByUid;
  final String createdByName;
  final String createdByEmail;
  final DateTime createdAt;

  SharedFile({
    required this.id,
    required this.name,
    required this.url,
    required this.storagePath,
    required this.sizeBytes,
    required this.contentType,
    required this.kind,
    required this.createdByUid,
    required this.createdByName,
    required this.createdByEmail,
    required this.createdAt,
  });

  String get sizeLabel {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory SharedFile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? const {};
    return SharedFile(
      id: doc.id,
      name: data['name'] as String? ?? 'Untitled file',
      url: data['url'] as String? ?? '',
      storagePath: data['storagePath'] as String? ?? '',
      sizeBytes: data['sizeBytes'] as int? ?? 0,
      contentType: data['contentType'] as String?,
      kind: SharedFileKind.fromId(data['kind'] as String?),
      createdByUid: data['createdByUid'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? 'Team member',
      createdByEmail: data['createdByEmail'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
