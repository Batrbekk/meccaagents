import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agentteam/core/websocket/ws_client.dart';
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

  const MessagesState({
    this.messages = const [],
    this.nextCursor,
    this.isLoadingMore = false,
    this.isSending = false,
    this.agentTyping = false,
  });

  MessagesState copyWith({
    List<Message>? messages,
    String? nextCursor,
    bool? isLoadingMore,
    bool? isSending,
    bool? agentTyping,
    bool clearCursor = false,
  }) {
    return MessagesState(
      messages: messages ?? this.messages,
      nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isSending: isSending ?? this.isSending,
      agentTyping: agentTyping ?? this.agentTyping,
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
  WsClient? _wsClient;
  StreamSubscription<Map<String, dynamic>>? _wsSub;

  @override
  FutureOr<MessagesState> build() async {
    ref.onDispose(() {
      _wsSub?.cancel();
      _wsClient?.dispose();
    });

    final repo = ref.read(chatRepositoryProvider);
    final result = await repo.getMessages(_threadId);

    // Connect WebSocket for real-time updates
    _wsClient = WsClient();
    await _wsClient!.connect(_threadId);
    _wsSub = _wsClient!.messages.listen(_onWsMessage);

    return MessagesState(
      messages: result.messages,
      nextCursor: result.nextCursor,
    );
  }

  void _onWsMessage(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final current = state.value;
    if (current == null) return;

    if (type == 'message') {
      final payload = data['payload'] as Map<String, dynamic>?;
      if (payload == null) return;
      final message = Message.fromJson(payload);
      final exists = current.messages.any((m) => m.id == message.id);
      if (!exists) {
        state = AsyncData(current.copyWith(
          messages: [message, ...current.messages],
          agentTyping: false,
        ));
      }
    } else if (type == 'typing') {
      state = AsyncData(current.copyWith(agentTyping: true));
    } else if (type == 'typing_stop') {
      state = AsyncData(current.copyWith(agentTyping: false));
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
        ));
      } else {
        state = AsyncData(updated.copyWith(isSending: false));
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
