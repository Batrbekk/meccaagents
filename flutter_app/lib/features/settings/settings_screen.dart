import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),

          // Agents section
          _SectionHeader(title: 'Configuration'),
          _SettingsTile(
            icon: Icons.smart_toy_outlined,
            title: 'Agents',
            subtitle: 'Manage AI agents, models, and prompts',
            onTap: () => context.push('/settings/agents'),
          ),
          _SettingsTile(
            icon: Icons.extension_outlined,
            title: 'Integrations',
            subtitle: 'Connect external services',
            onTap: () => context.push('/settings/integrations'),
          ),

          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),

          // Account section
          _SectionHeader(title: 'Account'),
          _SettingsTile(
            icon: Icons.person_outline,
            title: 'Profile',
            subtitle: 'View profile and preferences',
            onTap: () => context.push('/settings/profile'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
        ),
        child: Icon(icon, size: 20),
      ),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: AppTheme.textSecondary,
      ),
      onTap: onTap,
    );
  }
}
