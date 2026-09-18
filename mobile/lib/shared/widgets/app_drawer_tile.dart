import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_shadows.dart';

/// Shared drawer navigation tile used by every role's drawer, so Admin,
/// Teacher, Parent and Coordinator all render navigation items identically.
class AppDrawerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final bool isLogout;

  const AppDrawerTile({
    super.key,
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
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.hardEdge,
        child: ListTile(
          onTap: onTap,
          dense: true,
          leading: Icon(
            icon,
            color:
                isActive
                    ? Colors.white
                    : (isLogout
                        ? Colors.redAccent.shade400
                        : const Color(0xFF64748B)),
            size: 22,
          ),
          title: Text(
            label,
            style: GoogleFonts.lexend(
              color:
                  isActive
                      ? Colors.white
                      : (isLogout
                          ? Colors.redAccent.shade400
                          : const Color(0xFF1E293B)),
              fontWeight:
                  isActive || isLogout ? FontWeight.w700 : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
