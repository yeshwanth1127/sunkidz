import 'package:flutter/material.dart';
import 'app_theme.dart';

class AppGradients {
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.primary,
      Color(0xFF6366F1), // Deepening the blue indigo
    ],
  );

  static const LinearGradient warmGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFBBF24), // Vibrant yellow
      Color(0xFFF59E0B), // Golden orange
    ],
  );

  static const LinearGradient coolGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF34D399), // Emerald green
      Color(0xFF10B981), // Solid green
    ],
  );

  static const LinearGradient cardGlass = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xCCFFFFFF), // Frosted white
      Color(0x80FFFFFF), // More transperant
    ],
  );
}
