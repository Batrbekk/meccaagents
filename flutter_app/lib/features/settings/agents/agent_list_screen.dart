import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/agent_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/settings_providers.dart';
import '../data/settings_repository.dart';
import '../domain/agent_config.dart';

class AgentListScreen extends ConsumerWidget {
  const AgentListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agentsAsync = ref.watch(agentListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agents'),
      ),
      body: agentsAsync.when(
        data: (agents) {
          if (agents.isEmpty) {
            return const Center(child: Text('No agents configured'));
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: agents.length,
            itemBuilder: (context, index) {
              return _AgentCard(
                agent: agents[index],
                onTap: () {
                  context.push('/settings/agents/${agents[index].slug}');
                },
                onToggle: (value) async {
                  await ref.read(settingsRepositoryProvider).updateAgentConfig(
                        agents[index].slug,
                        isActive: value,
                      );
                  ref.invalidate(agentListProvider);
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text('Failed to load agents: $error'),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(agentListProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgentCard extends StatelessWidget {
  final AgentConfig agent;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  const _AgentCard({
    required this.agent,
    required this.onTap,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final agentColor = AgentColors.forSlug(agent.slug);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Colored dot
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: agentColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              // Agent info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          agent.displayName,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(width: 8),
                        _StatusBadge(isActive: agent.isActive),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      agent.model,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              // Toggle
              Switch(
                value: agent.isActive,
                onChanged: onToggle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;

  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppTheme.success : AppTheme.textSecondary;
    final label = isActive ? 'Active' : 'Inactive';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
