import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/agent_colors.dart';
import '../data/approval_providers.dart';
import '../data/approval_repository.dart';
import '../domain/approval_task.dart';

// ---------------------------------------------------------------------------
// Light-theme palette (local to this screen)
// ---------------------------------------------------------------------------
class _C {
  _C._();
  static const surfacePrimary = Color(0xFFFFFFFF);
  static const bgLight = Color(0xFFF9FAFB);
  static const borderLight = Color(0xFFF3F4F6);
  static const borderMedium = Color(0xFFE5E7EB);
  static const borderInput = Color(0xFFD1D5DB);
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const iconMuted = Color(0xFF9CA3AF);

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
  static const modifyAmber = Color(0xFFF59E0B);
}

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
      backgroundColor: _C.bgLight,
      body: SafeArea(
        child: detailAsync.when(
          data: (task) => _buildContent(context, task),
          loading: () => const Center(
            child: CircularProgressIndicator(color: _C.accentPrimary),
          ),
          error: (error, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: _C.textSecondary),
                const SizedBox(height: 12),
                Text(
                  'Failed to load approval: $error',
                  style: GoogleFonts.inter(
                      color: _C.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ref.invalidate(
                    approvalDetailProvider(widget.approvalId),
                  ),
                  child: Text('Retry',
                      style: GoogleFonts.inter(
                          color: _C.accentPrimary, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ApprovalTask task) {
    final agentColor = AgentColors.forSlug(task.agentSlug);

    return Column(
      children: [
        // Header: back arrow + title
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back, color: _C.textPrimary),
                splashRadius: 20,
              ),
              const SizedBox(width: 4),
              Text(
                'Approval Detail',
                style: GoogleFonts.anton(
                  fontSize: 22,
                  color: _C.textPrimary,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Agent banner
              _buildAgentBanner(context, task, agentColor),
              const SizedBox(height: 16),

              // Details card
              _buildDetailsCard(context, task),
              const SizedBox(height: 16),

              // Content section
              _buildContentSection(context, task),
              const SizedBox(height: 16),

              // Image preview
              _buildImagePreview(context, task),

              // Timeline section
              _buildTimelineSection(context, task),
              const SizedBox(height: 16),
            ],
          ),
        ),

        // Bottom action bar (only for pending)
        if (task.isPending) _buildActionBar(context, task),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Agent Banner
  // -----------------------------------------------------------------------
  Widget _buildAgentBanner(
    BuildContext context,
    ApprovalTask task,
    Color agentColor,
  ) {
    final initial = AgentColors.displayName(task.agentSlug)
        .substring(0, 1)
        .toUpperCase();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.accentPrimary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Avatar: 40x40 circle
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AgentColors.displayName(task.agentSlug),
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Details Card
  // -----------------------------------------------------------------------
  Widget _buildDetailsCard(BuildContext context, ApprovalTask task) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surfacePrimary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.borderLight),
      ),
      child: Column(
        children: [
          _DetailRow(
            label: 'Status',
            child: _StatusBadge(status: task.status),
          ),
          const SizedBox(height: 12),
          _DetailRow(
            label: 'Action Type',
            child: Text(
              task.actionLabel,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _C.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _DetailRow(
            label: 'Agent',
            child: Text(
              AgentColors.displayName(task.agentSlug),
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _C.textPrimary,
              ),
            ),
          ),
          if (task.notes != null) ...[
            const SizedBox(height: 12),
            _DetailRow(
              label: 'Notes',
              child: Text(
                task.notes!,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _C.textPrimary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Content Section
  // -----------------------------------------------------------------------
  Widget _buildContentSection(BuildContext context, ApprovalTask task) {
    final hasText = task.payload.containsKey('text') ||
        task.payload.containsKey('content') ||
        task.payload.containsKey('caption');
    final extraEntries = task.payload.entries.where((e) =>
        e.key != 'text' &&
        e.key != 'content' &&
        e.key != 'caption' &&
        e.key != 'imageUrl' &&
        e.key != 'image_url');

    if (!hasText && extraEntries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Content',
          style: GoogleFonts.anton(
            fontSize: 16,
            color: _C.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _C.bgLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasText) ...[
                SelectableText(
                  (task.payload['text'] ??
                          task.payload['content'] ??
                          task.payload['caption'] ??
                          '')
                      .toString(),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: _C.textSecondary,
                    height: 1.5,
                  ),
                ),
                if (extraEntries.isNotEmpty) const SizedBox(height: 8),
              ],
              ...extraEntries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _DetailRow(
                    label: entry.key,
                    child: Flexible(
                      child: Text(
                        entry.value.toString(),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _C.textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Image Preview
  // -----------------------------------------------------------------------
  Widget _buildImagePreview(BuildContext context, ApprovalTask task) {
    final hasImage = task.payload.containsKey('imageUrl') ||
        task.payload.containsKey('image_url');

    if (!hasImage) {
      // Placeholder image preview
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(
          width: double.infinity,
          height: 120,
          decoration: BoxDecoration(
            color: _C.borderMedium,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_outlined, size: 28, color: _C.iconMuted),
              const SizedBox(height: 4),
              Text(
                'Image Preview',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: _C.iconMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final raw = task.payload['imageUrl'] ?? task.payload['image_url'];
    final url = _extractImageUrl(raw);
    if (url == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(
          width: double.infinity,
          height: 120,
          decoration: BoxDecoration(
            color: _C.borderMedium,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              'No image data',
              style: GoogleFonts.inter(fontSize: 13, color: _C.iconMuted),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _buildImage(url),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Timeline Section
  // -----------------------------------------------------------------------
  Widget _buildTimelineSection(BuildContext context, ApprovalTask task) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Timeline',
          style: GoogleFonts.anton(
            fontSize: 16,
            color: _C.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _C.surfacePrimary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _C.borderLight),
          ),
          child: Column(
            children: [
              _TimelineRow(
                label: 'Requested',
                value: _formatDateTime(task.requestedAt),
                icon: Icons.schedule,
                color: _C.modifyAmber,
              ),
              if (task.resolvedAt != null) ...[
                const SizedBox(height: 10),
                _TimelineRow(
                  label: task.isApproved ? 'Approved' : 'Rejected',
                  value: _formatDateTime(task.resolvedAt!),
                  icon:
                      task.isApproved ? Icons.check_circle : Icons.cancel,
                  color: task.isApproved ? _C.approvedFg : _C.rejectedFg,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Bottom Action Bar
  // -----------------------------------------------------------------------
  Widget _buildActionBar(BuildContext context, ApprovalTask task) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: _C.surfacePrimary,
        border: const Border(top: BorderSide(color: _C.borderLight)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Notes input
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: _C.surfacePrimary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _C.borderInput, width: 1),
              ),
              child: TextField(
                controller: _notesController,
                style: GoogleFonts.inter(
                    fontSize: 14, color: _C.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Add a note...',
                  hintStyle: GoogleFonts.inter(
                      fontSize: 14, color: _C.iconMuted),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Three buttons row
            Row(
              children: [
                // Reject
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed:
                          _isProcessing ? null : () => _handleReject(task),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _C.rejectRed,
                        side: const BorderSide(
                            color: _C.rejectRed, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Reject',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _C.rejectRed,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Modify
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed:
                          _isProcessing ? null : () => _handleModify(task),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _C.modifyAmber,
                        side: const BorderSide(
                            color: _C.modifyAmber, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Modify',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _C.modifyAmber,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Approve
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: FilledButton(
                      onPressed:
                          _isProcessing ? null : () => _handleApprove(task),
                      style: FilledButton.styleFrom(
                        backgroundColor: _C.approveGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Approve',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Handlers (unchanged logic)
  // -----------------------------------------------------------------------

  Future<void> _handleApprove(ApprovalTask task) async {
    final confirmed = await _showConfirmDialog(
      title: 'Approve Action',
      message:
          'Are you sure you want to approve "${task.actionLabel}"? This action will be executed.',
      confirmLabel: 'Approve',
      confirmColor: _C.approveGreen,
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
      confirmColor: _C.rejectRed,
    );
    if (confirmed != true) return;

    await _executeAction(() async {
      final notes = _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim();
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
        backgroundColor: _C.surfacePrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: GoogleFonts.inter(
            color: _C.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          message,
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
              backgroundColor: confirmColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel,
                style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.w600)),
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

  /// Extract URL string from various formats:
  /// - plain string: "data:image/png;base64,..."
  /// - nested object: {type: "image_url", image_url: {url: "data:..."}}
  /// - simple object: {url: "data:..."}
  String? _extractImageUrl(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) return raw;
    if (raw is Map) {
      // {image_url: {url: "..."}}
      if (raw['image_url'] is Map) {
        return raw['image_url']['url']?.toString();
      }
      // {url: "..."}
      if (raw['url'] is String) return raw['url'];
    }
    return null;
  }

  Widget _buildImage(String url) {
    // Handle base64 data URLs
    if (url.startsWith('data:')) {
      try {
        final base64Part = url.split(',').last;
        final bytes = base64Decode(base64Part);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (_, e, st) => Container(
            height: 200,
            color: _C.borderMedium,
            child: const Center(
                child: Icon(Icons.broken_image_outlined,
                    size: 40, color: _C.iconMuted)),
          ),
        );
      } catch (_) {
        return Container(
          height: 200,
          color: _C.borderMedium,
          child: const Center(
              child: Icon(Icons.broken_image_outlined,
                  size: 40, color: _C.iconMuted)),
        );
      }
    }
    // Regular HTTP URL
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, e, st) => Container(
        height: 200,
        color: _C.borderMedium,
        child: const Center(
            child: Icon(Icons.broken_image_outlined,
                size: 40, color: _C.iconMuted)),
      ),
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

// ---------------------------------------------------------------------------
// Detail Row (label on left, value on right, space-between)
// ---------------------------------------------------------------------------

class _DetailRow extends StatelessWidget {
  final String label;
  final Widget child;

  const _DetailRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: _C.textSecondary,
          ),
        ),
        const SizedBox(width: 16),
        child,
      ],
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
          const Color(0xFFF3F4F6),
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

// ---------------------------------------------------------------------------
// Timeline Row
// ---------------------------------------------------------------------------

class _TimelineRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _TimelineRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: _C.textPrimary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: _C.textSecondary,
          ),
        ),
      ],
    );
  }
}
