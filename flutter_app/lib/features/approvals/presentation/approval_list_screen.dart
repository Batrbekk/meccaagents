import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/agent_colors.dart';
import '../data/approval_providers.dart';
import '../domain/approval_task.dart';
import '../data/approval_repository.dart';

// ---------------------------------------------------------------------------
// Light-theme palette (local to this screen)
// ---------------------------------------------------------------------------
class _C {
  _C._();
  static const surfacePrimary = Color(0xFFFFFFFF);
  static const borderLight = Color(0xFFF3F4F6);
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);

  // Accent primary — matches AppTheme.accentPrimary
  static const accentPrimary = Color(0xFF1F6FEB);

  // Status colors
  static const pendingBg = Color(0xFFFEF3C7);
  static const pendingFg = Color(0xFF92400E);
  static const approvedBg = Color(0xFFD1FAE5);
  static const approvedFg = Color(0xFF065F46);
  static const rejectedBg = Color(0xFFFEE2E2);
  static const rejectedFg = Color(0xFF991B1B);

  // Action button colors
  static const approveGreen = Color(0xFF10B981);
  static const rejectRed = Color(0xFFEF4444);

  // Tag bg
  static const tagBg = Color(0xFFF3F4F6);
}

class ApprovalListScreen extends ConsumerWidget {
  const ApprovalListScreen({super.key});

  static const _filters = ['all', 'pending', 'approved', 'rejected'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentFilter = ref.watch(approvalFilterProvider);
    final approvalsAsync = ref.watch(approvalListProvider);

    return Scaffold(
      backgroundColor: _C.surfacePrimary,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Text(
                'APPROVALS',
                style: GoogleFonts.anton(
                  fontSize: 28,
                  color: _C.textPrimary,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            // Filter chips row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = currentFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        ref
                            .read(approvalFilterProvider.notifier)
                            .setFilter(filter);
                      },
                      child: _FilterChip(
                        label: filter[0].toUpperCase() + filter.substring(1),
                        filter: filter,
                        isSelected: isSelected,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 12),

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
                            color: _C.textSecondary.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No $currentFilter approvals',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              color: _C.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return RefreshIndicator(
                    color: _C.accentPrimary,
                    onRefresh: () async {
                      ref.invalidate(approvalListProvider);
                    },
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      itemCount: approvals.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        return _ApprovalCard(
                          task: approvals[index],
                          onTap: () {
                            context.push('/approvals/${approvals[index].id}');
                          },
                          onApprove: approvals[index].isPending
                              ? () => _quickApprove(
                                  context, ref, approvals[index])
                              : null,
                          onReject: approvals[index].isPending
                              ? () =>
                                  _quickReject(context, ref, approvals[index])
                              : null,
                        );
                      },
                    ),
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: _C.accentPrimary),
                ),
                error: (error, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: _C.textSecondary),
                      const SizedBox(height: 12),
                      Text(
                        'Failed to load approvals',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          color: _C.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => ref.invalidate(approvalListProvider),
                        child: Text(
                          'Retry',
                          style: GoogleFonts.inter(
                            color: _C.accentPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
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
        backgroundColor: _C.surfacePrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Approve Action',
          style: GoogleFonts.inter(
            color: _C.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Approve "${task.actionLabel}" by '
          '${AgentColors.displayName(task.agentSlug)}?',
          style: GoogleFonts.inter(color: _C.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: _C.textSecondary)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: _C.approveGreen,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Approve',
                style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.w600)),
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
        backgroundColor: _C.surfacePrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Reject Action',
          style: GoogleFonts.inter(
            color: _C.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Reject "${task.actionLabel}" by '
          '${AgentColors.displayName(task.agentSlug)}?',
          style: GoogleFonts.inter(color: _C.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: _C.textSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _C.rejectRed,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Reject',
                style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.w600)),
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

// ---------------------------------------------------------------------------
// Filter Chip
// ---------------------------------------------------------------------------

class _FilterChip extends StatelessWidget {
  final String label;
  final String filter;
  final bool isSelected;

  const _FilterChip({
    required this.label,
    required this.filter,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = _chipColors(filter, isSelected);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: fg,
        ),
      ),
    );
  }

  static (Color, Color) _chipColors(String filter, bool selected) {
    if (filter == 'all') {
      return selected
          ? (_C.accentPrimary, Colors.white)
          : (const Color(0xFFF3F4F6), _C.textSecondary);
    }
    if (filter == 'pending') {
      return selected
          ? (_C.pendingBg, _C.pendingFg)
          : (const Color(0xFFF3F4F6), _C.textSecondary);
    }
    if (filter == 'approved') {
      return selected
          ? (_C.approvedBg, _C.approvedFg)
          : (const Color(0xFFF3F4F6), _C.textSecondary);
    }
    if (filter == 'rejected') {
      return selected
          ? (_C.rejectedBg, _C.rejectedFg)
          : (const Color(0xFFF3F4F6), _C.textSecondary);
    }
    return (const Color(0xFFF3F4F6), _C.textSecondary);
  }
}

// ---------------------------------------------------------------------------
// Approval Card
// ---------------------------------------------------------------------------

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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _C.surfacePrimary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.borderLight, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Left color stripe — full height
              Container(width: 4, color: agentColor),

              // Content area
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: agent icon + name | status badge
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
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: agentColor,
                            ),
                          ),
                          const Spacer(),
                          _StatusBadge(status: task.status),
                        ],
                      ),

                      const SizedBox(height: 6),

                      // Action type tag
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _C.tagBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          task.actionLabel,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _C.textSecondary,
                          ),
                        ),
                      ),

                      const SizedBox(height: 6),

                      // Description text
                      Text(
                        task.payloadPreview,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: _C.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 8),

                      // Bottom row: timestamp left, action buttons right
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 13,
                            color: _C.textSecondary.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatTime(task.requestedAt),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: _C.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          if (onApprove != null) ...[
                            _ActionIconButton(
                              icon: Icons.check_circle_outline,
                              color: _C.approveGreen,
                              onPressed: onApprove!,
                              tooltip: 'Approve',
                            ),
                            const SizedBox(width: 4),
                          ],
                          if (onReject != null)
                            _ActionIconButton(
                              icon: Icons.cancel_outlined,
                              color: _C.rejectRed,
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

// ---------------------------------------------------------------------------
// Action Icon Button
// ---------------------------------------------------------------------------

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
      color: color.withValues(alpha: 0.10),
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

// ---------------------------------------------------------------------------
// Status Badge
// ---------------------------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color bgColor, Color fgColor, String label) = switch (status) {
      'pending' => (_C.pendingBg, _C.pendingFg, 'Pending'),
      'approved' => (_C.approvedBg, _C.approvedFg, 'Approved'),
      'rejected' => (_C.rejectedBg, _C.rejectedFg, 'Rejected'),
      _ => (
          _C.tagBg,
          _C.textSecondary,
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
        style: GoogleFonts.inter(
          color: fgColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
