import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/quick_item.dart';
import '../services/quick_list_service.dart';
import 'auth_provider.dart';
import 'team_provider.dart';

final quickListServiceProvider =
    Provider.family<QuickListService, QuickListKind>(
  (ref, kind) => QuickListService(kind),
);

final quickListItemsProvider =
    StreamProvider.family<List<QuickItem>, QuickListKind>((ref, kind) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream<List<QuickItem>>.value(const []);
  ref.watch(memberBootstrapProvider);
  return ref.watch(quickListServiceProvider(kind)).stream();
});
