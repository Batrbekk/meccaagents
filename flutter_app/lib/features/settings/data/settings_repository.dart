import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_client.dart';
import '../domain/agent_config.dart';
import '../domain/integration_info.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

class SettingsRepository {
  // ---- Agents ----

  Future<List<AgentConfig>> getAgents() async {
    final response = await dio.get('/agents');
    final data = response.data;
    final List<dynamic> items =
        data is List ? data : (data['agents'] as List? ?? data['data'] as List? ?? []);
    return items
        .map((e) => AgentConfig.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AgentConfig> getAgentConfig(String slug) async {
    final response = await dio.get('/agents/$slug/config');
    final data = response.data;
    final Map<String, dynamic> item =
        data is Map<String, dynamic> ? data : data['data'];
    return AgentConfig.fromJson(item);
  }

  Future<void> updateAgentConfig(
    String slug, {
    String? systemPrompt,
    String? model,
    double? temperature,
    List<String>? tools,
    bool? isActive,
  }) async {
    await dio.put('/agents/$slug/config', data: {
      if (systemPrompt != null) 'systemPrompt': systemPrompt,  // ignore: use_null_aware_elements
      if (model != null) 'model': model,  // ignore: use_null_aware_elements
      if (temperature != null) 'temperature': temperature,  // ignore: use_null_aware_elements
      if (tools != null) 'tools': tools,  // ignore: use_null_aware_elements
      if (isActive != null) 'isActive': isActive,  // ignore: use_null_aware_elements
    });
  }

  // ---- Integrations ----

  Future<List<IntegrationInfo>> getIntegrations() async {
    final response = await dio.get('/integrations');
    final data = response.data;
    final List<dynamic> items =
        data is List ? data : (data['data'] as List? ?? []);
    return items
        .map((e) => IntegrationInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Save/update a single-account integration (backward compat)
  Future<void> saveIntegration(
    String service,
    Map<String, dynamic> credentials,
  ) async {
    await dio.put('/integrations/$service', data: {
      'credentials': credentials,
    });
  }

  /// Add a new account for a multi-account service (e.g. WhatsApp)
  Future<void> addAccount(
    String service, {
    required String label,
    required Map<String, dynamic> credentials,
  }) async {
    await dio.post('/integrations/$service', data: {
      'label': label,
      'credentials': credentials,
    });
  }

  /// Update an existing account by ID
  Future<void> updateAccount(
    String accountId, {
    String? label,
    Map<String, dynamic>? credentials,
  }) async {
    await dio.put('/integrations/accounts/$accountId', data: {
      if (label != null) 'label': label,  // ignore: use_null_aware_elements
      if (credentials != null) 'credentials': credentials,  // ignore: use_null_aware_elements
    });
  }

  /// Delete an account by ID
  Future<void> deleteAccount(String accountId) async {
    await dio.delete('/integrations/accounts/$accountId');
  }

  /// Test a single-account integration by service name
  Future<bool> testIntegration(String service) async {
    try {
      final response = await dio.post('/integrations/$service/test');
      final data = response.data;
      return data is Map ? (data['success'] as bool? ?? response.statusCode == 200) : response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Test a specific account by ID
  Future<bool> testAccount(String accountId) async {
    try {
      final response = await dio.post('/integrations/accounts/$accountId/test');
      final data = response.data;
      return data is Map ? (data['success'] as bool? ?? response.statusCode == 200) : response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
