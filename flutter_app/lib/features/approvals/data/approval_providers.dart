import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/approval_task.dart';
import 'approval_repository.dart';

/// Currently selected filter for the approval list.
final approvalFilterProvider =
    NotifierProvider<ApprovalFilterNotifier, String>(ApprovalFilterNotifier.new);

class ApprovalFilterNotifier extends Notifier<String> {
  @override
  String build() => 'pending';

  void setFilter(String filter) {
    state = filter;
  }
}

/// Fetches approvals based on the current filter.
final approvalListProvider =
    FutureProvider.autoDispose<List<ApprovalTask>>((ref) async {
  final filter = ref.watch(approvalFilterProvider);
  final repo = ref.read(approvalRepositoryProvider);
  return repo.getApprovals(status: filter);
});

/// Fetches a single approval by ID.
final approvalDetailProvider =
    FutureProvider.autoDispose.family<ApprovalTask, String>((ref, id) async {
  final repo = ref.read(approvalRepositoryProvider);
  return repo.getApproval(id);
});
