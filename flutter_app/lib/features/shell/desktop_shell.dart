import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

/// Navigation shell with a pill-shaped bottom tab bar.
///
/// Used as the shell builder in [StatefulShellRoute.indexedStack].
class DesktopShell extends StatelessWidget {
  const DesktopShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: _PillTabBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab definition
// ---------------------------------------------------------------------------

class _TabDef {
  const _TabDef({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

const _tabs = [
  _TabDef(icon: Icons.chat_bubble_outline, label: 'CHAT'),
  _TabDef(icon: Icons.check_circle_outline, label: 'APPROVALS'),
  _TabDef(icon: Icons.settings_outlined, label: 'SETTINGS'),
];

// ---------------------------------------------------------------------------
// Pill-shaped bottom tab bar
// ---------------------------------------------------------------------------

class _PillTabBar extends StatelessWidget {
  const _PillTabBar({
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    // Outer container: padding top=12, right=21, bottom=21, left=21
    return Container(
      color: AppTheme.scaffoldBg,
      padding: const EdgeInsets.fromLTRB(21, 12, 21, 21),
      child: Container(
        height: 62,
        decoration: BoxDecoration(
          color: AppTheme.surfacePrimary,
          borderRadius: BorderRadius.circular(36),
          border: Border.all(
            color: const Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: List.generate(_tabs.length, (index) {
            final isActive = index == currentIndex;
            return Expanded(
              child: _PillTab(
                tab: _tabs[index],
                isActive: isActive,
                onTap: () => onTap(index),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual pill tab
// ---------------------------------------------------------------------------

class _PillTab extends StatelessWidget {
  const _PillTab({
    required this.tab,
    required this.isActive,
    required this.onTap,
  });

  final _TabDef tab;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor =
        isActive ? AppTheme.foregroundInverse : AppTheme.foregroundSecondary;
    final textColor =
        isActive ? AppTheme.foregroundInverse : AppTheme.foregroundSecondary;
    final bgColor =
        isActive ? AppTheme.accentPrimary : Colors.transparent;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              tab.icon,
              size: 18,
              color: iconColor,
            ),
            const SizedBox(height: 4),
            Text(
              tab.label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
