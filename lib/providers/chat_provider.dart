import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import '../models/chat_thread.dart';
import '../services/chat_service.dart';
import 'auth_provider.dart';
import 'team_provider.dart';

final chatServiceProvider = Provider<ChatService>((ref) => ChatService());

final selectedChatThreadIdProvider = StateProvider<String?>((ref) => null);

final chatThreadsProvider = StreamProvider<List<ChatThread>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream<List<ChatThread>>.value(const []);
  ref.watch(memberBootstrapProvider);
  return ref.watch(chatServiceProvider).threadsStream();
});

final chatMessagesProvider =
    StreamProvider.family<List<ChatMessage>, String>((ref, threadId) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null || threadId.isEmpty) {
    return Stream<List<ChatMessage>>.value(const []);
  }
  ref.watch(memberBootstrapProvider);
  return ref.watch(chatServiceProvider).messagesStream(threadId);
});
