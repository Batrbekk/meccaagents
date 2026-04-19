import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:agentteam/core/theme/app_theme.dart';
import 'package:agentteam/core/theme/agent_colors.dart';
import 'package:agentteam/features/chat/data/chat_repository.dart';
import 'package:agentteam/features/chat/presentation/chat_providers.dart';
import 'package:agentteam/features/chat/presentation/widgets/agent_typing_indicator.dart';
import 'package:agentteam/features/chat/presentation/widgets/message_bubble.dart';


/// Provider that auto-creates or loads the single main thread.
final mainThreadIdProvider = FutureProvider<String>((ref) async {
  final repo = ChatRepository();
  final threads = await repo.getThreads();

  if (threads.isNotEmpty) {
    return threads.first.id;
  }

  // First time — create the main thread
  final thread = await repo.createThread('AgentTeam Chat');
  return thread.id;
});

class MainChatScreen extends ConsumerStatefulWidget {
  const MainChatScreen({super.key});

  @override
  ConsumerState<MainChatScreen> createState() => _MainChatScreenState();
}

class _MainChatScreenState extends ConsumerState<MainChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  bool _isSending = false;
  bool _isUploading = false;
  OverlayEntry? _mentionOverlay;
  final List<_AttachedFile> _attachedFiles = [];

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _mentionOverlay?.remove();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: [
        'pdf', 'txt', 'doc', 'docx', 'xls', 'xlsx', 'csv',
        'jpg', 'jpeg', 'png', 'gif', 'webp',
        'mp4', 'mov', 'avi',
      ],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    setState(() => _isUploading = true);

    final repo = ChatRepository();
    final threadId = ref.read(mainThreadIdProvider).value;

    for (final file in result.files) {
      if (file.bytes == null) continue;
      try {
        final uploaded = await repo.uploadFile(
          file.bytes!,
          file.name,
          _guessMimeType(file.name),
          threadId: threadId,
        );
        setState(() {
          _attachedFiles.add(_AttachedFile(
            id: uploaded['id'] as String,
            name: file.name,
            mimeType: uploaded['mimeType'] as String? ?? _guessMimeType(file.name),
            sizeBytes: file.size,
          ));
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload ${file.name}: $e'),
                backgroundColor: Colors.red.shade700),
          );
        }
      }
    }

    if (mounted) setState(() => _isUploading = false);
  }

  String _guessMimeType(String name) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'pdf' => 'application/pdf',
      'txt' => 'text/plain',
      'doc' => 'application/msword',
      'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls' => 'application/vnd.ms-excel',
      'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'csv' => 'text/csv',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'avi' => 'video/x-msvideo',
      _ => 'application/octet-stream',
    };
  }

  void _removeAttachment(int index) {
    setState(() => _attachedFiles.removeAt(index));
  }

  void _closeMentionPicker() {
    _mentionOverlay?.remove();
    _mentionOverlay = null;
  }

  void _showMentionPicker() {
    if (_mentionOverlay != null) {
      _closeMentionPicker();
      return;
    }
    final overlay = Overlay.of(context);
    _mentionOverlay = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Transparent barrier — tap to close
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeMentionPicker,
              behavior: HitTestBehavior.opaque,
              child: const ColoredBox(color: Colors.transparent),
            ),
          ),
          // Agent picker
          Positioned(
            bottom: 80,
            left: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: AgentColors.allAgents.map((agent) {
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: agent.color,
                      radius: 16,
                      child: Text(
                        agent.name[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(agent.name,
                        style: GoogleFonts.inter(
                          color: AppTheme.foregroundPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        )),
                    subtitle: Text('@${agent.slug}',
                        style: GoogleFonts.inter(
                            color: AgentColors.placeholder,
                            fontSize: 12)),
                    onTap: () {
                      final text = _messageController.text;
                      final atIndex = text.lastIndexOf('@');
                      if (atIndex >= 0) {
                        _messageController.text =
                            '${text.substring(0, atIndex)}@${agent.slug} ';
                      } else {
                        _messageController.text = '$text@${agent.slug} ';
                      }
                      _messageController.selection = TextSelection.fromPosition(
                        TextPosition(offset: _messageController.text.length),
                      );
                      _closeMentionPicker();
                      _focusNode.requestFocus();
                    },
                  );
                }).toList(),
              ),
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(_mentionOverlay!);
  }

  Future<void> _sendMessage(String threadId) async {
    final text = _messageController.text.trim();
    if (text.isEmpty && _attachedFiles.isEmpty) return;
    if (_isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      // Build message content with file references
      final fileRefs = _attachedFiles.map((f) => '[${f.name}]').join(' ');
      final content = _attachedFiles.isNotEmpty
          ? '$text ${fileRefs}'.trim()
          : text;

      final files = _attachedFiles
          .map((f) => {
                'id': f.id,
                'name': f.name,
                'mimeType': f.mimeType,
                'sizeBytes': f.sizeBytes,
              })
          .toList();

      await ref.read(messagesProvider(threadId).notifier).sendMessageWithFiles(
        content,
        files: files.isNotEmpty ? files : null,
      );

      setState(() => _attachedFiles.clear());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final threadAsync = ref.watch(mainThreadIdProvider);

    return Scaffold(
      backgroundColor: AgentColors.background,
      body: SafeArea(
        child: threadAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.accentPrimary),
          ),
          error: (err, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Failed to load chat',
                    style: GoogleFonts.inter(
                      color: AppTheme.foregroundSecondary,
                    )),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => ref.invalidate(mainThreadIdProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (threadId) => _ChatBody(
            threadId: threadId,
            messageController: _messageController,
            scrollController: _scrollController,
            focusNode: _focusNode,
            isSending: _isSending,
            isUploading: _isUploading,
            attachedFiles: _attachedFiles,
            onSend: () => _sendMessage(threadId),
            onMention: _showMentionPicker,
            onMentionClose: _closeMentionPicker,
            onPickFiles: _pickFiles,
            onRemoveAttachment: _removeAttachment,
          ),
        ),
      ),
    );
  }
}

