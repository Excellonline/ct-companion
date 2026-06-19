import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/note_comment.dart';
import '../services/comments_service.dart';
import 'auth_provider.dart';
import 'team_provider.dart';

final commentsServiceProvider =
    Provider<CommentsService>((ref) => CommentsService());

final noteCommentsProvider =
    StreamProvider.family<List<NoteComment>, String>((ref, noteId) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null || noteId.isEmpty) {
    return Stream<List<NoteComment>>.value(const []);
  }
  ref.watch(memberBootstrapProvider);
  return ref.watch(commentsServiceProvider).commentsStream(noteId);
});
