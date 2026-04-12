import 'package:flutter/material.dart';
import 'package:agentteam/core/theme/agent_colors.dart';
import 'package:agentteam/features/chat/domain/message.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isUser;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    final agentColor = AgentColors.forAgent(message.agentSlug);
    final agentName = AgentColors.displayName(message.agentSlug);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            // Agent avatar
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: agentColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  agentName.isNotEmpty ? agentName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isUser)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 3),
                    child: Text(
                      agentName,
                      style: TextStyle(
                        color: agentColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser ? AgentColors.userBubble : AgentColors.card,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: isUser
                          ? const Radius.circular(16)
                          : const Radius.circular(4),
                      bottomRight: isUser
                          ? const Radius.circular(4)
                          : const Radius.circular(16),
                    ),
                    border: isUser
                        ? null
                        : Border(
                            left: BorderSide(
                              color: agentColor.withValues(alpha: 0.6),
                              width: 2,
                            ),
                          ),
                  ),
                  child: Text(
                    message.content ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                  child: Text(
                    _formatTime(message.createdAt),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 36),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
