import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/auth/auth_provider.dart';

class TeacherDrawer extends ConsumerWidget {
  const TeacherDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: const Color(0xFF42F07C).withValues(alpha: 0.2)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.school, size: 40, color: const Color(0xFF42F07C)),
                const SizedBox(height: 8),
                Text('Teacher Portal', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          _DrawerTile(icon: Icons.dashboard, label: 'Home', onTap: () => _navigate(context, '/teacher')),
          _DrawerTile(icon: Icons.face, label: 'Students', onTap: () => _navigate(context, '/teacher/students')),
          _DrawerTile(icon: Icons.event_available, label: 'Attendance', onTap: () => _navigate(context, '/teacher/attendance')),
          _DrawerTile(icon: Icons.assignment, label: 'Homework', onTap: () => _navigate(context, '/teacher/homework')),
          _DrawerTile(icon: Icons.grade, label: 'Marks Card', onTap: () => _navigate(context, '/teacher/marks')),
          const Divider(),
          _DrawerTile(icon: Icons.logout, label: 'Logout', onTap: () => _logout(context, ref)),
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

  const _DrawerTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: onTap,
    );
  }
}