class _ChatBody extends ConsumerWidget {
  final String threadId;
  final TextEditingController messageController;
  final ScrollController scrollController;
  final FocusNode focusNode;
  final bool isSending;
  final bool isUploading;
  final List<_AttachedFile> attachedFiles;
  final VoidCallback onSend;
  final VoidCallback onMention;
  final VoidCallback onMentionClose;
  final VoidCallback onPickFiles;
  final void Function(int) onRemoveAttachment;

  const _ChatBody({
    required this.threadId,
    required this.messageController,
    required this.scrollController,
    required this.focusNode,
    required this.isSending,
    required this.isUploading,
    required this.attachedFiles,
    required this.onSend,
    required this.onMention,
    required this.onMentionClose,
    required this.onPickFiles,
    required this.onRemoveAttachment,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(messagesProvider(threadId));

    final screenW = MediaQuery.of(context).size.width;
    final hPad = screenW > 400 ? 16.0 : 8.0;

    return Column(
      children: [
        // ---- Header area ----
        Padding(
          padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title "Chat" — Anton 28px
              Text(
                'Chat',
                style: GoogleFonts.anton(
                  fontSize: 28,
                  color: AppTheme.foregroundPrimary,
                ),
              ),
              const SizedBox(height: 10),
              // Agent chips row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: AgentColors.allAgents.map((a) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AgentColors.card,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: a.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              a.name,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.foregroundPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        // ---- Messages ----
        Expanded(
          child: messagesAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppTheme.accentPrimary),
            ),
            error: (err, _) => Center(
              child: Text('Error: $err',
                  style: GoogleFonts.inter(
                    color: AppTheme.foregroundSecondary,
                  )),
            ),
            data: (state) {
              if (state.messages.isEmpty && !state.agentTyping) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 64,
                          color: AppTheme.foregroundTertiary.withValues(alpha: 0.4)),
                      const SizedBox(height: 16),
                      Text(
                        'Start a conversation with your AI team',
                        style: GoogleFonts.inter(
                            color: AppTheme.foregroundSecondary,
                            fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Use @agent to mention a specific agent\ne.g. @content create a content plan',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                            color: AppTheme.foregroundTertiary,
                            fontSize: 13),
                      ),
                    ],
                  ),
                );
              }

