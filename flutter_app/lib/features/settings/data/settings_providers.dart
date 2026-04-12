import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/agent_config.dart';
import '../domain/integration_info.dart';
import 'settings_repository.dart';

/// Fetches the list of all agents.
final agentListProvider =
    FutureProvider.autoDispose<List<AgentConfig>>((ref) async {
  final repo = ref.read(settingsRepositoryProvider);
  return repo.getAgents();
});

/// Fetches a single agent config by slug.
final agentConfigProvider =
    FutureProvider.autoDispose.family<AgentConfig, String>((ref, slug) async {
  final repo = ref.read(settingsRepositoryProvider);
  return repo.getAgentConfig(slug);
});

/// Fetches all integrations.
final integrationListProvider =
    FutureProvider.autoDispose<List<IntegrationInfo>>((ref) async {
  final repo = ref.read(settingsRepositoryProvider);
  return repo.getIntegrations();
});
