import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/api/current_user_provider.dart';
import '../../core/auth/auth_provider.dart';
import 'sunkidz_logo.dart';

class AdminDrawer extends ConsumerWidget {
  const AdminDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentRoute = GoRouterState.of(context).matchedLocation;
    final userAsync = ref.watch(currentUserProvider);
    final displayName =
        userAsync.valueOrNull?['full_name']?.toString() ?? 'Admin';
    final email =
        userAsync.valueOrNull?['email']?.toString() ?? 'admin@sunkidz.com';

    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      width: MediaQuery.of(context).size.width * 0.85,
      child: Stack(
        children: [
          // Glassmorphic Background
          ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(30)),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                  boxShadow: [AppShadows.elevated],
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // Premium Header
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const SunkidzLogo(size: 80),
                      const SizedBox(height: 16),
                      Text(
                        displayName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        email,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                
                const Divider(indent: 24, endIndent: 24),
                
                // Scrollable Nav List
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    children: [
                      _DrawerTile(
                        icon: Icons.dashboard_rounded,
                        label: 'Dashboard',
                        isActive: currentRoute == '/admin',
                        onTap: () => _navigate(context, '/admin'),
                      ),
                      _DrawerTile(
                        icon: Icons.account_balance_rounded,
                        label: 'Branches',
                        isActive: currentRoute == '/branches',
                        onTap: () => _navigate(context, '/branches'),
                      ),
                      _DrawerTile(
                        icon: Icons.person_search_rounded,
                        label: 'Enquiries',
                        isActive: currentRoute == '/enquiries',
                        onTap: () => _navigate(context, '/enquiries'),
                      ),
                      _DrawerTile(
                        icon: Icons.school_rounded,
                        label: 'Admissions',
                        isActive: currentRoute == '/admissions',
                        onTap: () => _navigate(context, '/admissions'),
                      ),
                      _DrawerTile(
                        icon: Icons.face_6_rounded,
                        label: 'Students',
                        isActive: currentRoute == '/students',
                        onTap: () => _navigate(context, '/students'),
                      ),
                      _DrawerTile(
                        icon: Icons.assignment_rounded,
                        label: 'Marks Card',
                        isActive: currentRoute == '/marks',
                        onTap: () => _navigate(context, '/marks'),
                      ),
                      _DrawerTile(
                        icon: Icons.event_available_rounded,
                        label: 'Attendance',
                        isActive: currentRoute == '/admin/attendance',
                        onTap: () => _navigate(context, '/admin/attendance'),
                      ),
                      _DrawerTile(
                        icon: Icons.receipt_long_rounded,
                        label: 'Fee Management',
                        isActive: currentRoute.contains('/fees'),
                        onTap: () => _navigate(context, '/admin/fees'),
                      ),
                      _DrawerTile(
                        icon: Icons.groups_rounded,
                        label: 'Staff',
                        isActive: currentRoute == '/staff',
                        onTap: () => _navigate(context, '/staff'),
                      ),
                      _DrawerTile(
                        icon: Icons.child_care_rounded,
                        label: 'Toddlers',
                        isActive: currentRoute == '/admin/toddlers',
                        onTap: () => _navigate(context, '/admin/toddlers'),
                      ),
                      _DrawerTile(
                        icon: Icons.child_friendly_rounded,
                        label: 'Daycare',
                        isActive: currentRoute == '/admin/daycare',
                        onTap: () => _navigate(context, '/admin/daycare'),
                      ),
                      _DrawerTile(
                        icon: Icons.menu_book_rounded,
                        label: 'Syllabus',
                        isActive: currentRoute == '/syllabus',
                        onTap: () => _navigate(context, '/syllabus'),
                      ),
                      _DrawerTile(
                        icon: Icons.assignment_turned_in_rounded,
                        label: 'Homework',
                        isActive: currentRoute == '/homework',
                        onTap: () => _navigate(context, '/homework'),
                      ),
                      _DrawerTile(
                        icon: Icons.settings_suggest_rounded,
                        label: 'Settings',
                        isActive: currentRoute == '/admin/settings',
                        onTap: () => _navigate(context, '/admin/settings'),
                      ),
                    ],
                  ),
                ),
                
                // Logout at bottom
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _DrawerTile(
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
    // If navigating to a root dashboard, use go to clear stack.
    // Otherwise, push so the physical back button works.
    if (path == '/admin' || 
        path == '/coordinator' || 
        path == '/teacher' || 
        path == '/parent' || 
        path == '/bus-staff' || 
        path == '/toddler' || 
        path == '/daycare') {
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

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final bool isLogout;

  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.isLogout = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: isActive ? AppGradients.primaryGradient : null,
        boxShadow: isActive ? [AppShadows.glow(AppColors.primary)] : null,
      ),
      child: ListTile(
        onTap: onTap,
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(
          icon,
          color: isActive 
            ? Colors.white 
            : (isLogout ? Colors.redAccent.shade400 : const Color(0xFF64748B)),
          size: 22,
        ),
        title: Text(
          label,
          style: GoogleFonts.lexend(
            color: isActive 
              ? Colors.white 
              : (isLogout ? Colors.redAccent.shade400 : const Color(0xFF1E293B)),
            fontWeight: isActive || isLogout ? FontWeight.w700 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
