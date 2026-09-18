import 'package:flutter/material.dart';
import 'app_drawer_shell.dart';

class CoordinatorDrawer extends StatelessWidget {
  const CoordinatorDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppDrawerShell(
      avatarIcon: Icons.business,
      roleLabel: 'Branch Coordinator',
      fallbackName: 'Coordinator',
      items: [
        AppDrawerItem(
          icon: Icons.dashboard_rounded,
          label: 'Home',
          route: '/coordinator',
        ),
        AppDrawerItem(
          icon: Icons.badge_rounded,
          label: 'Teachers',
          route: '/coordinator/teachers',
        ),
        AppDrawerItem(
          icon: Icons.face_6_rounded,
          label: 'Students',
          route: '/coordinator/students',
        ),
        AppDrawerItem(
          icon: Icons.document_scanner_rounded,
          label: 'Admission Documents',
          route: '/coordinator/documents',
        ),
        AppDrawerItem(
          icon: Icons.event_available_rounded,
          label: 'Attendance',
          route: '/coordinator/attendance',
        ),
        AppDrawerItem(
          icon: Icons.people_alt_rounded,
          label: 'Staff Attendance',
          route: '/coordinator/staff-attendance',
        ),
        AppDrawerItem(
          icon: Icons.menu_book_rounded,
          label: 'Syllabus',
          route: '/coordinator/syllabus',
        ),
        AppDrawerItem(
          icon: Icons.play_lesson_rounded,
          label: 'Learning Modules',
          route: '/learning-modules',
        ),
        AppDrawerItem(
          icon: Icons.assignment_turned_in_rounded,
          label: 'Homework',
          route: '/coordinator/homework',
        ),
        AppDrawerItem(
          icon: Icons.collections_bookmark_rounded,
          label: 'Class Photos',
          route: '/coordinator/gallery',
        ),
        AppDrawerItem(
          icon: Icons.chat_rounded,
          label: 'Chats',
          route: '/chat',
          isActive: _isChatRoute,
        ),
        AppDrawerItem(
          icon: Icons.photo_library_rounded,
          label: 'Gallery',
          route: '/gallery',
        ),
        AppDrawerItem(
          icon: Icons.event_available_rounded,
          label: 'Leave Requests',
          route: '/coordinator/leave',
        ),
        AppDrawerItem(
          icon: Icons.settings_suggest_rounded,
          label: 'Profile & Settings',
          route: '/coordinator/settings',
        ),
      ],
    );
  }
}

bool _isChatRoute(String loc) => loc == '/chat' || loc.startsWith('/chat/');
