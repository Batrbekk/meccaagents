import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:agentteam/core/theme/agent_colors.dart';
import 'package:agentteam/features/auth/presentation/auth_provider.dart';
import 'package:agentteam/features/chat/domain/thread.dart';
import 'package:agentteam/features/chat/presentation/chat_providers.dart';

class ThreadListScreen extends ConsumerWidget {
  const ThreadListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threadsAsync = ref.watch(threadListProvider);

    return Scaffold(
      backgroundColor: AgentColors.background,
      appBar: AppBar(
        backgroundColor: AgentColors.surface,
        title: const Text(
          'AgentTeam',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white54),
            tooltip: 'Sign out',
            onPressed: () async {
              await ref.read(authStateProvider.notifier).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
      body: threadsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AgentColors.lawyer),
        ),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Failed to load threads',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.read(threadListProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (threads) {
          if (threads.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No threads yet. Start a conversation!',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: AgentColors.lawyer,
            backgroundColor: AgentColors.surface,
            onRefresh: () =>
                ref.read(threadListProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: threads.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                color: Colors.white.withValues(alpha: 0.06),
                indent: 16,
                endIndent: 16,
              ),
              itemBuilder: (context, index) {
                return _ThreadTile(thread: threads[index]);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AgentColors.lawyer,
        onPressed: () => _showCreateDialog(context, ref),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AgentColors.surface,
        title: const Text(
          'New Thread',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Thread title...',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            filled: true,
            fillColor: AgentColors.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (value) async {
            if (value.trim().isNotEmpty) {
              Navigator.of(ctx).pop();
              final thread = await ref
                  .read(threadListProvider.notifier)
                  .createThread(value.trim());
              if (context.mounted) {
                context.go('/threads/${thread.id}');
              }
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AgentColors.lawyer,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final title = controller.text.trim();
              if (title.isNotEmpty) {
                Navigator.of(ctx).pop();
                final thread = await ref
                    .read(threadListProvider.notifier)
                    .createThread(title);
                if (context.mounted) {
                  context.go('/threads/${thread.id}');
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class _ThreadTile extends StatelessWidget {
  final ChatThread thread;

  const _ThreadTile({required this.thread});

  @override
  Widget build(BuildContext context) {
    final senderColor = thread.lastMessageSender != null
        ? AgentColors.forAgent(thread.lastMessageSender!)
        : Colors.white24;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: senderColor,
          shape: BoxShape.circle,
        ),
      ),
      title: Text(
        thread.title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: thread.lastMessageContent != null
          ? Text(
              thread.lastMessageContent!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: thread.lastMessageAt != null
          ? Text(
              _formatTimestamp(thread.lastMessageAt!),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 12,
              ),
            )
          : null,
      onTap: () => context.go('/threads/${thread.id}'),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inDays > 0) {
      return '${dt.day}/${dt.month}';
    }
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
