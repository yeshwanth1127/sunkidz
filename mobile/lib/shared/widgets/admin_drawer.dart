import 'package:flutter/material.dart';
import 'app_drawer_shell.dart';

class AdminDrawer extends StatelessWidget {
  const AdminDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppDrawerShell(
      avatarIcon: Icons.person,
      roleLabel: 'Administrator',
      fallbackName: 'Admin',
      items: [
        AppDrawerItem(
          icon: Icons.dashboard_rounded,
          label: 'Dashboard',
          route: '/admin',
        ),
        AppDrawerItem(
          icon: Icons.account_balance_rounded,
          label: 'Branches',
          route: '/branches',
        ),
        AppDrawerItem(
          icon: Icons.person_search_rounded,
          label: 'Enquiries',
          route: '/enquiries',
        ),
        AppDrawerItem(
          icon: Icons.school_rounded,
          label: 'Admissions',
          route: '/admissions',
        ),
        AppDrawerItem(
          icon: Icons.document_scanner_rounded,
          label: 'Admission Documents',
          route: '/admin/documents',
        ),
        AppDrawerItem(
          icon: Icons.face_6_rounded,
          label: 'Students',
          route: '/students',
        ),
        AppDrawerItem(
          icon: Icons.assignment_rounded,
          label: 'Marks Card',
          route: '/marks',
        ),
        AppDrawerItem(
          icon: Icons.event_available_rounded,
          label: 'Attendance',
          route: '/admin/attendance',
        ),
        AppDrawerItem(
          icon: Icons.receipt_long_rounded,
          label: 'Fee Management',
          route: '/admin/fees',
          isActive: _containsFees,
        ),
        AppDrawerItem(
          icon: Icons.groups_rounded,
          label: 'Staff',
          route: '/staff',
        ),
        AppDrawerItem(
          icon: Icons.child_care_rounded,
          label: 'Toddlers',
          route: '/admin/toddlers',
        ),
        AppDrawerItem(
          icon: Icons.child_friendly_rounded,
          label: 'Daycare',
          route: '/admin/daycare',
        ),
        AppDrawerItem(
          icon: Icons.menu_book_rounded,
          label: 'Syllabus',
          route: '/syllabus',
        ),
        AppDrawerItem(
          icon: Icons.assignment_turned_in_rounded,
          label: 'Homework',
          route: '/homework',
        ),
        AppDrawerItem(
          icon: Icons.send_rounded,
          label: 'Send Message',
          route: '/admin/send-message',
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
          route: '/admin/leave',
        ),
        AppDrawerItem(
          icon: Icons.settings_suggest_rounded,
          label: 'Profile & Settings',
          route: '/admin/settings',
        ),
      ],
    );
  }
}

bool _containsFees(String loc) => loc.contains('/fees');
bool _isChatRoute(String loc) => loc == '/chat' || loc.startsWith('/chat/');
