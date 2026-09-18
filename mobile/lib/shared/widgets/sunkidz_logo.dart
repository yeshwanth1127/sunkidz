import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class SunkidzLogo extends StatelessWidget {
  final double size;
  final bool showText;

  const SunkidzLogo({super.key, this.size = 120, this.showText = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/sunkidzlogo.png',
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
