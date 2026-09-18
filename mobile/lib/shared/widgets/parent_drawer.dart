import 'package:flutter/material.dart';
import 'app_drawer_shell.dart';

class ParentDrawer extends StatelessWidget {
  const ParentDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppDrawerShell(
      avatarIcon: Icons.person,
      roleLabel: 'Parent',
      fallbackName: 'Parent',
      items: [
        AppDrawerItem(
          icon: Icons.dashboard_rounded,
          label: 'Home',
          route: '/parent',
        ),
        AppDrawerItem(
          icon: Icons.receipt_long_rounded,
          label: 'Fee Receipts',
          route: '/parent/receipts',
        ),
        AppDrawerItem(
          icon: Icons.school_rounded,
          label: 'Homework',
          route: '/parent/homework',
        ),
        AppDrawerItem(
          icon: Icons.assignment_rounded,
          label: 'Marks Card',
          route: '/parent/marks-cards',
        ),
        AppDrawerItem(
          icon: Icons.directions_bus_rounded,
          label: 'Bus Tracking',
          route: '/parent/bus-tracking',
        ),
        AppDrawerItem(
          icon: Icons.notes_rounded,
          label: 'Daycare Updates',
          route: '/parent/daycare-updates',
        ),
        AppDrawerItem(
          icon: Icons.event_available_rounded,
          label: 'Attendance',
          route: '/parent/attendance',
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
          icon: Icons.event_note_rounded,
          label: 'Apply Leave',
          route: '/parent/leave',
        ),
        AppDrawerItem(
          icon: Icons.settings_suggest_rounded,
          label: 'Settings',
          route: '/parent/settings',
        ),
      ],
    );
  }
}

bool _isChatRoute(String loc) => loc == '/chat' || loc.startsWith('/chat/');
