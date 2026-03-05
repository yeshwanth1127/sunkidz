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
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Center(
            child: ClipOval(
              child: Image.asset(
                'images/new_logo.png',
                width: size * 0.9,
                height: size * 0.9,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback if logo not found
                  return Icon(
                    Icons.school,
                    size: size * 0.6,
                    color: AppColors.primary,
                  );
                },
              ),
            ),
          ),
        ),
        if (showText) ...[
          const SizedBox(height: 16),
          Text(
            'SUNKIDZ',
            style: TextStyle(
              fontSize: size * 0.2,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Learning Management System',
            style: TextStyle(
              fontSize: size * 0.1,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ],
    );
  }
}
