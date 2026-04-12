import 'package:agentteam/core/api/dio_client.dart';
import 'package:agentteam/features/chat/domain/message.dart';
import 'package:agentteam/features/chat/domain/thread.dart';

class ChatRepository {
  Future<List<ChatThread>> getThreads() async {
    final response = await dio.get('/threads');
    final list = response.data as List<dynamic>;
    return list
        .map((e) => ChatThread.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ChatThread> createThread(String title) async {
    final response = await dio.post('/threads', data: {'title': title});
    return ChatThread.fromJson(response.data as Map<String, dynamic>);
  }

  Future<({List<Message> messages, String? nextCursor})> getMessages(
    String threadId, {
    String? cursor,
    int limit = 50,
  }) async {
    final queryParams = <String, dynamic>{'limit': limit};
    if (cursor != null) queryParams['cursor'] = cursor;

    final response = await dio.get(
      '/threads/$threadId/messages',
      queryParameters: queryParams,
    );
    final data = response.data as Map<String, dynamic>;
    final messages = (data['messages'] as List<dynamic>)
        .map((e) => Message.fromJson(e as Map<String, dynamic>))
        .toList();
    final nextCursor = data['nextCursor'] as String?;

    return (messages: messages, nextCursor: nextCursor);
  }

  Future<Message> sendMessage(String threadId, String content) async {
    final response = await dio.post(
      '/threads/$threadId/messages',
      data: {'content': content},
    );
    return Message.fromJson(response.data as Map<String, dynamic>);
  }
}
