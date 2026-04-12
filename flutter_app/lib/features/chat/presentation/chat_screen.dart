import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agentteam/core/theme/agent_colors.dart';
import 'package:agentteam/features/chat/presentation/chat_providers.dart';
import 'package:agentteam/features/chat/presentation/widgets/agent_typing_indicator.dart';
import 'package:agentteam/features/chat/presentation/widgets/message_bubble.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String threadId;
  final String? threadTitle;

  const ChatScreen({
    super.key,
    required this.threadId,
    this.threadTitle,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  OverlayEntry? _mentionOverlay;
  bool _showMentionPopup = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _messageController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _mentionOverlay?.remove();
    super.dispose();
  }

  void _onScroll() {
    // Pagination: when user scrolls near the top (in reverse list, that's maxScrollExtent)
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      ref.read(messagesProvider(widget.threadId).notifier).loadMore();
    }
  }

  void _onTextChanged() {
    final text = _messageController.text;
    final cursorPos = _messageController.selection.baseOffset;

    if (cursorPos > 0 && cursorPos <= text.length) {
      // Find the last '@' before cursor that isn't preceded by a non-space char
      final beforeCursor = text.substring(0, cursorPos);
      final atIndex = beforeCursor.lastIndexOf('@');

      if (atIndex >= 0 &&
          (atIndex == 0 || beforeCursor[atIndex - 1] == ' ')) {
        if (!_showMentionPopup) {
          setState(() => _showMentionPopup = true);
          _showMentionOverlay();
        }
        return;
      }
    }

    if (_showMentionPopup) {
      _hideMentionOverlay();
    }
  }

  void _showMentionOverlay() {
    _mentionOverlay?.remove();

    _mentionOverlay = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 80,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: AgentColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: AgentColors.allAgents.map((agent) {
                return InkWell(
                  onTap: () => _insertMention(agent.slug),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: agent.color,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              agent.name[0],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          agent.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_mentionOverlay!);
  }

  void _hideMentionOverlay() {
    _mentionOverlay?.remove();
    _mentionOverlay = null;
    if (_showMentionPopup) {
      setState(() => _showMentionPopup = false);
    }
  }

  void _insertMention(String slug) {
    final text = _messageController.text;
    final cursorPos = _messageController.selection.baseOffset;
    final beforeCursor = text.substring(0, cursorPos);
    final atIndex = beforeCursor.lastIndexOf('@');

    if (atIndex >= 0) {
      final newText =
          '${text.substring(0, atIndex)}@$slug ${text.substring(cursorPos)}';
      _messageController.text = newText;
      final newCursorPos = atIndex + slug.length + 2;
      _messageController.selection =
          TextSelection.collapsed(offset: newCursorPos);
    }

    _hideMentionOverlay();
    _focusNode.requestFocus();
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    _messageController.clear();
    _hideMentionOverlay();

    setState(() => _isSending = true);
    try {
      final sendFn = ref.read(sendMessageProvider(widget.threadId));
      await sendFn(content);
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
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesProvider(widget.threadId));

    return Scaffold(
      backgroundColor: AgentColors.background,
      appBar: AppBar(
        backgroundColor: AgentColors.surface,
        leading: BackButton(color: Colors.white.withValues(alpha: 0.7)),
        title: Text(
          widget.threadTitle ?? 'Chat',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(
                child:
                    CircularProgressIndicator(color: AgentColors.lawyer),
              ),
              error: (err, _) => Center(
                child: Text(
                  'Error loading messages',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5)),
                ),
              ),
              data: (state) {
                final messages = state.messages;

                if (messages.isEmpty && !state.agentTyping) {
                  return Center(
                    child: Text(
                      'Send a message to get started',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 15,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  itemCount:
                      messages.length + (state.agentTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    // Typing indicator at position 0 (bottom in reverse list)
                    if (state.agentTyping && index == 0) {
                      return const AgentTypingIndicator();
                    }

                    final adjustedIndex =
                        state.agentTyping ? index - 1 : index;

                    final message = messages[adjustedIndex];
                    return MessageBubble(
                      message: message,
                      isUser: message.isUser,
                    );
                  },
                );
              },
            ),
          ),

          // Input area
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: AgentColors.surface,
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            icon: Icon(
              Icons.attach_file,
              color: Colors.white.withValues(alpha: 0.4),
            ),
            onPressed: () {
              // Attachment functionality placeholder
            },
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _focusNode,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              maxLines: 5,
              minLines: 1,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'Message... (@ to mention agent)',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.25),
                  fontSize: 15,
                ),
                filled: true,
                fillColor: AgentColors.card,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: _isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AgentColors.lawyer,
                    ),
                  )
                : const Icon(
                    Icons.send_rounded,
                    color: AgentColors.lawyer,
                  ),
            onPressed: _isSending ? null : _sendMessage,
          ),
        ],
      ),
    );
  }
}
