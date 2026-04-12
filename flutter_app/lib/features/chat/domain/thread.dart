class ChatThread {
  final String id;
  final String title;
  final bool isArchived;
  final DateTime createdAt;
  final String? lastMessageContent;
  final String? lastMessageSender;
  final DateTime? lastMessageAt;

  const ChatThread({
    required this.id,
    required this.title,
    this.isArchived = false,
    required this.createdAt,
    this.lastMessageContent,
    this.lastMessageSender,
    this.lastMessageAt,
  });

  factory ChatThread.fromJson(Map<String, dynamic> json) {
    final lastMsg = json['lastMessage'] as Map<String, dynamic>?;
    return ChatThread(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Untitled',
      isArchived: json['isArchived'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastMessageContent: lastMsg?['content'] as String?,
      lastMessageSender: lastMsg?['senderType'] as String? ??
          lastMsg?['senderId'] as String?,
      lastMessageAt: lastMsg?['createdAt'] != null
          ? DateTime.parse(lastMsg!['createdAt'] as String)
          : null,
    );
  }
}
