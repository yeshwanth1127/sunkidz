import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api/current_user_provider.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import 'notification_bell.dart';

/// Breakpoint above which the web console renders the permanent sidebar shell.
const double kWebShellBreakpoint = 1000;

/// Returns true when we should render the desktop-style web shell (sidebar +
/// top bar) instead of the mobile-style scaffold + drawer.
bool isWebWide(BuildContext context) {
  if (!kIsWeb) return false;
  return MediaQuery.of(context).size.width >= kWebShellBreakpoint;
}

/// A single sidebar navigation entry.
class WebNavItem {
  final IconData icon;
  final String label;
  final String route;
  final bool Function(String currentRoute)? isActive;

  const WebNavItem({
    required this.icon,
    required this.label,
    required this.route,
    this.isActive,
  });
}

/// Group of nav items with an optional section title.
class WebNavGroup {
  final String? title;
  final List<WebNavItem> items;
  const WebNavGroup({this.title, required this.items});
}

/// Desktop-style web console shell: permanent rounded sidebar on the left and a
/// soft top bar with greeting, notifications and avatar. Use this on web wide
/// screens only — on mobile/narrow widths return your existing Scaffold instead.
class WebConsoleShell extends ConsumerWidget {
  const WebConsoleShell({
    super.key,
    required this.roleLabel,
    required this.nav,
    required this.body,
    this.notificationsRoute,
    this.settingsRoute,
    this.accent = AppColors.hueLavender,
  });

  final String roleLabel;
  final List<WebNavGroup> nav;
  final Widget body;
  final String? notificationsRoute;
  final String? settingsRoute;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentRoute = GoRouterState.of(context).matchedLocation;
    final userAsync = ref.watch(currentUserProvider);
    final fullName = userAsync.valueOrNull?['full_name']?.toString() ?? '';
    final initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: AppColors.webCanvas,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Sidebar(
              currentRoute: currentRoute,
              roleLabel: roleLabel,
              accent: accent,
              groups: nav,
              fullName: fullName,
              initial: initial,
              onLogout: () => _logout(context, ref),
            ),
            Expanded(
              child: Column(
                children: [
                  _TopBar(
                    notificationsRoute: notificationsRoute,
                    settingsRoute: settingsRoute,
                    fullName: fullName,
                    initial: initial,
                    accent: accent,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
                      child: body,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _logout(BuildContext context, WidgetRef ref) {
    ref.read(authProvider.notifier).logout();
    context.go('/login');
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.currentRoute,
    required this.roleLabel,
    required this.accent,
    required this.groups,
    required this.fullName,
    required this.initial,
    required this.onLogout,
  });

  final String currentRoute;
  final String roleLabel;
  final Color accent;
  final List<WebNavGroup> groups;
  final String fullName;
  final String initial;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 252,
      margin: const EdgeInsets.fromLTRB(16, 16, 0, 16),
      decoration: BoxDecoration(
        color: AppColors.webSurface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 24,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.tintLavender,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Image.asset(
                    'assets/images/sunkidz_logo_hd.png',
                    height: 28,
                    errorBuilder: (_, __, ___) =>
                        Icon(Icons.school_rounded, color: accent, size: 24),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sunkidz',
                        style: GoogleFonts.lexend(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.webInk,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        roleLabel,
                        style: GoogleFonts.lexend(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.webInkMuted,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(
            height: 1,
            thickness: 1,
            color: AppColors.webBorder,
            indent: 20,
            endIndent: 20,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              children: [
                for (final group in groups) ...[
                  if (group.title != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
                      child: Text(
                        group.title!.toUpperCase(),
                        style: GoogleFonts.lexend(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.webInkMuted,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  for (final item in group.items)
                    _NavTile(
                      item: item,
                      currentRoute: currentRoute,
                      accent: accent,
                    ),
                ],
              ],
            ),
          ),
          const Divider(
            height: 1,
            thickness: 1,
            color: AppColors.webBorder,
            indent: 20,
            endIndent: 20,
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onLogout,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.logout_rounded,
                      size: 20,
                      color: Color(0xFFE05A6F),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Log out',
                      style: GoogleFonts.lexend(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFE05A6F),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatefulWidget {
  const _NavTile({
    required this.item,
    required this.currentRoute,
    required this.accent,
  });

  final WebNavItem item;
  final String currentRoute;
  final Color accent;

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.item.isActive?.call(widget.currentRoute) ??
        widget.currentRoute == widget.item.route;
    final accent = widget.accent;

    final bg = active
        ? accent.withValues(alpha: 0.12)
        : (_hover ? AppColors.webCanvas : Colors.transparent);
    final fg = active ? accent : AppColors.webInk;
    final iconFg = active ? accent : AppColors.webInkMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => context.go(widget.item.route),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(widget.item.icon, size: 19, color: iconFg),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.item.label,
                    style: GoogleFonts.lexend(
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: fg,
                    ),
                  ),
                ),
                if (active)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.notificationsRoute,
    required this.settingsRoute,
    required this.fullName,
    required this.initial,
    required this.accent,
  });

  final String? notificationsRoute;
  final String? settingsRoute;
  final String fullName;
  final String initial;
  final Color accent;

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _formatDate(DateTime d) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    const days = [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final firstName = fullName.split(' ').first;
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_greeting()}${firstName.isNotEmpty ? ', $firstName' : ''}',
                  style: GoogleFonts.lexend(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.webInk,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(DateTime.now()),
                  style: GoogleFonts.lexend(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.webInkMuted,
                  ),
                ),
              ],
            ),
          ),
          _SearchPlaceholder(),
          const SizedBox(width: 12),
          if (notificationsRoute != null)
            Container(
              decoration: BoxDecoration(
                color: AppColors.webSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.webBorder),
              ),
              child: NotificationBell(
                notificationsRoute: notificationsRoute!,
                iconColor: AppColors.webInk,
              ),
            ),
          const SizedBox(width: 12),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: settingsRoute != null
                  ? () => context.go(settingsRoute!)
                  : null,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.webSurface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.webBorder),
                ),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: accent.withValues(alpha: 0.15),
                  child: Text(
                    initial,
                    style: GoogleFonts.lexend(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.webSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.webBorder),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            size: 18,
            color: AppColors.webInkMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Search students, classes, staff…',
              style: GoogleFonts.lexend(
                fontSize: 13,
                color: AppColors.webInkMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.webCanvas,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.webBorder),
            ),
            child: Text(
              '⌘ K',
              style: GoogleFonts.lexend(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.webInkMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
