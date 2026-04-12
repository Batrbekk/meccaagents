import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/agent_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/approval_providers.dart';
import '../domain/approval_task.dart';
import '../data/approval_repository.dart';

class ApprovalListScreen extends ConsumerWidget {
  const ApprovalListScreen({super.key});

  static const _filters = ['pending', 'approved', 'rejected', 'all'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentFilter = ref.watch(approvalFilterProvider);
    final approvalsAsync = ref.watch(approvalListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Approvals'),
      ),
      body: Column(
        children: [
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: _filters.map((filter) {
                final isSelected = currentFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      filter[0].toUpperCase() + filter.substring(1),
                    ),
                    selected: isSelected,
                    onSelected: (_) {
                      ref.read(approvalFilterProvider.notifier).setFilter(filter);
                    },
                    selectedColor: AppTheme.surface,
                    checkmarkColor: Theme.of(context).colorScheme.primary,
                    side: BorderSide(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : AppTheme.border,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),
          // Approval list
          Expanded(
            child: approvalsAsync.when(
              data: (approvals) {
                if (approvals.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 64,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No $currentFilter approvals',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(approvalListProvider);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: approvals.length,
                    itemBuilder: (context, index) {
                      return _ApprovalCard(
                        task: approvals[index],
                        onTap: () {
                          context.push('/approvals/${approvals[index].id}');
                        },
                        onApprove: approvals[index].isPending
                            ? () => _quickApprove(context, ref, approvals[index])
                            : null,
                        onReject: approvals[index].isPending
                            ? () => _quickReject(context, ref, approvals[index])
                            : null,
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: AppTheme.card),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to load approvals',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => ref.invalidate(approvalListProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _quickApprove(
    BuildContext context,
    WidgetRef ref,
    ApprovalTask task,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Action'),
        content: Text('Approve "${task.actionLabel}" by '
            '${AgentColors.displayName(task.agentSlug)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(approvalRepositoryProvider).approve(task.id);
      ref.invalidate(approvalListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Approved successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to approve: $e')),
        );
      }
    }
  }

  Future<void> _quickReject(
    BuildContext context,
    WidgetRef ref,
    ApprovalTask task,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Action'),
        content: Text('Reject "${task.actionLabel}" by '
            '${AgentColors.displayName(task.agentSlug)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(approvalRepositoryProvider).reject(task.id);
      ref.invalidate(approvalListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rejected')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reject: $e')),
        );
      }
    }
  }
}

class _ApprovalCard extends StatelessWidget {
  final ApprovalTask task;
  final VoidCallback onTap;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _ApprovalCard({
    required this.task,
    required this.onTap,
    this.onApprove,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final agentColor = AgentColors.forSlug(task.agentSlug);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Left color stripe
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: agentColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Agent + status row
                      Row(
                        children: [
                          Icon(
                            AgentColors.icon(task.agentSlug),
                            size: 18,
                            color: agentColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            AgentColors.displayName(task.agentSlug),
                            style:
                                Theme.of(context).textTheme.labelLarge?.copyWith(
                                      color: agentColor,
                                    ),
                          ),
                          const Spacer(),
                          _StatusBadge(status: task.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Action type
                      Text(
                        task.actionLabel,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      // Payload preview
                      Text(
                        task.payloadPreview,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      // Bottom row: timestamp + actions
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatTime(task.requestedAt),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          const Spacer(),
                          if (onApprove != null) ...[
                            _ActionIconButton(
                              icon: Icons.check_circle_outline,
                              color: AppTheme.success,
                              onPressed: onApprove!,
                              tooltip: 'Approve',
                            ),
                            const SizedBox(width: 4),
                          ],
                          if (onReject != null)
                            _ActionIconButton(
                              icon: Icons.cancel_outlined,
                              color: Theme.of(context).colorScheme.error,
                              onPressed: onReject!,
                              tooltip: 'Reject',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final String tooltip;

  const _ActionIconButton({
    required this.icon,
    required this.color,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, size: 20, color: color),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color bgColor, Color fgColor, String label) = switch (status) {
      'pending' => (
          AppTheme.warning.withValues(alpha: 0.15),
          AppTheme.warning,
          'Pending',
        ),
      'approved' => (
          AppTheme.success.withValues(alpha: 0.15),
          AppTheme.success,
          'Approved',
        ),
      'rejected' => (
          Theme.of(context).colorScheme.error.withValues(alpha: 0.15),
          Theme.of(context).colorScheme.error,
          'Rejected',
        ),
      _ => (
          AppTheme.border,
          AppTheme.textSecondary,
          status[0].toUpperCase() + status.substring(1),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fgColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
