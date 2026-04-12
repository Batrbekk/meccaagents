import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _pushNotifications = true;
  bool _biometricLogin = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: authState.when(
        data: (user) {
          final name = user?.name ?? 'User';
          final email = user?.email ?? '';
          final initials = _getInitials(name);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Avatar + info
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor:
                          Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                      child: Text(
                        initials,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                    if (user?.role != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          user!.role.toUpperCase(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 8),

              // Preferences
              _SectionHeader(title: 'Preferences'),
              const SizedBox(height: 8),
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Push Notifications'),
                      subtitle: Text(
                        'Receive alerts for new approvals',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      secondary: const Icon(Icons.notifications_outlined),
                      value: _pushNotifications,
                      onChanged: (value) {
                        setState(() => _pushNotifications = value);
                      },
                    ),
                    const Divider(height: 1, indent: 56),
                    SwitchListTile(
                      title: const Text('Biometric Login'),
                      subtitle: Text(
                        'Use Face ID or fingerprint to sign in',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      secondary: const Icon(Icons.fingerprint),
                      value: _biometricLogin,
                      onChanged: (value) {
                        setState(() => _biometricLogin = value);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Logout
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _handleLogout(context),
                  icon: const Icon(Icons.logout),
                  label: const Text('Log Out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    side: BorderSide(
                      color: Theme.of(context)
                          .colorScheme
                          .error
                          .withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => const Center(child: Text('Failed to load profile')),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await ref.read(authStateProvider.notifier).logout();
    if (context.mounted) {
      context.go('/login');
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}
