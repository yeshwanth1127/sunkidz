import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/api/current_user_provider.dart';
import '../../core/auth/auth_provider.dart';
import 'app_drawer_tile.dart';

/// One navigation entry in a role's drawer.
class AppDrawerItem {
  final IconData icon;
  final String label;
  final String route;

  /// Optional custom "is this the active route" check. Defaults to an exact
  /// match against [route]; pass this to also highlight for sub-routes
  /// (e.g. `(loc) => loc.contains('/fees')`).
  final bool Function(String currentRoute)? isActive;

  const AppDrawerItem({
    required this.icon,
    required this.label,
    required this.route,
    this.isActive,
  });
}

/// Shared drawer shell used by every role (Admin, Teacher, Parent,
/// Coordinator) so the app has one consistent drawer design: glass
/// background, profile header with the signed-in user's real name, active
/// route highlighting, and a logout tile at the bottom. Each role supplies
/// its own [roleLabel] and role-appropriate [items] -- navigation content
/// stays role-specific, only the visual shell is shared.
class AppDrawerShell extends ConsumerWidget {
  const AppDrawerShell({
    super.key,
    required this.avatarIcon,
    required this.roleLabel,
    required this.items,
    this.fallbackName,
  });

  final IconData avatarIcon;
  final String roleLabel;
  final List<AppDrawerItem> items;

  /// Shown as the header name if the signed-in user's profile hasn't loaded
  /// yet (e.g. 'Admin', 'Teacher').
  final String? fallbackName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentRoute = GoRouterState.of(context).matchedLocation;
    final userAsync = ref.watch(currentUserProvider);
    final displayName =
        userAsync.valueOrNull?['full_name']?.toString() ??
        fallbackName ??
        roleLabel;

    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      width: MediaQuery.of(context).size.width * 0.85,
      child: Stack(
        children: [
          ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(30),
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  boxShadow: [AppShadows.elevated],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.1,
                        ),
                        child: Icon(
                          avatarIcon,
                          size: 40,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        displayName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        roleLabel,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Divider(indent: 24, endIndent: 24),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    children: [
                      for (final item in items)
                        AppDrawerTile(
                          icon: item.icon,
                          label: item.label,
                          isActive:
                              item.isActive?.call(currentRoute) ??
                              currentRoute == item.route,
                          onTap: () => _navigate(context, item.route),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: AppDrawerTile(
                    icon: Icons.logout_rounded,
                    label: 'Logout',
                    onTap: () => _logout(context, ref),
                    isLogout: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigate(BuildContext context, String path) {
    Navigator.pop(context);
    // Dashboard roots clear the navigation stack; everything else pushes so
    // the physical/back button works as expected.
    const dashboardRoots = {
      '/admin',
      '/coordinator',
      '/teacher',
      '/parent',
      '/bus-staff',
      '/toddler',
      '/daycare',
    };
    if (dashboardRoots.contains(path)) {
      context.go(path);
    } else {
      context.push(path);
    }
  }

  void _logout(BuildContext context, WidgetRef ref) {
    Navigator.pop(context);
    ref.read(authProvider.notifier).logout();
    while (GoRouter.of(context).canPop()) {
      context.pop();
    }
    context.go('/login');
  }
}
