import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:agentteam/features/auth/presentation/auth_provider.dart';
import 'package:agentteam/features/auth/presentation/login_screen.dart';
import 'package:agentteam/features/chat/presentation/chat_screen.dart';
import 'package:agentteam/features/chat/presentation/thread_list_screen.dart';
import 'package:agentteam/features/approvals/presentation/approval_list_screen.dart';
import 'package:agentteam/features/approvals/presentation/approval_detail_screen.dart';
import 'package:agentteam/features/settings/settings_screen.dart';
import 'package:agentteam/features/settings/agents/agent_list_screen.dart';
import 'package:agentteam/features/settings/agents/agent_edit_screen.dart';
import 'package:agentteam/features/settings/integrations/integrations_screen.dart';
import 'package:agentteam/features/settings/profile/profile_screen.dart';
import 'package:agentteam/features/shell/desktop_shell.dart';

// Navigator keys for shell branches
final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _threadsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'threads');
final _approvalsNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'approvals');
final _settingsNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'settings');

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggedIn = authState.value != null;
      final isOnLogin = state.matchedLocation == '/login';

      if (!isLoggedIn && !isOnLogin) return '/login';
      if (isLoggedIn && isOnLogin) return '/threads';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),

      // Shell with bottom nav (mobile) / side rail (desktop)
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return DesktopShell(navigationShell: navigationShell);
        },
        branches: [
          // --- Threads branch ---
          StatefulShellBranch(
            navigatorKey: _threadsNavigatorKey,
            routes: [
              GoRoute(
                path: '/threads',
                builder: (context, state) => const ThreadListScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) {
                      final id = state.pathParameters['id']!;
                      final title = state.uri.queryParameters['title'];
                      return ChatScreen(threadId: id, threadTitle: title);
                    },
                  ),
                ],
              ),
            ],
          ),

          // --- Approvals branch ---
          StatefulShellBranch(
            navigatorKey: _approvalsNavigatorKey,
            routes: [
              GoRoute(
                path: '/approvals',
                builder: (context, state) => const ApprovalListScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) {
                      final id = state.pathParameters['id']!;
                      return ApprovalDetailScreen(approvalId: id);
                    },
                  ),
                ],
              ),
            ],
          ),

          // --- Settings branch ---
          StatefulShellBranch(
            navigatorKey: _settingsNavigatorKey,
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'agents',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const AgentListScreen(),
                    routes: [
                      GoRoute(
                        path: ':slug',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (context, state) {
                          final slug = state.pathParameters['slug']!;
                          return AgentEditScreen(slug: slug);
                        },
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'integrations',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const IntegrationsScreen(),
                  ),
                  GoRoute(
                    path: 'profile',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const ProfileScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Center(
        child: Text(
          'Page not found',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        ),
      ),
    ),
  );
});
