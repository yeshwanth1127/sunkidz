import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class SunkidzLogo extends StatelessWidget {
  final double size;
  final bool showText;

  const SunkidzLogo({
    super.key,
    this.size = 120,
    this.showText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.15),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.8),
                blurRadius: 4,
                offset: const Offset(-2, -2),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(size * 0.12),
            child: Image.asset(
              'assets/images/sunkidz_logo_hd.png',
              width: size * 0.76,
              height: size * 0.76,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.school,
                  size: size * 0.5,
                  color: AppColors.primary,
                );
              },
            ),
          ),
        ),
        if (showText) ...[
          const SizedBox(height: 16),
          Text(
            'SUNKIDZ',
            style: TextStyle(
              fontSize: size * 0.18,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Learning Management System',
            style: TextStyle(
              fontSize: size * 0.09,
              color: Colors.grey.shade500,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ],
    );
  }
}
