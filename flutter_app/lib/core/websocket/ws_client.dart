import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:agentteam/core/auth/secure_storage.dart';

class WsClient {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _controller.stream;

  Future<void> connect(String threadId) async {
    await disconnect();

    final token = await AuthStorage.getAccessToken();
    final params = <String, String>{};
    if (token != null) params['token'] = token;
    final uri = Uri.parse(
      'ws://localhost:3000/threads/$threadId/subscribe',
    ).replace(queryParameters: params.isEmpty ? null : params);

    _channel = WebSocketChannel.connect(uri);
    _subscription = _channel!.stream.listen(
      (data) {
        try {
          final decoded = jsonDecode(data as String) as Map<String, dynamic>;
          _controller.add(decoded);
        } catch (_) {}
      },
      onError: (error) {
        // Connection error — could implement reconnect logic here
      },
      onDone: () {
        // Connection closed
      },
    );
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _controller.close();
  }
}
