import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/decision.dart';
import '../services/decisions_service.dart';
import 'auth_provider.dart';
import 'team_provider.dart';

final decisionsServiceProvider = Provider<DecisionsService>(
  (ref) => DecisionsService(),
);

final showArchivedDecisionsProvider = StateProvider<bool>((ref) => false);

final decisionsProvider = StreamProvider<List<Decision>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream<List<Decision>>.value(const []);
  ref.watch(memberBootstrapProvider);
  final includeArchived = ref.watch(showArchivedDecisionsProvider);
  return ref
      .watch(decisionsServiceProvider)
      .decisionsStream(includeArchived: includeArchived);
});
