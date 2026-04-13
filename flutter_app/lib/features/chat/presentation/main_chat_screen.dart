import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  OverlayEntry? _mentionOverlay;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _mentionOverlay?.remove();
    super.dispose();
  }

  void _showMentionPicker() {
    _mentionOverlay?.remove();
    final overlay = Overlay.of(context);
    _mentionOverlay = OverlayEntry(
      builder: (context) => Positioned(
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
                  _mentionOverlay?.remove();
                  _mentionOverlay = null;
                  _focusNode.requestFocus();
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
    overlay.insert(_mentionOverlay!);
  }

  Future<void> _sendMessage(String threadId) async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      await ref.read(messagesProvider(threadId).notifier).sendMessage(text);
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
          onSend: () => _sendMessage(threadId),
          onMention: _showMentionPicker,
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
  final VoidCallback onSend;
  final VoidCallback onMention;

  const _ChatBody({
    required this.threadId,
    required this.messageController,
    required this.scrollController,
    required this.focusNode,
    required this.isSending,
    required this.onSend,
    required this.onMention,
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
            child: Row(
              children: [
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
          ),
        ),
      ],
    );
  }
}
