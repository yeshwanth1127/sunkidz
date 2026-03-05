import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color primary = Color(0xFF4299F0);
  static const Color primaryLight = Color(0xFF5EA6ED);
  static const Color backgroundLight = Color(0xFFF6F7F8);
  static const Color backgroundDark = Color(0xFF101922);
  static const Color pastelYellow = Color(0xFFFFF9DB);
  static const Color pastelGreen = Color(0xFFEBFBEE);
  static const Color pastelBlue = Color(0xFFE7F5FF);
  static const Color pastelOrange = Color(0xFFFFEDD5);
  static const Color secondary = Color(0xFFFFD966);
  static const Color accentGreen = Color(0xFFA3E635);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        surface: Colors.white,
        onSurface: const Color(0xFF0F172A),
        onSurfaceVariant: const Color(0xFF64748B),
      ),
      scaffoldBackgroundColor: AppColors.backgroundLight,
      fontFamily: GoogleFonts.lexend().fontFamily,
      textTheme: GoogleFonts.lexendTextTheme().copyWith(
        headlineLarge: GoogleFonts.lexend(fontWeight: FontWeight.bold, fontSize: 24),
        headlineMedium: GoogleFonts.lexend(fontWeight: FontWeight.bold, fontSize: 20),
        titleLarge: GoogleFonts.lexend(fontWeight: FontWeight.bold, fontSize: 18),
        titleMedium: GoogleFonts.lexend(fontWeight: FontWeight.w600, fontSize: 16),
        bodyMedium: GoogleFonts.lexend(fontSize: 14),
        bodySmall: GoogleFonts.lexend(fontSize: 12),
        labelSmall: GoogleFonts.lexend(fontSize: 10, fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: AppColors.primary,
        surface: const Color(0xFF0F172A),
        onSurface: Colors.white,
        onSurfaceVariant: const Color(0xFF94A3B8),
      ),
      scaffoldBackgroundColor: AppColors.backgroundDark,
      fontFamily: GoogleFonts.lexend().fontFamily,
      textTheme: GoogleFonts.lexendTextTheme(ThemeData.dark().textTheme).copyWith(
        headlineLarge: GoogleFonts.lexend(fontWeight: FontWeight.bold, fontSize: 24),
        titleLarge: GoogleFonts.lexend(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF0F172A),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
