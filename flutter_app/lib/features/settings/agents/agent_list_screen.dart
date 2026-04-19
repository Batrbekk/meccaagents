import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

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
      backgroundColor: AppTheme.scaffoldBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.chevron_left,
                      size: 28,
                      color: AppTheme.foregroundPrimary,
                    ),
                  ),
                  Text(
                    'AGENTS',
                    style: GoogleFonts.anton(
                      fontSize: 22,
                      color: AppTheme.foregroundPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Content
            Expanded(
              child: agentsAsync.when(
                data: (agents) {
                  if (agents.isEmpty) {
                    return const Center(child: Text('No agents configured'));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: agents.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _AgentCard(
                        agent: agents[index],
                        onTap: () {
                          context.push('/settings/agents/${agents[index].slug}');
                        },
                        onToggle: (value) async {
                          await ref
                              .read(settingsRepositoryProvider)
                              .updateAgentConfig(
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
            ),
          ],
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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
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
                  Text(
                    agent.displayName,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.foregroundPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    agent.model,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.foregroundSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // Badge
            _StatusBadge(isActive: agent.isActive),
          ],
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
    final bgColor =
        isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7);
    final textColor =
        isActive ? const Color(0xFF16A34A) : const Color(0xFFD97706);
    final label = isActive ? 'Active' : 'Inactive';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}
