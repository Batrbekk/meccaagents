import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/agent_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/approval_providers.dart';
import '../data/approval_repository.dart';
import '../domain/approval_task.dart';

class ApprovalDetailScreen extends ConsumerStatefulWidget {
  final String approvalId;

  const ApprovalDetailScreen({super.key, required this.approvalId});

  @override
  ConsumerState<ApprovalDetailScreen> createState() =>
      _ApprovalDetailScreenState();
}

class _ApprovalDetailScreenState extends ConsumerState<ApprovalDetailScreen> {
  final _notesController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(approvalDetailProvider(widget.approvalId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Approval Detail'),
      ),
      body: detailAsync.when(
        data: (task) => _buildContent(context, task),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text('Failed to load approval: $error'),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(
                  approvalDetailProvider(widget.approvalId),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ApprovalTask task) {
    final agentColor = AgentColors.forSlug(task.agentSlug);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Agent header
              _buildAgentHeader(context, task, agentColor),
              const SizedBox(height: 16),

              // Action type + status
              _buildInfoSection(context, task),
              const SizedBox(height: 16),

              // Payload
              _buildPayloadSection(context, task),
              const SizedBox(height: 16),

              // Timeline
              _buildTimelineSection(context, task),
              const SizedBox(height: 16),

              // Notes input (only for pending)
              if (task.isPending) _buildNotesInput(context),
            ],
          ),
        ),

        // Action buttons (only for pending)
        if (task.isPending) _buildActionBar(context, task),
      ],
    );
  }

  Widget _buildAgentHeader(
    BuildContext context,
    ApprovalTask task,
    Color agentColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: agentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: agentColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: agentColor.withValues(alpha: 0.2),
            child: Icon(
              AgentColors.icon(task.agentSlug),
              color: agentColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AgentColors.displayName(task.agentSlug),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: agentColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  task.actionLabel,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context, ApprovalTask task) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Details',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            _InfoRow(label: 'Status', value: task.status.toUpperCase()),
            const SizedBox(height: 8),
            _InfoRow(label: 'Action', value: task.actionLabel),
            const SizedBox(height: 8),
            _InfoRow(label: 'Agent', value: AgentColors.displayName(task.agentSlug)),
            if (task.notes != null) ...[
              const SizedBox(height: 8),
              _InfoRow(label: 'Notes', value: task.notes!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPayloadSection(BuildContext context, ApprovalTask task) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payload',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            // Display text content if available
            if (task.payload.containsKey('text') ||
                task.payload.containsKey('content') ||
                task.payload.containsKey('caption'))
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border),
                ),
                child: SelectableText(
                  (task.payload['text'] ??
                          task.payload['content'] ??
                          task.payload['caption'] ??
                          '')
                      .toString(),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            // Display image URL if available
            if (task.payload.containsKey('imageUrl') ||
                task.payload.containsKey('image_url')) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  (task.payload['imageUrl'] ?? task.payload['image_url'])
                      .toString(),
                  fit: BoxFit.cover,
                  errorBuilder: (_, e, st) => Container(
                    height: 120,
                    color: AppTheme.surface,
                    child: const Center(
                      child: Icon(Icons.broken_image_outlined, size: 40),
                    ),
                  ),
                ),
              ),
            ],
            // Show all key-value pairs
            const SizedBox(height: 12),
            ...task.payload.entries.map((entry) {
              if (entry.key == 'text' ||
                  entry.key == 'content' ||
                  entry.key == 'caption' ||
                  entry.key == 'imageUrl' ||
                  entry.key == 'image_url') {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _InfoRow(
                  label: entry.key,
                  value: entry.value.toString(),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineSection(BuildContext context, ApprovalTask task) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Timeline',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            _TimelineEntry(
              icon: Icons.schedule,
              color: AppTheme.warning,
              label: 'Requested',
              time: _formatDateTime(task.requestedAt),
            ),
            if (task.resolvedAt != null) ...[
              const SizedBox(height: 8),
              _TimelineEntry(
                icon: task.isApproved
                    ? Icons.check_circle
                    : Icons.cancel,
                color: task.isApproved ? AppTheme.success : Theme.of(context).colorScheme.error,
                label: task.isApproved ? 'Approved' : 'Rejected',
                time: _formatDateTime(task.resolvedAt!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotesInput(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notes / Modifications',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Add notes or modification instructions...',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBar(BuildContext context, ApprovalTask task) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Reject
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isProcessing ? null : () => _handleReject(task),
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Reject'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.error.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Modify
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isProcessing ? null : () => _handleModify(task),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Modify'),
              ),
            ),
            const SizedBox(width: 8),
            // Approve
            Expanded(
              child: FilledButton.icon(
                onPressed: _isProcessing ? null : () => _handleApprove(task),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Approve'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.success,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleApprove(ApprovalTask task) async {
    final confirmed = await _showConfirmDialog(
      title: 'Approve Action',
      message:
          'Are you sure you want to approve "${task.actionLabel}"? This action will be executed.',
      confirmLabel: 'Approve',
      confirmColor: AppTheme.success,
    );
    if (confirmed != true) return;

    await _executeAction(() async {
      await ref.read(approvalRepositoryProvider).approve(task.id);
      _showSuccess('Approved successfully');
    });
  }

  Future<void> _handleReject(ApprovalTask task) async {
    final confirmed = await _showConfirmDialog(
      title: 'Reject Action',
      message:
          'Are you sure you want to reject "${task.actionLabel}"? This action will not be executed.',
      confirmLabel: 'Reject',
      confirmColor: Theme.of(context).colorScheme.error,
    );
    if (confirmed != true) return;

    await _executeAction(() async {
      final notes =
          _notesController.text.trim().isEmpty ? null : _notesController.text.trim();
      await ref.read(approvalRepositoryProvider).reject(task.id, notes: notes);
      _showSuccess('Rejected');
    });
  }

  Future<void> _handleModify(ApprovalTask task) async {
    if (_notesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add modification notes before modifying'),
        ),
      );
      return;
    }

    await _executeAction(() async {
      await ref.read(approvalRepositoryProvider).modify(
            task.id,
            task.payload,
            notes: _notesController.text.trim(),
          );
      _showSuccess('Modified and approved');
    });
  }

  Future<void> _executeAction(Future<void> Function() action) async {
    setState(() => _isProcessing = true);
    try {
      await action();
      ref.invalidate(approvalDetailProvider(widget.approvalId));
      ref.invalidate(approvalListProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: confirmColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatDateTime(DateTime dt) {
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.year}-$month-$day $hour:$minute';
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String time;

  const _TimelineEntry({
    required this.icon,
    required this.color,
    required this.label,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
        const Spacer(),
        Text(
          time,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
