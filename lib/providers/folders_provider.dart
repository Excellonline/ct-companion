import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/folder.dart';
import 'auth_provider.dart';
import 'notes_provider.dart';
import 'team_provider.dart';

final foldersStreamProvider = StreamProvider<List<Folder>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream<List<Folder>>.value(const []);
  ref.watch(memberBootstrapProvider);
  return ref.watch(notesServiceProvider).foldersStream();
});
