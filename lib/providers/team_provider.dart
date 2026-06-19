import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/team_member.dart';
import '../services/team_service.dart';
import 'auth_provider.dart';

final teamServiceProvider = Provider<TeamService>((ref) => TeamService());

final memberBootstrapProvider = FutureProvider<void>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return;
  await ref.read(teamServiceProvider).ensureMemberProfile();
});

final currentMemberProvider = StreamProvider<TeamMember?>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream<TeamMember?>.value(null);
  ref.watch(memberBootstrapProvider);
  return ref.watch(teamServiceProvider).currentMemberStream();
});

final membersProvider = StreamProvider<List<TeamMember>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream<List<TeamMember>>.value(const []);
  ref.watch(memberBootstrapProvider);
  return ref.watch(teamServiceProvider).membersStream();
});

final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(currentMemberProvider).valueOrNull?.isAdmin ?? false;
});
