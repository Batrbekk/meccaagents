import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agentteam/features/chat/data/chat_repository.dart';
import 'package:agentteam/features/chat/domain/message.dart';
import 'package:agentteam/features/chat/domain/thread.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

// --- Thread list ---

final threadListProvider =
    AsyncNotifierProvider<ThreadListNotifier, List<ChatThread>>(
  ThreadListNotifier.new,
);

class ThreadListNotifier extends AsyncNotifier<List<ChatThread>> {
  @override
  Future<List<ChatThread>> build() async {
    final repo = ref.read(chatRepositoryProvider);
    return repo.getThreads();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(chatRepositoryProvider);
      return repo.getThreads();
    });
  }

  Future<ChatThread> createThread(String title) async {
    final repo = ref.read(chatRepositoryProvider);
    final thread = await repo.createThread(title);
    final current = state.value ?? [];
    state = AsyncData([thread, ...current]);
    return thread;
  }
}

// --- Messages for a thread ---

class MessagesState {
  final List<Message> messages;
  final String? nextCursor;
  final bool isLoadingMore;
  final bool isSending;
  final bool agentTyping;
  final String? typingAgentSlug;

  const MessagesState({
    this.messages = const [],
    this.nextCursor,
    this.isLoadingMore = false,
    this.isSending = false,
    this.agentTyping = false,
    this.typingAgentSlug,
  });

  MessagesState copyWith({
    List<Message>? messages,
    String? nextCursor,
    bool? isLoadingMore,
    bool? isSending,
    bool? agentTyping,
    String? typingAgentSlug,
    bool clearCursor = false,
    bool clearTypingAgent = false,
  }) {
    return MessagesState(
      messages: messages ?? this.messages,
      nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isSending: isSending ?? this.isSending,
      agentTyping: agentTyping ?? this.agentTyping,
      typingAgentSlug: clearTypingAgent ? null : (typingAgentSlug ?? this.typingAgentSlug),
    );
  }
}

/// Family provider for messages per thread.
final messagesProvider = AsyncNotifierProvider.family
    .autoDispose<MessagesNotifier, MessagesState, String>(
  (threadId) => MessagesNotifier(threadId),
);

class MessagesNotifier extends AsyncNotifier<MessagesState> {
  MessagesNotifier(this._threadId);

  final String _threadId;
  Timer? _pollTimer;

  @override
  FutureOr<MessagesState> build() async {
    ref.onDispose(() {
      _pollTimer?.cancel();
    });

    final repo = ref.read(chatRepositoryProvider);
    final result = await repo.getMessages(_threadId);

    // Poll for new messages every 3 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());

    return MessagesState(
      messages: result.messages,
      nextCursor: result.nextCursor,
    );
  }

  Future<void> _poll() async {
    final current = state.value;
    if (current == null) return;

    try {
      final repo = ref.read(chatRepositoryProvider);
      final results = await Future.wait([
        repo.getMessages(_threadId),
        repo.getThinkingAgent(),
      ]);

      final result = results[0] as ({List<Message> messages, String? nextCursor});
      final thinkingSlug = results[1] as String?;

      // Check for new messages
      final newMessages = result.messages;

      // Detect if there are new messages (compare first message id)
      final hasNew = newMessages.isNotEmpty &&
          (current.messages.isEmpty || newMessages.first.id != current.messages.first.id);

      final isThinking = thinkingSlug != null;

      if (hasNew || isThinking != current.agentTyping || thinkingSlug != current.typingAgentSlug) {
        state = AsyncData(current.copyWith(
          messages: hasNew ? newMessages : null,
          nextCursor: hasNew ? result.nextCursor : null,
          agentTyping: isThinking,
          typingAgentSlug: thinkingSlug,
          clearTypingAgent: thinkingSlug == null,
        ));
      }
    } catch (_) {
      // Silently ignore poll errors
    }
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null ||
        current.isLoadingMore ||
        current.nextCursor == null) {
      return;
    }

    state = AsyncData(current.copyWith(isLoadingMore: true));

    try {
      final repo = ref.read(chatRepositoryProvider);
      final result =
          await repo.getMessages(_threadId, cursor: current.nextCursor);
      state = AsyncData(current.copyWith(
        messages: [...current.messages, ...result.messages],
        nextCursor: result.nextCursor,
        isLoadingMore: false,
        clearCursor: result.nextCursor == null,
      ));
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  Future<void> sendMessage(String content) async {
    final current = state.value;
    if (current == null) return;

    state = AsyncData(current.copyWith(isSending: true));

    try {
      final repo = ref.read(chatRepositoryProvider);
      final message = await repo.sendMessage(_threadId, content);
      final updated = state.value ?? current;
      final exists = updated.messages.any((m) => m.id == message.id);
      if (!exists) {
        state = AsyncData(updated.copyWith(
          messages: [message, ...updated.messages],
          isSending: false,
          agentTyping: true,
        ));
      } else {
        state = AsyncData(updated.copyWith(isSending: false, agentTyping: true));
      }
    } catch (e) {
      final updated = state.value ?? current;
      state = AsyncData(updated.copyWith(isSending: false));
      rethrow;
    }
  }

  Future<void> sendMessageWithFiles(String content, {List<Map<String, dynamic>>? files}) async {
    final current = state.value;
    if (current == null) return;

    state = AsyncData(current.copyWith(isSending: true));

    try {
      final repo = ref.read(chatRepositoryProvider);
      final message = await repo.sendMessageWithFiles(_threadId, content, files: files);
      final updated = state.value ?? current;
      final exists = updated.messages.any((m) => m.id == message.id);
      if (!exists) {
        state = AsyncData(updated.copyWith(
          messages: [message, ...updated.messages],
          isSending: false,
          agentTyping: true,
        ));
      } else {
        state = AsyncData(updated.copyWith(isSending: false, agentTyping: true));
      }
    } catch (e) {
      final updated = state.value ?? current;
      state = AsyncData(updated.copyWith(isSending: false));
      rethrow;
    }
  }
}

/// Convenience provider that returns a send function for a given thread.
/// Usage: `ref.read(sendMessageProvider(threadId))('Hello')`
final sendMessageProvider =
    Provider.family<Future<void> Function(String), String>((ref, threadId) {
  return (String content) async {
    await ref.read(messagesProvider(threadId).notifier).sendMessage(content);
  };
});
