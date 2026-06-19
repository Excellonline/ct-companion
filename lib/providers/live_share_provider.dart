import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/live_share.dart';
import '../services/live_share_service.dart';
import 'auth_provider.dart';
import 'team_provider.dart';

final liveShareServiceProvider =
    Provider<LiveShareService>((ref) => LiveShareService());

final selectedLiveShareIdProvider = StateProvider<String?>((ref) => null);

final liveShareBoardsProvider = StreamProvider<List<LiveShareBoard>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream<List<LiveShareBoard>>.value(const []);
  ref.watch(memberBootstrapProvider);
  return ref.watch(liveShareServiceProvider).boardsStream();
});

final selectedLiveShareProvider = StreamProvider<LiveShareBoard?>((ref) {
  final id = ref.watch(selectedLiveShareIdProvider);
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null || id == null) return Stream<LiveShareBoard?>.value(null);
  ref.watch(memberBootstrapProvider);
  return ref.watch(liveShareServiceProvider).boardStream(id);
});

final liveShareStrokesProvider =
    StreamProvider.family<List<LiveShareStroke>, String>((ref, boardId) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream<List<LiveShareStroke>>.value(const []);
  ref.watch(memberBootstrapProvider);
  return ref.watch(liveShareServiceProvider).strokesStream(boardId);
});
