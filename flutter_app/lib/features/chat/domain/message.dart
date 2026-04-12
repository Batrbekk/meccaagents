class Message {
  final String id;
  final String threadId;
  final String senderType; // 'user' | 'agent'
  final String senderId;
  final String? content;
  final Map<String, dynamic>? metadata;
  final String status;
  final DateTime createdAt;

  const Message({
    required this.id,
    required this.threadId,
    required this.senderType,
    required this.senderId,
    this.content,
    this.metadata,
    this.status = 'sent',
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      threadId: json['threadId'] as String,
      senderType: json['senderType'] as String? ?? 'user',
      senderId: json['senderId'] as String? ?? '',
      content: json['content'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      status: json['status'] as String? ?? 'sent',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  bool get isUser => senderType == 'user';
  bool get isAgent => senderType == 'agent';

  /// The agent slug is typically the senderId for agent messages
  String get agentSlug => senderId;
}
