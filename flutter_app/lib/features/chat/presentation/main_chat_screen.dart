import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:agentteam/core/theme/agent_colors.dart';
import 'package:agentteam/features/auth/presentation/auth_provider.dart';
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
            child: Material(
              color: AgentColors.card,
              borderRadius: BorderRadius.circular(12),
              elevation: 8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: AgentColors.allAgents.map((agent) {
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: agent.color,
                      radius: 16,
                      child: Icon(AgentColors.icon(agent.slug), size: 16, color: Colors.white),
                    ),
                    title: Text(agent.name,
                        style: const TextStyle(color: Colors.white)),
                    subtitle: Text('@${agent.slug}',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
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

      final repo = ChatRepository();
      await repo.sendMessageWithFiles(threadId, content, files: files.isNotEmpty ? files : null);

      // Refresh messages
      ref.invalidate(messagesProvider(threadId));

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
      appBar: AppBar(
        backgroundColor: AgentColors.surface,
        title: const Text('AgentTeam',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 1)),
        actions: [
          // Agent status indicators
          ...AgentColors.allAgents.map((agent) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Tooltip(
                  message: agent.name,
                  child: CircleAvatar(
                    backgroundColor: agent.color,
                    radius: 10,
                    child: Icon(AgentColors.icon(agent.slug), size: 11, color: Colors.white),
                  ),
                ),
              )),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white54),
            tooltip: 'Sign out',
            onPressed: () async {
              await ref.read(authStateProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: threadAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AgentColors.lawyer),
        ),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Failed to load chat',
                  style:
                      TextStyle(color: Colors.white.withValues(alpha: 0.7))),
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
          onPickFiles: _pickFiles,
          onRemoveAttachment: _removeAttachment,
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
    required this.onPickFiles,
    required this.onRemoveAttachment,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(messagesProvider(threadId));

    return Column(
      children: [
        // Agent bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AgentColors.surface,
          child: Row(
            children: [
              Text('Agents online: ',
                  style:
                      TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
              ...AgentColors.allAgents.map((a) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(
                      avatar: CircleAvatar(
                          backgroundColor: a.color,
                          radius: 8,
                          child: Icon(AgentColors.icon(a.slug), size: 9, color: Colors.white)),
                      label: Text(a.name,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11)),
                      backgroundColor: AgentColors.card,
                      side: BorderSide.none,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                  )),
            ],
          ),
        ),

        // Messages
        Expanded(
          child: messagesAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AgentColors.lawyer),
            ),
            error: (err, _) => Center(
              child: Text('Error: $err',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7))),
            ),
            data: (state) {
              if (state.messages.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.white.withValues(alpha: 0.2)),
                      const SizedBox(height: 16),
                      Text(
                        'Start a conversation with your AI team',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Use @agent to mention a specific agent\ne.g. @content create a content plan',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
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
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: state.messages.length +
                      (state.agentTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (state.agentTyping && index == 0) {
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: AgentTypingIndicator(),
                      );
                    }
                    final msgIndex =
                        state.agentTyping ? index - 1 : index;
                    final message = state.messages[msgIndex];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: MessageBubble(
                        message: message,
                        isUser: message.senderType == 'user',
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),

        // Input bar
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AgentColors.surface,
            border: Border(
              top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1)),
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
                            border: Border.all(
                                color:
                                    Colors.white.withValues(alpha: 0.1)),
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
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () => onRemoveAttachment(index),
                                child: const Icon(Icons.close,
                                    size: 14, color: Colors.white38),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                if (isUploading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: LinearProgressIndicator(
                        color: AgentColors.lawyer,
                        backgroundColor: AgentColors.card),
                  ),
                Row(
              children: [
                // Attach file button
                IconButton(
                  icon: const Icon(Icons.attach_file, color: Colors.white54),
                  onPressed: isUploading ? null : onPickFiles,
                  tooltip: 'Attach files (PDF, Excel, images, video)',
                ),
                // @ mention button
                IconButton(
                  icon:
                      const Icon(Icons.alternate_email, color: Colors.white54),
                  onPressed: onMention,
                  tooltip: 'Mention agent',
                ),
                // Text field
                Expanded(
                  child: TextField(
                    controller: messageController,
                    focusNode: focusNode,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 4,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: 'Message your AI team...',
                      hintStyle:
                          TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                      filled: true,
                      fillColor: AgentColors.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                    onChanged: (text) {
                      if (text.endsWith('@')) {
                        onMention();
                      }
                    },
                    onSubmitted: (_) => onSend(),
                  ),
                ),
                const SizedBox(width: 8),
                // Send button
                Container(
                  decoration: const BoxDecoration(
                    color: AgentColors.lawyer,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white),
                    onPressed: isSending ? null : onSend,
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