              return NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollEndNotification &&
                      scrollController.position.pixels >=
                          scrollController.position.maxScrollExtent - 100) {
                    ref
                        .read(messagesProvider(threadId).notifier)
                        .loadMore();
                  }
                  return false;
                },
                child: ListView.builder(
                  controller: scrollController,
                  reverse: true,
                  padding:
                      EdgeInsets.symmetric(horizontal: hPad, vertical: 8),
                  itemCount: state.messages.length +
                      (state.agentTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (state.agentTyping && index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AgentTypingIndicator(agentSlug: state.typingAgentSlug),
                      );
                    }
                    final msgIndex =
                        state.agentTyping ? index - 1 : index;
                    final message = state.messages[msgIndex];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: MessageBubble(
                        message: message,
                        isUser: message.senderType == 'user',
                        onDelete: message.senderType == 'user'
                            ? (msg) async {
                                final repo = ChatRepository();
                                try {
                                  await repo.deleteMessage(threadId, msg.id);
                                  ref.invalidate(messagesProvider(threadId));
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Failed to delete: $e'),
                                          backgroundColor: Colors.red.shade700),
                                    );
                                  }
                                }
                              }
                            : null,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),

        // ---- Input bar ----
        Container(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 8),
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Color(0xFFE5E7EB), width: 1),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Attached files preview
                if (attachedFiles.isNotEmpty)
                  Container(
                    height: 60,
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: attachedFiles.length,
                      itemBuilder: (context, index) {
                        final file = attachedFiles[index];
                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AgentColors.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AgentColors.borderColor),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_fileIcon(file.mimeType),
                                  size: 18, color: _fileColor(file.mimeType)),
                              const SizedBox(width: 6),
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 120),
                                child: Text(
                                  file.name,
                                  style: GoogleFonts.inter(
                                      color: AppTheme.foregroundSecondary,
                                      fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () => onRemoveAttachment(index),
                                child: Icon(Icons.close,
                                    size: 14, color: AppTheme.foregroundTertiary),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                if (isUploading)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: LinearProgressIndicator(
                        color: AppTheme.accentPrimary,
                        backgroundColor: AgentColors.card),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Paperclip icon
                    GestureDetector(
                      onTap: isUploading ? null : onPickFiles,
                      child: Icon(
                        Icons.attach_file,
                        size: 22,
                        color: AppTheme.foregroundSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Input field — pill shape
                    Expanded(
                      child: TextField(
                        controller: messageController,
                        focusNode: focusNode,
                        style: GoogleFonts.inter(
                          color: AppTheme.foregroundPrimary,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText: 'Message agents...',
                          hintStyle: GoogleFonts.inter(
                            color: const Color(0xFF9CA3AF),
                            fontSize: 14,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF3F4F6),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                          onChanged: (text) {
                            if (text.endsWith('@')) {
                              onMention();
                            } else if (!text.contains('@')) {
                              // Close mention picker when @ is deleted
                              onMentionClose();
                            }
                          },
                          onSubmitted: (_) => onSend(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Send button — accent circle 36x36
                    GestureDetector(
                      onTap: isSending ? null : onSend,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: AppTheme.accentPrimary,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: isSending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.arrow_upward,
                                  color: Colors.white,
                                  size: 18,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static IconData _fileIcon(String mimeType) {
    if (mimeType.startsWith('image/')) return Icons.image;
    if (mimeType.startsWith('video/')) return Icons.videocam;
    if (mimeType.contains('pdf')) return Icons.picture_as_pdf;
    if (mimeType.contains('spreadsheet') || mimeType.contains('excel') || mimeType.contains('csv')) {
      return Icons.table_chart;
    }
    if (mimeType.contains('word') || mimeType.contains('document')) return Icons.description;
    return Icons.insert_drive_file;
  }

  static Color _fileColor(String mimeType) {
    if (mimeType.startsWith('image/')) return Colors.green;
    if (mimeType.startsWith('video/')) return Colors.purple;
    if (mimeType.contains('pdf')) return Colors.red;
    if (mimeType.contains('spreadsheet') || mimeType.contains('excel')) return Colors.green.shade700;
    return Colors.blue;
  }
}

class _AttachedFile {
  final String id;
  final String name;
  final String mimeType;
  final int sizeBytes;

  const _AttachedFile({
    required this.id,
    required this.name,
    required this.mimeType,
    required this.sizeBytes,
  });
}
