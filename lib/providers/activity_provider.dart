import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/activity_item.dart';
import '../services/activity_service.dart';
import 'auth_provider.dart';
import 'team_provider.dart';

final activityServiceProvider =
    Provider<ActivityService>((ref) => ActivityService());

final activityStreamProvider = StreamProvider<List<ActivityItem>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream<List<ActivityItem>>.value(const []);
  ref.watch(memberBootstrapProvider);
  return ref.watch(activityServiceProvider).activityStream();
});
