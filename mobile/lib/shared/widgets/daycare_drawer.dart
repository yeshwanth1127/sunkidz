import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/api/current_user_provider.dart';

class DaycareDrawer extends ConsumerWidget {
  const DaycareDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final userName = userAsync.valueOrNull?['full_name']?.toString() ?? 'Daycare';

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: const Color(0xFF85CDCA).withValues(alpha: 0.3),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.child_friendly, size: 40, color: Colors.teal.shade700),
                const SizedBox(height: 8),
                Text(
                  userName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Daycare Portal',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () {
              Navigator.pop(context);
              context.go('/daycare');
            },
          ),
          ListTile(
            leading: const Icon(Icons.menu_book),
            title: const Text('Syllabus'),
            onTap: () {
              Navigator.pop(context);
              context.go('/daycare/syllabus');
            },
          ),
          ListTile(
            leading: const Icon(Icons.assignment),
            title: const Text('Homework'),
            onTap: () {
              Navigator.pop(context);
              context.go('/daycare/homework');
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Gallery'),
            onTap: () {
              Navigator.pop(context);
              context.go('/daycare/gallery');
            },
          ),
          ListTile(
            leading: const Icon(Icons.notes),
            title: const Text('Daily Updates'),
            onTap: () {
              Navigator.pop(context);
              context.go('/daycare/daily-updates');
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              context.go('/daycare/settings');
            },
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.red.shade700),
            title: Text(
              'Logout',
              style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600),
            ),
            onTap: () {
              Navigator.pop(context);
              ref.read(authProvider.notifier).logout();
              context.go('/login');
            },
          ),
        ],
      ),
    );
  }
}
