import 'package:dio/dio.dart';
import 'package:agentteam/core/api/dio_client.dart';
import 'package:agentteam/features/chat/domain/message.dart';
import 'package:agentteam/features/chat/domain/thread.dart';

class ChatRepository {
  /// Upload a file and return its metadata (id, url, mimeType, etc.)
  Future<Map<String, dynamic>> uploadFile(
    List<int> bytes,
    String fileName,
    String mimeType, {
    String? threadId,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
    });
    final query = threadId != null ? '?threadId=$threadId' : '';
    final response = await dio.post('/files/upload$query',
        data: formData,
        options: Options(headers: {'Content-Type': 'multipart/form-data'}));
    return response.data as Map<String, dynamic>;
  }

  /// Send message with optional file attachments
  Future<Message> sendMessageWithFiles(
    String threadId,
    String content, {
    List<Map<String, dynamic>>? files,
  }) async {
    final metadata = <String, dynamic>{};
    if (files != null && files.isNotEmpty) {
      metadata['files'] = files;
    }
    final response = await dio.post('/threads/$threadId/messages', data: {
      'content': content,
      if (metadata.isNotEmpty) 'metadata': metadata,
    });
    return Message.fromJson(response.data as Map<String, dynamic>);
  }

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

  Future<void> deleteMessage(String threadId, String messageId) async {
    await dio.delete('/threads/$threadId/messages/$messageId');
  }

  Future<Message> sendMessage(String threadId, String content) async {
    final response = await dio.post(
      '/threads/$threadId/messages',
      data: {'content': content},
    );
    return Message.fromJson(response.data as Map<String, dynamic>);
  }

  /// Returns the slug of the first agent with status 'thinking', or null.
  Future<String?> getThinkingAgent() async {
    final response = await dio.get('/agents');
    final agents = (response.data['agents'] as List<dynamic>?) ?? [];
    for (final agent in agents) {
      if (agent['status'] == 'thinking') {
        return agent['slug'] as String?;
      }
    }
    return null;
  }
}
