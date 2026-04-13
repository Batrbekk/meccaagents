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

  Future<void> saveIntegration(
    String service,
    Map<String, dynamic> credentials,
  ) async {
    await dio.put('/integrations/$service', data: {
      'credentials': credentials,
    });
  }

  Future<bool> testIntegration(String service) async {
    try {
      final response = await dio.post('/integrations/$service/test');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
