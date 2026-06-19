import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_notification.dart';
import '../services/notifications_service.dart';
import 'auth_provider.dart';
import 'team_provider.dart';

final notificationsServiceProvider = Provider<NotificationsService>(
  (ref) => NotificationsService(),
);

final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream<List<AppNotification>>.value(const []);
  ref.watch(memberBootstrapProvider);
  return ref.watch(notificationsServiceProvider).notificationsStream();
});

final unreadNotificationsCountProvider = StreamProvider<int>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream<int>.value(0);
  ref.watch(memberBootstrapProvider);
  return ref.watch(notificationsServiceProvider).unreadCountStream();
});
