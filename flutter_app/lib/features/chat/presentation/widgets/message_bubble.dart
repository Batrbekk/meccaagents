import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:agentteam/core/theme/app_theme.dart';
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
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AgentColors.borderColor),
      ),
      items: [
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
              const SizedBox(width: 8),
              Text('Delete', style: GoogleFonts.inter(color: Colors.redAccent)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'copy',
          child: Row(
            children: [
              Icon(Icons.copy, color: AppTheme.foregroundSecondary, size: 20),
              const SizedBox(width: 8),
              Text('Copy', style: GoogleFonts.inter(color: AppTheme.foregroundSecondary)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'delete') {
        showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            title: Text('Delete message?',
                style: GoogleFonts.inter(
                  color: AppTheme.foregroundPrimary,
                  fontWeight: FontWeight.w600,
                )),
            content: Text(
              'This action cannot be undone.',
              style: GoogleFonts.inter(color: AppTheme.foregroundSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel',
                    style: GoogleFonts.inter(color: AppTheme.foregroundSecondary)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Delete',
                    style: GoogleFonts.inter(color: Colors.redAccent)),
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

    final screenWidth = MediaQuery.of(context).size.width;
    final maxBubble = screenWidth > 400 ? 240.0 : screenWidth * 0.6;

    if (isUser) {
      return GestureDetector(
        onLongPressStart: (details) => _showContextMenu(context, details.globalPosition),
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            constraints: BoxConstraints(maxWidth: maxBubble),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: AgentColors.userBubble,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(4),
                bottomLeft: Radius.circular(16),
              ),
            ),
            child: _buildContent(isUserMsg: true),
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          constraints: BoxConstraints(maxWidth: maxBubble),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: Color(0xFFF3F4F6),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                agentName,
                style: GoogleFonts.inter(
                  color: agentColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              _buildContent(isUserMsg: false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent({required bool isUserMsg}) {
    final files = message.metadata?['files'] as List?;
    final hasFiles = files != null && files.isNotEmpty;

    // Text colors
    final textColor = isUserMsg ? Colors.white : AppTheme.foregroundPrimary;
    final codeColor = isUserMsg ? Colors.white70 : const Color(0xFF059669);
    final codeBg = isUserMsg
        ? Colors.white.withValues(alpha: 0.1)
        : const Color(0xFFECFDF5);
    final linkColor = isUserMsg ? Colors.white : AppTheme.accentPrimary;
    final fileTextColor = isUserMsg ? Colors.white70 : AppTheme.foregroundSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.content != null && message.content!.isNotEmpty)
          MarkdownBody(
            data: message.content!,
            selectable: true,
            styleSheet: MarkdownStyleSheet(
              p: GoogleFonts.inter(color: textColor, fontSize: 14, height: 1.4),
              strong: GoogleFonts.inter(color: textColor, fontSize: 14, fontWeight: FontWeight.bold),
              em: GoogleFonts.inter(color: textColor, fontSize: 14, fontStyle: FontStyle.italic),
              h1: GoogleFonts.inter(color: textColor, fontSize: 22, fontWeight: FontWeight.bold),
              h2: GoogleFonts.inter(color: textColor, fontSize: 19, fontWeight: FontWeight.bold),
              h3: GoogleFonts.inter(color: textColor, fontSize: 16, fontWeight: FontWeight.w600),
              code: TextStyle(
                color: codeColor,
                backgroundColor: codeBg,
                fontSize: 13,
                fontFamily: 'monospace',
              ),
              codeblockDecoration: BoxDecoration(
                color: codeBg,
                borderRadius: BorderRadius.circular(8),
              ),
              listBullet: GoogleFonts.inter(color: textColor, fontSize: 14),
              a: GoogleFonts.inter(color: linkColor, decoration: TextDecoration.underline),
              blockquoteDecoration: BoxDecoration(
                border: Border(left: BorderSide(
                  color: isUserMsg
                      ? Colors.white.withValues(alpha: 0.3)
                      : AppTheme.foregroundTertiary,
                  width: 3,
                )),
              ),
              blockquote: GoogleFonts.inter(
                color: isUserMsg
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppTheme.foregroundSecondary,
                fontSize: 14,
              ),
            ),
          ),
        if (hasFiles) ...[
          if (message.content != null && message.content!.isNotEmpty)
            const SizedBox(height: 6),
          ...files.map((f) {
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
                      style: GoogleFonts.inter(
                          color: fileTextColor,
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

}
