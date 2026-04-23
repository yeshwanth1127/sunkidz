import 'package:flutter/material.dart';

class AppShadows {
  static const BoxShadow soft = BoxShadow(
    color: Color(0x0F000000),
    blurRadius: 10,
    offset: Offset(0, 4),
  );

  static const BoxShadow card = BoxShadow(
    color: Color(0x1A000000),
    blurRadius: 20,
    offset: Offset(0, 8),
  );

  static const BoxShadow elevated = BoxShadow(
    color: Color(0x26000000),
    blurRadius: 30,
    offset: Offset(0, 12),
  );

  static BoxShadow glow(Color color) => BoxShadow(
    color: color.withValues(alpha: 0.3),
    blurRadius: 15,
    spreadRadius: 2,
    offset: const Offset(0, 4),
  );
}
