import 'package:flutter/material.dart';

class AppColors {
  static const Color forestGreen = Color(0xFF1B5E20);
  static const Color freshGreen = Color(0xFF4CAF50);
  static const Color background = Color(0xFFF8FAF8);
  static const Color white = Color(0xFFFFFFFF);
  static const Color charcoal = Color(0xFF212121);
  static const Color grey = Color(0xFF757575);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFE53935);
  static const Color softGreen = Color(0xFFE8F5E9);
  static const Color softWarning = Color(0xFFFFF3E0);
  static const Color softRed = Color(0xFFFFEBEE);
}

class AppTheme {
  static ThemeData buildTheme() {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.forestGreen,
        brightness: Brightness.light,
      ),
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
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
        headlineSmall: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.charcoal,
        ),
        titleMedium: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.charcoal,
        ),
        bodyMedium: const TextStyle(color: AppColors.charcoal),
        bodySmall: const TextStyle(color: AppColors.grey),
      ),
    );
  }
}
