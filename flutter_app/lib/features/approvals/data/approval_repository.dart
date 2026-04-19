import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_client.dart';
import '../domain/approval_task.dart';

final approvalRepositoryProvider = Provider<ApprovalRepository>((ref) {
  return ApprovalRepository(dio);
});

class ApprovalRepository {
  final Dio _dio;

  ApprovalRepository(this._dio);

  Future<List<ApprovalTask>> getApprovals({String? status}) async {
    final queryParams = <String, dynamic>{};
    if (status != null && status != 'all') {
      queryParams['status'] = status;
    }
    final response =
        await _dio.get('/approvals', queryParameters: queryParams);
    final data = response.data;
    final List<dynamic> items =
        data is List ? data : (data['approvals'] as List? ?? data['data'] as List? ?? []);
    return items
        .map((e) => ApprovalTask.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ApprovalTask> getApproval(String id) async {
    final response = await _dio.get('/approvals/$id');
    final data = response.data;
    final Map<String, dynamic> item =
        data is Map<String, dynamic> ? data : data['data'];
    return ApprovalTask.fromJson(item);
  }

  Future<void> approve(String id) async {
    await _dio.post('/approvals/$id/approve');
  }

  Future<void> reject(String id, {String? notes}) async {
    await _dio.post(
      '/approvals/$id/reject',
      data: {if (notes != null) 'notes': notes},  // ignore: use_null_aware_elements
    );
  }

  Future<void> modify(
    String id,
    Map<String, dynamic> payload, {
    String? notes,
  }) async {
    await _dio.post(
      '/approvals/$id/modify',
      data: {
        'payload': payload,
        if (notes != null) 'notes': notes,  // ignore: use_null_aware_elements
      },
    );
  }
}
