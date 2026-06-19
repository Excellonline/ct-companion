import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/shared_file.dart';
import '../services/files_service.dart';
import 'auth_provider.dart';
import 'team_provider.dart';

enum SharedFilesFilter { all, docs, files }

final filesServiceProvider = Provider<FilesService>((ref) => FilesService());

final sharedFilesFilterProvider = StateProvider<SharedFilesFilter>(
  (ref) => SharedFilesFilter.all,
);

final sharedFilesProvider = StreamProvider<List<SharedFile>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream<List<SharedFile>>.value(const []);
  ref.watch(memberBootstrapProvider);
  return ref.watch(filesServiceProvider).filesStream();
});

final filteredSharedFilesProvider = Provider<List<SharedFile>>((ref) {
  final files = ref.watch(sharedFilesProvider).valueOrNull ?? const [];
  final filter = ref.watch(sharedFilesFilterProvider);
  return switch (filter) {
    SharedFilesFilter.all => files,
    SharedFilesFilter.docs =>
      files.where((f) => f.kind == SharedFileKind.document).toList(),
    SharedFilesFilter.files =>
      files.where((f) => f.kind == SharedFileKind.file).toList(),
  };
});
