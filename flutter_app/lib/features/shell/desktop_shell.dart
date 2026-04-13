import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';

/// Desktop shell that replaces the bottom navigation bar with a side
/// NavigationRail when the screen is wide enough (>= 800px).
///
/// Used as the shell builder in [StatefulShellRoute.indexedStack].
class DesktopShell extends StatelessWidget {
  const DesktopShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const double _breakpoint = 800;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= _breakpoint;

    if (isDesktop) {
      return _DesktopLayout(navigationShell: navigationShell);
    }
    return _MobileLayout(navigationShell: navigationShell);
  }
}

// ---------------------------------------------------------------------------
// Mobile — bottom navigation bar
// ---------------------------------------------------------------------------

class _MobileLayout extends StatelessWidget {
  const _MobileLayout({required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.approval_outlined),
            selectedIcon: Icon(Icons.approval),
            label: 'Approvals',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Desktop — side navigation rail
// ---------------------------------------------------------------------------

class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout({required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final isExtended = MediaQuery.sizeOf(context).width >= 1100;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (index) {
              navigationShell.goBranch(
                index,
                initialLocation: index == navigationShell.currentIndex,
              );
            },
            extended: isExtended,
            minWidth: 72,
            minExtendedWidth: 200,
            backgroundColor: AppTheme.surface,
            leading: Padding(
              padding: EdgeInsets.symmetric(
                vertical: 16,
                horizontal: isExtended ? 16 : 8,
              ),
              child: isExtended
                  ? Row(
                      children: [
                        Icon(
                          Icons.hub,
                          color: Theme.of(context).colorScheme.primary,
                          size: 28,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'AgentTeam',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    )
                  : Icon(
                      Icons.hub,
                      color: Theme.of(context).colorScheme.primary,
                      size: 28,
                    ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.chat_bubble_outline),
                selectedIcon: Icon(Icons.chat_bubble),
                label: Text('Threads'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.approval_outlined),
                selectedIcon: Icon(Icons.approval),
                label: Text('Approvals'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('Settings'),
              ),
            ],
          ),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: AppTheme.border,
          ),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}
