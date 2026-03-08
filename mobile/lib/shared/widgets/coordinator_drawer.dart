import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/auth/auth_provider.dart';

class CoordinatorDrawer extends ConsumerWidget {
  const CoordinatorDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.business, size: 40, color: AppColors.primaryLight),
                const SizedBox(height: 8),
                Text(
                  'Branch Coordinator',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          _DrawerTile(
            icon: Icons.dashboard,
            label: 'Home',
            onTap: () => _navigate(context, '/coordinator'),
          ),
          _DrawerTile(
            icon: Icons.badge,
            label: 'Teachers',
            onTap: () => _navigate(context, '/coordinator/teachers'),
          ),
          _DrawerTile(
            icon: Icons.face,
            label: 'Students',
            onTap: () => _navigate(context, '/coordinator/students'),
          ),
          _DrawerTile(
            icon: Icons.event_available,
            label: 'Attendance',
            onTap: () => _navigate(context, '/coordinator/attendance'),
          ),
          _DrawerTile(
            icon: Icons.people_alt,
            label: 'Staff Attendance',
            onTap: () => _navigate(context, '/coordinator/staff-attendance'),
          ),
          _DrawerTile(
            icon: Icons.menu_book,
            label: 'Syllabus',
            onTap: () => _navigate(context, '/coordinator/syllabus'),
          ),
          _DrawerTile(
            icon: Icons.school,
            label: 'Homework',
            onTap: () => _navigate(context, '/coordinator/homework'),
          ),
          _DrawerTile(
            icon: Icons.photo_library_outlined,
            label: 'Gallery',
            onTap: () => _navigate(context, '/coordinator/gallery'),
          ),
          _DrawerTile(
            icon: Icons.settings,
            label: 'Settings',
            onTap: () => _navigate(context, '/coordinator/settings'),
          ),
          const Divider(),
          _DrawerTile(
            icon: Icons.logout,
            label: 'Logout',
            onTap: () => _logout(context, ref),
          ),
        ],
      ),
    );
  }

  void _navigate(BuildContext context, String path) {
    Navigator.pop(context);
    context.go(path);
  }

  void _logout(BuildContext context, WidgetRef ref) {
    Navigator.pop(context);
    ref.read(authProvider.notifier).logout();
    context.go('/login');
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(leading: Icon(icon), title: Text(label), onTap: onTap);
  }
}
