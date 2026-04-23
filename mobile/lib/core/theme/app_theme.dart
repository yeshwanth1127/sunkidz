import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color primary = Color(0xFF4F46E5); // More modern Indigo/Blue
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color secondary = Color(0xFFFBBF24); // Solid Amber
  static const Color backgroundLight = Color(0xFFF9FAFB); 
  static const Color backgroundDark = Color(0xFF0F172A);
  
  static const Color pastelYellow = Color(0xFFFEF3C7);
  static const Color pastelGreen = Color(0xFFD1FAE5);
  static const Color pastelBlue = Color(0xFFDBEAFE);
  static const Color pastelOrange = Color(0xFFFFEDD5);
  static const Color accentGreen = Color(0xFF10B981);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: Colors.white,
        onSurface: const Color(0xFF1E293B),
        onSurfaceVariant: const Color(0xFF64748B),
      ),
      scaffoldBackgroundColor: AppColors.backgroundLight,
      fontFamily: GoogleFonts.lexend().fontFamily,
      textTheme: GoogleFonts.lexendTextTheme().copyWith(
        headlineLarge: GoogleFonts.lexend(fontWeight: FontWeight.w800, fontSize: 28, letterSpacing: -0.5),
        headlineMedium: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 22, letterSpacing: -0.5),
        titleLarge: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 18),
        titleMedium: GoogleFonts.lexend(fontWeight: FontWeight.w600, fontSize: 16),
        bodyLarge: GoogleFonts.lexend(fontSize: 16, height: 1.5),
        bodyMedium: GoogleFonts.lexend(fontSize: 14, height: 1.4, color: const Color(0xFF334155)),
        bodySmall: GoogleFonts.lexend(fontSize: 12, color: const Color(0xFF64748B)),
        labelSmall: GoogleFonts.lexend(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Color(0xFF0F172A),
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: const Color(0xFFE2E8F0).withValues(alpha: 0.5), width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        labelStyle: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
      ),
    );
  }

  static ThemeData get darkTheme {
    // Keeping it simple as requested - disabling dark mode or keeping it legacy
    return lightTheme;
  }
}

