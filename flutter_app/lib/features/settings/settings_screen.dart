import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../auth/presentation/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            // Title
            Text(
              'SETTINGS',
              style: GoogleFonts.anton(
                fontSize: 28,
                color: AppTheme.foregroundPrimary,
              ),
            ),
            const SizedBox(height: 24),

            // CONFIGURATION section
            _SectionLabel(title: 'CONFIGURATION'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Column(
                children: [
                  _SettingsRow(
                    icon: Icons.smart_toy_outlined,
                    title: 'Agents',
                    onTap: () => context.push('/settings/agents'),
                  ),
                  Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    color: const Color(0xFFF3F4F6),
                  ),
                  _SettingsRow(
                    icon: Icons.link,
                    title: 'Integrations',
                    onTap: () => context.push('/settings/integrations'),
                    showBottomBorder: false,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ACCOUNT section
            _SectionLabel(title: 'ACCOUNT'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: _SettingsRow(
                icon: Icons.person_outline,
                title: 'Profile',
                onTap: () => context.push('/settings/profile'),
                showBottomBorder: false,
              ),
            ),

            const SizedBox(height: 24),

            // User card
            authState.when(
              data: (user) {
                final name = user?.name ?? 'User';
                final role = user?.role ?? 'member';
                final initials = _getInitials(name);

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.accentPrimary,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: Color(0x55FFFFFF),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initials,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Name + Role
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_capitalize(role)} \u2022 Mecca-Cola',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xCCFFFFFF),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 32),

            // Version footer
            Center(
              child: Column(
                children: [
                  Text(
                    'Mecca-Cola Agent v1.0.0',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.foregroundSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\u00A9 2026 Mecca-Cola',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppTheme.foregroundSecondary,
                    ),
                  ),
                ],
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

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  const _SectionLabel({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.foregroundSecondary,
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool showBottomBorder;

  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.showBottomBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: showBottomBorder
          ? null
          : BorderRadius.circular(AppTheme.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: AppTheme.accentPrimary,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: AppTheme.foregroundPrimary,
                ),
              ),
            ),
            Text(
              '\u203A',
              style: TextStyle(
                fontSize: 20,
                color: AppTheme.foregroundSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
