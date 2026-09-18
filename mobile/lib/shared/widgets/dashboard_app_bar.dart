import 'package:flutter/material.dart';
import 'notification_bell.dart';

/// Shared dashboard header used by Teacher, Coordinator and Parent so their
/// screens share one visual structure: menu button, logo, title/subtitle,
/// notification bell and a settings/profile avatar. Each role supplies its
/// own [title]/[subtitle]/[accentColor] and route targets -- only the shell
/// is shared, navigation and role-specific labels stay role-specific.
///
/// Admin keeps its own hero SliverAppBar and does not use this widget.
class DashboardAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DashboardAppBar({
    super.key,
    required this.title,
    this.subtitle,
    required this.accentColor,
    required this.notificationsRoute,
    required this.onAvatarTap,
    required this.avatarInitial,
    this.avatarPhotoUrl,
    this.logoAsset = 'assets/images/sunkidz_logo_hd.png',
  });

  final String title;
  final String? subtitle;
  final Color accentColor;
  final String notificationsRoute;
  final VoidCallback onAvatarTap;
  final String avatarInitial;
  final String? avatarPhotoUrl;
  final String logoAsset;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 0,
      leading: Builder(
        builder:
            (ctx) => IconButton(
              icon: const Icon(Icons.menu_rounded, color: Colors.black87),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Image.asset(
              logoAsset,
              height: 28,
              errorBuilder: (context, error, stackTrace) {
                return Icon(Icons.school, color: accentColor, size: 24);
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2D2323),
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                      letterSpacing: 0.5,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        NotificationBell(
          notificationsRoute: notificationsRoute,
          iconColor: Colors.black87,
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onAvatarTap,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: accentColor.withValues(alpha: 0.3)),
            ),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: accentColor.withValues(alpha: 0.1),
              backgroundImage:
                  avatarPhotoUrl != null ? NetworkImage(avatarPhotoUrl!) : null,
              child:
                  avatarPhotoUrl == null
                      ? Text(
                        avatarInitial,
                        style: TextStyle(
                          color: accentColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      )
                      : null,
            ),
          ),
        ),
        const SizedBox(width: 16),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(
          height: 1,
          thickness: 1,
          color: accentColor.withValues(alpha: 0.08),
        ),
      ),
    );
  }
}
