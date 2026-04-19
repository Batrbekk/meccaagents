import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

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
                    'PROFILE',
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
              child: authState.when(
                data: (user) {
                  final name = user?.name ?? 'User';
                  final email = user?.email ?? '';
                  final initials = _getInitials(name);

                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      const SizedBox(height: 8),

                      // Avatar section (centered)
                      Center(
                        child: Column(
                          children: [
                            // Avatar circle
                            Container(
                              width: 88,
                              height: 88,
                              decoration: const BoxDecoration(
                                color: AppTheme.accentPrimary,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                initials,
                                style: GoogleFonts.anton(
                                  fontSize: 32,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Name
                            Text(
                              name,
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.foregroundPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Email
                            Text(
                              email,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: AppTheme.foregroundSecondary,
                              ),
                            ),
                            if (user?.role != null) ...[
                              const SizedBox(height: 10),
                              // Role badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentPrimary,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  user!.role.toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Preferences card
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd),
                          border:
                              Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Section header
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                  16, 14, 16, 6),
                              child: Text(
                                'Preferences',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.foregroundSecondary,
                                ),
                              ),
                            ),
                            // Push Notifications
                            _PreferenceRow(
                              icon: Icons.notifications_outlined,
                              title: 'Push Notifications',
                              value: _pushNotifications,
                              activeColor: AppTheme.accentPrimary,
                              onChanged: (value) {
                                setState(
                                    () => _pushNotifications = value);
                              },
                            ),
                            // Divider
                            Container(
                              height: 1,
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16),
                              color: const Color(0xFFE5E7EB),
                            ),
                            // Biometric Login
                            _PreferenceRow(
                              icon: Icons.crop_free,
                              title: 'Biometric Login',
                              value: _biometricLogin,
                              activeColor: const Color(0xFFD1D5DB),
                              onChanged: (value) {
                                setState(
                                    () => _biometricLogin = value);
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Logout button
                      GestureDetector(
                        onTap: () => _handleLogout(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                            border: Border.all(
                              color: const Color(0xFFDC2626),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.logout,
                                size: 20,
                                color: Color(0xFFDC2626),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Log Out',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFDC2626),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, st) =>
                    const Center(child: Text('Failed to load profile')),
              ),
            ),
          ],
        ),
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
              backgroundColor: const Color(0xFFDC2626),
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

class _PreferenceRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final Color activeColor;
  final ValueChanged<bool> onChanged;

  const _PreferenceRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.activeColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.foregroundSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: AppTheme.foregroundPrimary,
              ),
            ),
          ),
          _CustomToggle(
            value: value,
            activeColor: activeColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _CustomToggle extends StatelessWidget {
  final bool value;
  final Color activeColor;
  final ValueChanged<bool> onChanged;

  const _CustomToggle({
    required this.value,
    required this.activeColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 24,
        decoration: BoxDecoration(
          color: value ? activeColor : const Color(0xFFD1D5DB),
          borderRadius: BorderRadius.circular(12),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment:
              value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.all(2),
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
