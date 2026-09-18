import 'package:flutter/material.dart';
import 'app_drawer_shell.dart';

class TeacherDrawer extends StatelessWidget {
  const TeacherDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppDrawerShell(
      avatarIcon: Icons.school,
      roleLabel: 'Teacher',
      fallbackName: 'Teacher',
      items: [
        AppDrawerItem(
          icon: Icons.dashboard_rounded,
          label: 'Home',
          route: '/teacher',
        ),
        AppDrawerItem(
          icon: Icons.face_6_rounded,
          label: 'Students',
          route: '/teacher/students',
        ),
        AppDrawerItem(
          icon: Icons.event_available_rounded,
          label: 'Attendance',
          route: '/teacher/attendance',
        ),
        AppDrawerItem(
          icon: Icons.menu_book_rounded,
          label: 'Syllabus',
          route: '/teacher/syllabus',
        ),
        AppDrawerItem(
          icon: Icons.assignment_turned_in_rounded,
          label: 'Homework',
          route: '/teacher/homework',
        ),
        AppDrawerItem(
          icon: Icons.assignment_rounded,
          label: 'Marks Card',
          route: '/teacher/marks',
        ),
        AppDrawerItem(
          icon: Icons.document_scanner_rounded,
          label: 'Admission Documents',
          route: '/teacher/documents',
        ),
        AppDrawerItem(
          icon: Icons.send_rounded,
          label: 'Send Message',
          route: '/teacher/send-message',
        ),
        AppDrawerItem(
          icon: Icons.play_lesson_rounded,
          label: 'Learning Modules',
          route: '/learning-modules',
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
          route: '/teacher/leave',
        ),
        AppDrawerItem(
          icon: Icons.settings_suggest_rounded,
          label: 'Profile & Settings',
          route: '/teacher/settings',
        ),
      ],
    );
  }
}

bool _isChatRoute(String loc) => loc == '/chat' || loc.startsWith('/chat/');
