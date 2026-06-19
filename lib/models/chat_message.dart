import 'package:cloud_firestore/cloud_firestore.dart';

class ChatAttachment {
  final String name;
  final String url;
  final String storagePath;
  final int sizeBytes;
  final String? contentType;

  ChatAttachment({
    required this.name,
    required this.url,
    required this.storagePath,
    required this.sizeBytes,
    required this.contentType,
  });

  factory ChatAttachment.fromMap(Map<String, dynamic> map) => ChatAttachment(
    name: map['name'] as String? ?? 'Attachment',
    url: map['url'] as String? ?? '',
    storagePath: map['storagePath'] as String? ?? '',
    sizeBytes: map['sizeBytes'] as int? ?? 0,
    contentType: map['contentType'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'url': url,
    'storagePath': storagePath,
    'sizeBytes': sizeBytes,
    'contentType': contentType,
  };
}

class ChatReplyReference {
  final String messageId;
  final String senderName;
  final String text;

  ChatReplyReference({
    required this.messageId,
    required this.senderName,
    required this.text,
  });

  factory ChatReplyReference.fromMap(Map<String, dynamic> map) =>
      ChatReplyReference(
        messageId: map['messageId'] as String? ?? '',
        senderName: map['senderName'] as String? ?? 'Team member',
        text: map['text'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
    'messageId': messageId,
    'senderName': senderName,
    'text': text,
  };
}

class ChatReaction {
  final String type;
  final String displayName;

  ChatReaction({required this.type, required this.displayName});

  factory ChatReaction.fromMap(Map<String, dynamic> map) => ChatReaction(
    type: map['type'] as String? ?? '',
    displayName: map['displayName'] as String? ?? 'Team member',
  );

  Map<String, dynamic> toMap() => {'type': type, 'displayName': displayName};
}

class ChatMessage {
  final String id;
  final String text;
  final String senderUid;
  final String senderName;
  final String senderEmail;
  final List<ChatAttachment> attachments;
  final ChatReplyReference? replyTo;
  final Map<String, ChatReaction> reactions;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.text,
    required this.senderUid,
    required this.senderName,
    required this.senderEmail,
    required this.attachments,
    required this.replyTo,
    required this.reactions,
    required this.createdAt,
  });

  int get thumbsUpCount => _reactionCount('up');
  int get thumbsDownCount => _reactionCount('down');

  String? reactionFor(String? uid) {
    if (uid == null || uid.isEmpty) return null;
    final type = reactions[uid]?.type;
    return type == 'up' || type == 'down' ? type : null;
  }

  int _reactionCount(String type) =>
      reactions.values.where((reaction) => reaction.type == type).length;

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? const {};
    final replyData = data['replyTo'];
    final reactionData = data['reactions'] as Map<String, dynamic>? ?? const {};
    return ChatMessage(
      id: doc.id,
      text: data['text'] as String? ?? '',
      senderUid: data['senderUid'] as String? ?? '',
      senderName: data['senderName'] as String? ?? 'Team member',
      senderEmail: data['senderEmail'] as String? ?? '',
      attachments: ((data['attachments'] as List?) ?? const [])
          .map(
            (e) => ChatAttachment.fromMap(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      replyTo: replyData is Map
          ? ChatReplyReference.fromMap(Map<String, dynamic>.from(replyData))
          : null,
      reactions: reactionData.map(
        (uid, value) => MapEntry(
          uid,
          value is Map
              ? ChatReaction.fromMap(Map<String, dynamic>.from(value))
              : ChatReaction(
                  type: value.toString(),
                  displayName: 'Team member',
                ),
        ),
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
