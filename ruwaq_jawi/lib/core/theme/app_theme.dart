import 'package:flutter/material.dart';

class AppTheme {
  // Color Palette - Following 60-30-10 rule
  // 10% - Accent colors (use sparingly for highlights, buttons, important icons)
  static const Color primaryColor = Color(0xFF00BF6D); // Bright green accent - ONLY for buttons/highlights
  static const Color primaryLightColor = Color(0xFF40D68A);
  static const Color primaryDarkColor = Color(0xFF00A85C);

  // 30% - Secondary colors (for surfaces, cards, secondary elements)
  static const Color secondaryColor = Color(0xFFD4AF37); // Gold
  static const Color secondaryLightColor = Color(0xFFE6C757);
  static const Color secondaryDarkColor = Color(0xFFB8941F);
  static const Color surfaceColor = Color(0xFFFFFFFF); // 30% - Cards and surfaces

  // 60% - Neutral colors (for backgrounds, majority of UI)
  static const Color backgroundColor = Color(0xFFF8F9FA); // 60% - Main background
  static const Color neutralGray = Color(0xFFF1F3F4); // Additional neutral option

  // Status colors
  static const Color errorColor = Color(0xFFDC3545);
  static const Color successColor = Color(0xFF28A745);
  static const Color warningColor = Color(0xFFFFC107);

  // Text Colors - Pastikan kontras yang baik
  static const Color textPrimaryColor = Color(0xFF000000); // Hitam penuh untuk keterbacaan maksimum
  static const Color textSecondaryColor = Color(0xFF4A4A4A); // Abu-abu gelap untuk teks sekunder
  static const Color textLightColor = Color(0xFFFFFFFF);

  // Border Colors
  static const Color borderColor = Color(0xFFDEE2E6);

  // Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
      ),

      // App Bar Theme - Transparent background as per CLAUDE.md
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimaryColor,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimaryColor,
        ),
      ),

      // Elevated Button Theme - Primary buttons use xl radius
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: textLightColor,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // xl radius for primary buttons
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),

      // Input Decoration Theme - Medium radius for inputs
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), // md radius for inputs
          borderSide: const BorderSide(color: textSecondaryColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), // md radius for inputs
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        labelStyle: const TextStyle(
          color: textPrimaryColor,
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
        hintStyle: const TextStyle(color: textSecondaryColor, fontSize: 16),
        filled: true,
        fillColor: surfaceColor,
      ),

      // Card Theme - Context-based rounded corners
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16), // xl radius for cards
          side: const BorderSide(color: borderColor, width: 1),
        ),
      ),

      // Dialog Theme - Pastikan title dialog jelas
      dialogTheme: DialogThemeData(
        titleTextStyle: const TextStyle(
          color: textPrimaryColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: const TextStyle(
          color: textPrimaryColor,
          fontSize: 16,
        ),
        backgroundColor: surfaceColor,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), // 2xl radius for dialogs
      ),

      // Text Theme - Pastikan semua teks mempunyai kontras yang baik
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: textPrimaryColor,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: TextStyle(
          color: textPrimaryColor,
          fontWeight: FontWeight.bold,
        ),
        displaySmall: TextStyle(
          color: textPrimaryColor,
          fontWeight: FontWeight.bold,
        ),
        headlineLarge: TextStyle(
          color: textPrimaryColor,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: textPrimaryColor,
          fontWeight: FontWeight.bold,
        ),
        headlineSmall: TextStyle(
          color: textPrimaryColor,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: TextStyle(
          color: textPrimaryColor,
          fontWeight: FontWeight.w600,
          fontSize: 22,
        ),
        titleMedium: TextStyle(
          color: textPrimaryColor,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
        titleSmall: TextStyle(
          color: textPrimaryColor,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
        bodyLarge: TextStyle(color: textPrimaryColor, fontSize: 16),
        bodyMedium: TextStyle(color: textPrimaryColor, fontSize: 14),
        bodySmall: TextStyle(color: textSecondaryColor, fontSize: 12),
        labelLarge: TextStyle(
          color: textPrimaryColor,
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
        labelMedium: TextStyle(
          color: textPrimaryColor,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        labelSmall: TextStyle(color: textSecondaryColor, fontSize: 12),
      ),
    );
  }

}
