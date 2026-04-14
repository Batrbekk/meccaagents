import 'package:flutter/material.dart';
import 'package:agentteam/core/theme/agent_colors.dart';
import 'package:agentteam/features/chat/domain/message.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isUser;
  final void Function(Message)? onDelete;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isUser,
    this.onDelete,
  });

  void _showContextMenu(BuildContext context, Offset position) {
    if (!isUser || onDelete == null) return;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      color: AgentColors.card,
      items: [
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
              SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: Colors.redAccent)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'copy',
          child: Row(
            children: [
              Icon(Icons.copy, color: Colors.white70, size: 20),
              SizedBox(width: 8),
              Text('Copy', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'delete') {
        showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AgentColors.surface,
            title: const Text('Delete message?',
                style: TextStyle(color: Colors.white)),
            content: const Text(
              'This action cannot be undone.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete',
                    style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        ).then((confirmed) {
          if (confirmed == true) onDelete?.call(message);
        });
      } else if (value == 'copy') {
        // Clipboard handled by parent if needed
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final agentColor = AgentColors.forAgent(message.agentSlug);
    final agentName = AgentColors.displayName(message.agentSlug);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: GestureDetector(
        onLongPressStart: isUser
            ? (details) => _showContextMenu(context, details.globalPosition)
            : null,
        child: Row(
          mainAxisAlignment:
              isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isUser) ...[
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
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
                    child: _buildContent(),
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
      ),
    );
  }

  Widget _buildContent() {
    final files = message.metadata?['files'] as List?;
    final hasFiles = files != null && files.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.content != null && message.content!.isNotEmpty)
          Text(
            message.content!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        if (hasFiles) ...[
          if (message.content != null && message.content!.isNotEmpty)
            const SizedBox(height: 6),
          ...files!.map((f) {
            final name = f['name'] as String? ?? 'file';
            final mime = f['mimeType'] as String? ?? '';
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_fileIcon(mime), size: 16, color: _fileColor(mime)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      name,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          decoration: TextDecoration.underline),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  static IconData _fileIcon(String mime) {
    if (mime.startsWith('image/')) return Icons.image;
    if (mime.startsWith('video/')) return Icons.videocam;
    if (mime.contains('pdf')) return Icons.picture_as_pdf;
    if (mime.contains('spreadsheet') || mime.contains('excel')) {
      return Icons.table_chart;
    }
    return Icons.insert_drive_file;
  }

  static Color _fileColor(String mime) {
    if (mime.startsWith('image/')) return Colors.green;
    if (mime.startsWith('video/')) return Colors.purple;
    if (mime.contains('pdf')) return Colors.red;
    if (mime.contains('spreadsheet') || mime.contains('excel')) {
      return Colors.green.shade700;
    }
    return Colors.blue;
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
