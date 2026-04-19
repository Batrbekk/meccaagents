import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:agentteam/core/theme/app_theme.dart';
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

    if (cursorPos >= 0 && cursorPos <= text.length && text.isNotEmpty) {
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AgentColors.borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
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
                              style: GoogleFonts.inter(
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
                          style: GoogleFonts.inter(
                            color: AppTheme.foregroundPrimary,
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
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: BackButton(color: AppTheme.foregroundPrimary),
        title: Text(
          widget.threadTitle ?? 'Chat',
          style: GoogleFonts.anton(
            color: AppTheme.foregroundPrimary,
            fontSize: 28,
          ),
        ),
      ),
      body: Column(
        children: [
          // Agent chips row
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 8),
            child: SingleChildScrollView(
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
          ),

          // Messages
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.accentPrimary),
              ),
              error: (err, _) => Center(
                child: Text(
                  'Error loading messages',
                  style: GoogleFonts.inter(
                    color: AppTheme.foregroundSecondary,
                  ),
                ),
              ),
              data: (state) {
                final messages = state.messages;

                if (messages.isEmpty && !state.agentTyping) {
                  return Center(
                    child: Text(
                      'Send a message to get started',
                      style: GoogleFonts.inter(
                        color: AppTheme.foregroundTertiary,
                        fontSize: 15,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  itemCount:
                      messages.length + (state.agentTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    // Typing indicator at position 0 (bottom in reverse list)
                    if (state.agentTyping && index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AgentTypingIndicator(agentSlug: state.typingAgentSlug),
                      );
                    }

                    final adjustedIndex =
                        state.agentTyping ? index - 1 : index;

                    final message = messages[adjustedIndex];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: MessageBubble(
                        message: message,
                        isUser: message.isUser,
                      ),
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
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Paperclip icon
          GestureDetector(
            onTap: () {
              // Attachment functionality placeholder
            },
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
              controller: _messageController,
              focusNode: _focusNode,
              style: GoogleFonts.inter(
                color: AppTheme.foregroundPrimary,
                fontSize: 14,
              ),
              maxLines: 1,
              minLines: 1,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'Message agents...',
                hintStyle: GoogleFonts.inter(
                  color: AgentColors.placeholder,
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
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          // Send button — accent circle 36x36
          GestureDetector(
            onTap: _isSending ? null : _sendMessage,
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppTheme.accentPrimary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: _isSending
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
    );
  }
}
