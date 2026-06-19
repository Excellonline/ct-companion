import '../models/team_member.dart';
import 'notifications_service.dart';
import 'team_service.dart';

class MentionsService {
  final _team = TeamService();
  final _notifications = NotificationsService();

  Future<void> notifyMentions({
    required String text,
    required String title,
    required String body,
    required String entityType,
    required String entityId,
  }) async {
    final tokens = _mentionTokens(text);
    if (tokens.isEmpty) return;

    final actor = _team.currentActor();
    final members = await _team.membersCol.get();
    for (final doc in members.docs) {
      final member = TeamMember.fromFirestore(doc);
      if (member.uid == actor.uid) continue;
      if (!_matchesAny(member, tokens)) continue;
      await _notifications.createNotification(
        uid: member.uid,
        title: title,
        body: body,
        entityType: entityType,
        entityId: entityId,
      );
    }
  }

  Set<String> _mentionTokens(String text) {
    return RegExp(r'(^|\s)@([A-Za-z0-9._-]+)')
        .allMatches(text)
        .map((m) => m.group(2)?.toLowerCase().trim() ?? '')
        .where((token) => token.isNotEmpty)
        .toSet();
  }

  bool _matchesAny(TeamMember member, Set<String> tokens) {
    final emailPrefix = member.email.split('@').first.toLowerCase();
    final name = member.displayName.toLowerCase();
    final compactName = name.replaceAll(RegExp(r'\s+'), '');
    final nameParts = name
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toSet();
    return tokens.any(
      (token) =>
          token == emailPrefix ||
          token == compactName ||
          nameParts.contains(token),
    );
  }
}
