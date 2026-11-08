import 'package:flutter/material.dart';

class AppColors {
  static bool _darkMode = false;

  static set darkMode(bool value) => _darkMode = value;

  static const Color forestGreen = Color(0xFF1B5E20);
  static const Color freshGreen = Color(0xFF4CAF50);
  static Color get background =>
      _darkMode ? const Color(0xFF111711) : const Color(0xFFF8FAF8);
  static Color get white =>
      _darkMode ? const Color(0xFF1B211B) : const Color(0xFFFFFFFF);
  static Color get charcoal =>
      _darkMode ? const Color(0xFFE8EDE8) : const Color(0xFF212121);
  static Color get grey =>
      _darkMode ? const Color(0xFFB0B8B0) : const Color(0xFF757575);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFE53935);
  static const Color softGreen = Color(0xFFE8F5E9);
  static const Color softWarning = Color(0xFFFFF3E0);
  static const Color softRed = Color(0xFFFFEBEE);
}

class AppTheme {
  static ThemeData buildTheme({Brightness brightness = Brightness.light}) {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      brightness: brightness,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.forestGreen,
        brightness: brightness,
      ),
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.charcoal,
        elevation: 0,
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.forestGreen,
          foregroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textTheme: base.textTheme.copyWith(
        headlineSmall: TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.charcoal,
        ),
        titleMedium: TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.charcoal,
        ),
        bodyMedium: TextStyle(color: AppColors.charcoal),
        bodySmall: TextStyle(color: AppColors.grey),
      ),
    );
  }
}
