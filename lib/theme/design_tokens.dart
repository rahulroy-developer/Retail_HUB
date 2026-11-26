import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DesignTokens {
  // Colors (Dark Mode Elevated Aesthetic)
  static const Color background = Color(0xFF0F172A); // Slate 900
  static const Color surface = Color(0xFF1E293B);    // Slate 800
  static const Color surfaceElevated = Color(0xFF334155); // Slate 700
  static const Color primary = Color(0xFF3B82F6);    // Blue 500
  static const Color primaryVariant = Color(0xFF2563EB); // Blue 600
  static const Color accent = Color(0xFF10B981);     // Emerald 500
  static const Color warning = Color(0xFFF59E0B);    // Amber 500
  static const Color error = Color(0xFFEF4444);      // Red 500
  static const Color textPrimary = Color(0xFFF8FAFC);  // Slate 50
  static const Color textSecondary = Color(0xFF94A3B8); // Slate 400

  // Gradients for Cards
  static const LinearGradient cardBorderGradient = LinearGradient(
    colors: [Color(0xFF3B82F6), Color(0x003B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Radii
  static final BorderRadius borderRadiusSmall = BorderRadius.circular(8.0);
  static final BorderRadius borderRadiusMedium = BorderRadius.circular(16.0);
  static final BorderRadius borderRadiusLarge = BorderRadius.circular(24.0);

  // Typography
  static TextTheme get textTheme {
    return GoogleFonts.interTextTheme(
      ThemeData.dark().textTheme.copyWith(
        displayLarge: const TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 32),
        displayMedium: const TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 28),
        titleLarge: const TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 22),
        bodyLarge: const TextStyle(color: textPrimary, fontSize: 16),
        bodyMedium: const TextStyle(color: textSecondary, fontSize: 14),
        labelLarge: const TextStyle(color: textPrimary, fontWeight: FontWeight.w600, letterSpacing: 1.2),
      ),
    );
  }

  // Theme Data
  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: surface,
        error: error,
      ),
      textTheme: textTheme,
      cardTheme: CardThemeData(
      color: surface,
      shape: RoundedRectangleBorder(borderRadius: borderRadiusMedium),
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceElevated,
        selectedItemColor: primary,
        unselectedItemColor: textSecondary,
      ),
    );
  }
}
